import {
  S3Client,
  GetObjectCommand,
  PutObjectCommand,
} from "@aws-sdk/client-s3";
import sharp from "sharp";

const s3 = new S3Client({});

const BUCKET_NAME = process.env.S3_BUCKET;
const PROCESSED_PREFIX = process.env.PROCESSED_PREFIX || "processed/";

// Convierte un stream de S3 a Buffer
async function streamABuffer(stream) {
  return new Promise((resolve, reject) => {
    const bloques = [];
    stream.on("data", (chunk) => bloques.push(chunk));
    stream.on("error", (err) => reject(err));
    stream.on("end", () => resolve(Buffer.concat(bloques)));
  });
}

export const handler = async (event) => {
  const erroresEnLote = [];

  for (const registro of event.Records) {
    try {
      // 1. Parsear cuerpo SQS
      let cuerpoSQS;
      try {
        cuerpoSQS = JSON.parse(registro.body);
      } catch (parseError) {
        console.error(
          `Mensaje SQS no es JSON válido: ${registro.messageId}`,
          parseError
        );
        erroresEnLote.push({ itemIdentifier: registro.messageId });
        continue;
      }

      const eventoS3 = cuerpoSQS.Records ? cuerpoSQS.Records[0] : null;

      // 2. Validar estructura del evento S3
      if (!eventoS3 || !eventoS3.s3 || !eventoS3.s3.object || !eventoS3.s3.object.key) {
        console.error(
          `Mensaje SQS sin estructura S3 válida: ${registro.messageId}`
        );
        erroresEnLote.push({ itemIdentifier: registro.messageId });
        continue;
      }

      // 3. Obtener key del objeto
      const rutaOrigen = decodeURIComponent(
        eventoS3.s3.object.key.replace(/\+/g, " ")
      );

      // 4. Descargar imagen original de uploads/
      const respuestaObjeto = await s3.send(
        new GetObjectCommand({
          Bucket: BUCKET_NAME,
          Key: rutaOrigen,
        })
      );

      const bufferImagenOriginal = await streamABuffer(respuestaObjeto.Body);

      // 5. Crear máscara circular SVG (40x40 px)
      const mascaraCircularSvg = Buffer.from(
        '<svg width="40" height="40"><circle cx="20" cy="20" r="20" fill="#fff"/></svg>'
      );

      // 6. Procesar con sharp
      const bufferProcesado = await sharp(bufferImagenOriginal, {
        limitInputPixels: 4096 * 4096, // protección anti decompression bomb
      })
        .resize(40, 40, { fit: "cover" })
        .ensureAlpha()
        .composite([{ input: mascaraCircularSvg, blend: "dest-in" }])
        .png()
        .toBuffer();

      // 7. Guardar en processed/ con sufijo _circular.png
      const nombreBase = rutaOrigen.split("/").pop().replace(/\.[^/.]+$/, "");
      const rutaDestino = `${PROCESSED_PREFIX}${nombreBase}_circular.png`;

      await s3.send(
        new PutObjectCommand({
          Bucket: BUCKET_NAME,
          Key: rutaDestino,
          Body: bufferProcesado,
          ContentType: "image/png",
        })
      );

      console.log(
        `Procesado OK: ${rutaOrigen} → ${rutaDestino} (msg: ${registro.messageId})`
      );
    } catch (error) {
      console.error(
        `Error procesando mensaje SQS ${registro.messageId}:`,
        error
      );
      erroresEnLote.push({ itemIdentifier: registro.messageId });
    }
  }

  return { batchItemFailures: erroresEnLote };
};