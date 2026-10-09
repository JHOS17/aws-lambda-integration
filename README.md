# AWS Lambda Image Processing

## 1. Requisitos

Antes de ejecutar el proyecto, se necesita:

* Una cuenta de AWS con permisos para crear los recursos del proyecto.
* Terraform CLI versión 1.6.0 o superior.
* AWS CLI configurado.
* Node.js 22 y npm.
* Git.
* Acceso al repositorio del proyecto.

Para comprobar las herramientas instaladas:

```powershell
terraform --version
aws --version
node --version
npm --version
git --version
```

## 2. Configuración de AWS

El proyecto utiliza AWS para desplegar la infraestructura y procesar imágenes.

Los principales servicios utilizados son:

* **VPC:** red y subredes públicas y privadas.
* **Amazon S3:** almacenamiento de imágenes originales y procesadas.
* **Amazon SQS:** cola de procesamiento y Dead Letter Queue (DLQ).
* **AWS Lambda:** carga y procesamiento de imágenes.
* **Amazon API Gateway:** endpoint HTTP para subir imágenes.
* **Amazon CloudWatch:** logs y alarmas.
* **Amazon SNS:** envío de notificaciones de alertas.
* **VPC Endpoints:** conectividad privada con S3 y SQS.

La región de AWS se configura mediante la variable `aws_region`. Antes de desplegar, revisa su valor en `variables.tf`.

## 3. Configuración de credenciales

El proveedor de Terraform utiliza el perfil AWS `customprofile`.

En PowerShell, configura tus credenciales con:

```powershell
aws configure --profile customprofile
```

AWS CLI solicitará el Access Key ID, Secret Access Key, región predeterminada y formato de salida.

Comprueba que el perfil funciona:

```powershell
aws sts get-caller-identity --profile customprofile
```

No guardes Access Keys ni Secret Keys en el repositorio, archivos `.tf`, `.tfvars`, README o commits. Cada integrante debe utilizar credenciales propias y con los permisos necesarios.

## 4. Inicialización de Terraform

Desde la carpeta raíz del proyecto:

```powershell
terraform init
```

Prepara las dependencias de las funciones Lambda:

```powershell
.\build-lambdas.ps1
```

Valida la configuración:

```powershell
terraform validate
terraform validate -var-file="environments/dev.tfvars"
terraform validate -var-file="environments/qa.tfvars"
terraform validate -var-file="environments/prod.tfvars"
```

Antes de desplegar, revisa siempre el plan para detectar recursos que se crearán, modificarán o eliminarán.

**Estado de Terraform:** actualmente el proyecto no tiene un backend remoto configurado. El estado local no se comparte automáticamente entre los equipos de los integrantes. No despliegues desde una copia nueva sin comprobar primero que estás utilizando el estado correspondiente al entorno.

## 5. Despliegue de DEV

Selecciona el workspace de desarrollo:

```powershell
terraform workspace select dev
```

Si todavía no existe, créalo:

```powershell
terraform workspace new dev
```

Prepara las dependencias y revisa el plan:

```powershell
.\build-lambdas.ps1
terraform plan -var-file="environments/dev.tfvars"
```

Si el plan es correcto y has confirmado que el estado corresponde a DEV, despliega:

```powershell
terraform apply -var-file="environments/dev.tfvars"
```

## 6. Despliegue de QA

Selecciona o crea el workspace de QA:

```powershell
terraform workspace select qa
```

Si no existe:

```powershell
terraform workspace new qa
```

Prepara y revisa el despliegue:

```powershell
.\build-lambdas.ps1
terraform plan -var-file="environments/qa.tfvars"
```

Después de revisar el plan y confirmar que el estado corresponde a QA:

```powershell
terraform apply -var-file="environments/qa.tfvars"
```

## 7. Despliegue de PROD

**Antes de desplegar en producción**, configura los orígenes CORS reales del frontend en `environments/prod.tfvars`. La configuración actual usa una lista vacía para evitar permitir cualquier origen mientras no se haya definido el dominio.

Selecciona o crea el workspace de producción:

```powershell
terraform workspace select prod
```

Si no existe:

```powershell
terraform workspace new prod
```

Prepara las dependencias y revisa el plan:

```powershell
.\build-lambdas.ps1
terraform plan -var-file="environments/prod.tfvars"
```

Solo cuando hayas verificado el plan, el estado y los valores de producción:

```powershell
terraform apply -var-file="environments/prod.tfvars"
```

No ejecutes `apply` si Terraform propone destruir o reemplazar recursos inesperadamente.

## 8. Prueba del endpoint

Después de desplegar, consulta el endpoint de API Gateway:

```powershell
terraform output -raw api_endpoint
```

La ruta para subir imágenes es:

```text
POST /upload
```

Por ejemplo, para enviar una imagen llamada `test.png` en formato base64 desde PowerShell:

```powershell
$api = terraform output -raw api_endpoint
$base64 = [Convert]::ToBase64String(
    [IO.File]::ReadAllBytes(".\test.png")
)
$body = @{ image = $base64 } | ConvertTo-Json -Compress

Invoke-RestMethod `
    -Method Post `
    -Uri "$api/upload" `
    -ContentType "application/json" `
    -Body $body
```

La respuesta debe incluir información de la imagen subida. Si el procesamiento asíncrono funciona correctamente, la imagen original quedará en el prefijo `uploads/` del bucket y la imagen circular procesada en `processed/`.

Revisa CloudWatch Logs si ocurre algún error.

## 9. Cómo destruir los recursos

Primero selecciona el workspace correcto:

```powershell
terraform workspace select dev
```

Revisa qué se eliminará:

```powershell
terraform plan -destroy -var-file="environments/dev.tfvars"
```

Si has confirmado que deseas eliminar ese entorno, ejecuta:

```powershell
terraform destroy -var-file="environments/dev.tfvars"
```

Para QA o PROD, selecciona el workspace correspondiente y utiliza su archivo `.tfvars`. Comprueba cuidadosamente el entorno antes de destruir recursos.

No ejecutes `destroy` desde una copia nueva del proyecto sin confirmar que dispone del estado correcto.

## 10. Estructura del proyecto

```text
aws-lambda-integration/
├── main.tf
├── variables.tf
├── versions.tf
├── outputs.tf
├── s3-sqs.tf
├── lambda.tf
├── lambda-iam.tf
├── lambda-security-group.tf
├── api-gateway.tf
├── vpc-endpoints.tf
├── cloudwatch.tf
├── build-lambdas.ps1
├── environments/
│   ├── dev.tfvars
│   ├── qa.tfvars
│   └── prod.tfvars
└── lambda/
    ├── upload/
    │   ├── index.mjs
    │   ├── package.json
    │   └── package-lock.json
    └── crop/
        ├── index.mjs
        ├── package.json
        └── package-lock.json
```

Los archivos `.tf` definen la infraestructura, `environments/` contiene la configuración por entorno y `lambda/` contiene el código de las funciones. El script `build-lambdas.ps1` instala las dependencias necesarias para crear los paquetes de despliegue.

### Alertas por correo

La variable `alarm_email` permite configurar un correo para recibir las alertas de SNS. Para habilitar la suscripción, proporciona un correo al ejecutar Terraform, por ejemplo:

```powershell
terraform apply -var-file="environments/dev.tfvars" -var="alarm_email=correo@example.com"
```
