import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";
import { randomUUID } from "crypto";
import Busboy from "busboy";
import { Readable } from "stream";

const s3 = new S3Client({});

const BUCKET_NAME = process.env.S3_BUCKET;
const UPLOAD_PREFIX = process.env.UPLOAD_PREFIX || "uploads/";
const MAX_SIZE_BYTES = 10 * 1024 * 1024; // 10 MB

// Función auxiliar para parsear multipart/form-data con busboy
function parsearMultipart(event, contentType) {
  return new Promise((resolve, reject) => {
    try {
      const busboy = Busboy({ headers: { "content-type": contentType } });
      let archivoBuffer = null;

      busboy.on("file", (_fieldname, fileStream) => {
        const chunks = [];
        fileStream.on("data", (chunk) => chunks.push(chunk));
        fileStream.on("end", () => {
          archivoBuffer = Buffer.concat(chunks);
        });
      });

      busboy.on("finish", () => resolve(archivoBuffer));
      busboy.on("error", (err) => reject(err));

      const rawBuffer = event.isBase64Encoded
        ? Buffer.from(event.body, "base64")
        : Buffer.from(event.body);

      const stream = Readable.from(rawBuffer);
      stream.pipe(busboy);
    } catch (err) {
      reject(err);
    }
  });
}

// Detecta el tipo MIME real usando magic bytes (firma binaria)
function detectarMimeType(buffer) {
  if (buffer.length < 12) return null;

  // PNG: 89 50 4E 47 0D 0A 1A 0A
  if (
    buffer[0] === 0x89 &&
    buffer[1] === 0x50 &&
    buffer[2] === 0x4e &&
    buffer[3] === 0x47
  ) {
    return { mime: "image/png", ext: "png" };
  }

  // JPEG: FF D8 FF
  if (buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff) {
    return { mime: "image/jpeg", ext: "jpg" };
  }

  // GIF: 47 49 46 38 ("GIF8")
  if (
    buffer[0] === 0x47 &&
    buffer[1] === 0x49 &&
    buffer[2] === 0x46 &&
    buffer[3] === 0x38
  ) {
    return { mime: "image/gif", ext: "gif" };
  }

  // WEBP: RIFF....WEBP
  if (
    buffer[0] === 0x52 &&
    buffer[1] === 0x49 &&
    buffer[2] === 0x46 &&
    buffer[3] === 0x46 &&
    buffer[8] === 0x57 &&
    buffer[9] === 0x45 &&
    buffer[10] === 0x42 &&
    buffer[11] === 0x50
  ) {
    return { mime: "image/webp", ext: "webp" };
  }

  return null;
}

export const handler = async (event) => {
  try {
    // 1. Validar que exista body
    if (!event.body) {
      return {
        statusCode: 400,
        body: JSON.stringify({
          message: "No se proporcionó el contenido de la imagen",
        }),
      };
    }

    // 2. Extraer buffer según Content-Type (multipart, JSON base64, o binario directo)
    const rawContentType =
      event.headers?.["content-type"] ||
      event.headers?.["Content-Type"] ||
      "";
    const contentTypeLower = rawContentType.toLowerCase();

    let imageBuffer;

    if (contentTypeLower.includes("multipart/form-data")) {
      imageBuffer = await parsearMultipart(event, rawContentType);
      if (!imageBuffer || imageBuffer.length === 0) {
        return {
          statusCode: 400,
          body: JSON.stringify({
            message: "No se encontró ningún archivo en la petición multipart",
          }),
        };
      }
    } else if (contentTypeLower.includes("application/json")) {
      const parsedBody = JSON.parse(event.body);
      const base64Data = parsedBody.image || parsedBody.data || parsedBody.file;
      if (!base64Data) {
        return {
          statusCode: 400,
          body: JSON.stringify({
            message: "El payload JSON debe incluir la clave 'image' o 'data' en base64",
          }),
        };
      }
      imageBuffer = Buffer.from(base64Data, "base64");
    } else {
      imageBuffer = event.isBase64Encoded
        ? Buffer.from(event.body, "base64")
        : Buffer.from(event.body);
    }

    // 3. Validar tamaño máximo (10 MB)
    if (imageBuffer.length > MAX_SIZE_BYTES) {
      return {
        statusCode: 413,
        body: JSON.stringify({
          message: "La imagen excede el tamaño máximo permitido de 10 MB",
          size: imageBuffer.length,
        }),
      };
    }

    if (imageBuffer.length === 0) {
      return {
        statusCode: 400,
        body: JSON.stringify({ message: "El archivo está vacío" }),
      };
    }

    // 4. Detectar tipo real (jpg, png, gif, webp)
    const tipo = detectarMimeType(imageBuffer);
    if (!tipo) {
      return {
        statusCode: 415,
        body: JSON.stringify({
          message:
            "Formato no soportado. Permitidos: jpg, png, gif, webp",
        }),
      };
    }

    // 5. Generar UUID y nombre de archivo
    const imageId = randomUUID();
    const nombreArchivo = `${UPLOAD_PREFIX}${imageId}.${tipo.ext}`;

    // 6. Subir a S3
    const comandoSubida = new PutObjectCommand({
      Bucket: BUCKET_NAME,
      Key: nombreArchivo,
      Body: imageBuffer,
      ContentType: tipo.mime,
    });

    await s3.send(comandoSubida);

    // 7. Respuesta exitosa
    return {
      statusCode: 201,
      body: JSON.stringify({
        message: "Imagen subida con éxito",
        imageId: imageId,
        ruta: nombreArchivo,
        contentType: tipo.mime,
        size: imageBuffer.length,
      }),
    };
  } catch (error) {
    console.error("Error en Upload Lambda:", error);
    return {
      statusCode: 500,
      body: JSON.stringify({
        message: "Error interno al subir la imagen",
        error: error.message,
      }),
    };
  }
};