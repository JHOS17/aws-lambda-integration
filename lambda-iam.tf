# Roles de ejecución de las Lambdas

resource "aws_iam_role" "upload_lambda" {
  name = "${local.name}-upload-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role" "crop_lambda" {
  name = "${local.name}-crop-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = local.common_tags
}

# Permisos básicos de CloudWatch Logs y acceso a la VPC

resource "aws_iam_role_policy_attachment" "upload_basic" {
  role       = aws_iam_role.upload_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "crop_basic" {
  role       = aws_iam_role.crop_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "upload_vpc" {
  role       = aws_iam_role.upload_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "crop_vpc" {
  role       = aws_iam_role.crop_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Upload solo puede guardar imágenes en uploads/

resource "aws_iam_role_policy" "upload_s3_access" {
  name = "${local.name}-upload-s3-access"
  role = aws_iam_role.upload_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:PutObject"]
      Resource = "${aws_s3_bucket.data_bucket.arn}/uploads/*"
    }]
  })
}

# Crop puede leer uploads/ y escribir en processed/

resource "aws_iam_role_policy" "crop_s3_access" {
  name = "${local.name}-crop-s3-access"
  role = aws_iam_role.crop_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.data_bucket.arn}/uploads/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "${aws_s3_bucket.data_bucket.arn}/processed/*"
      }
    ]
  })
}

# Permisos para que Crop consuma mensajes de SQS

data "aws_region" "current" {}

data "aws_partition" "current" {}

resource "aws_iam_role_policy" "crop_sqs_access" {
  name = "${local.name}-crop-sqs-access"
  role = aws_iam_role.crop_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility"
        ]
        Resource = aws_sqs_queue.main_queue.arn
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService"                    = "sqs.${data.aws_region.current.region}.${data.aws_partition.current.dns_suffix}"
            "kms:EncryptionContext:aws:sqs:arn" = aws_sqs_queue.main_queue.arn
          }
        }
      }
    ]
  })
}