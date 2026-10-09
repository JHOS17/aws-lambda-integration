# Empaquetado del código Node.js a ZIP
data "archive_file" "upload_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/upload"
  output_path = "${path.module}/lambda/upload.zip"
  excludes    = ["node_modules/.cache", "package-lock.json"]
}

data "archive_file" "crop_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/crop"
  output_path = "${path.module}/lambda/crop.zip"
  excludes    = ["node_modules/.cache", "package-lock.json"]
}

# Upload Lambda
resource "aws_lambda_function" "upload_lambda" {
  filename         = data.archive_file.upload_lambda_zip.output_path
  function_name    = "image-processor-${var.environment}-upload"
  role             = aws_iam_role.upload_lambda.arn
  handler          = "index.handler"
  runtime          = "nodejs22.x"
  memory_size      = 256
  timeout          = 30
  source_code_hash = data.archive_file.upload_lambda_zip.output_base64sha256

  vpc_config {
    subnet_ids         = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      S3_BUCKET     = aws_s3_bucket.data_bucket.id
      UPLOAD_PREFIX = "uploads/"
    }
  }

  tags = {
    Name = "image-processor-${var.environment}-upload"
  }

  depends_on = [
    aws_iam_role_policy_attachment.upload_basic,
    aws_iam_role_policy_attachment.upload_vpc,
    aws_iam_role_policy.upload_s3_access
  ]
}

# Crop Lambda
resource "aws_lambda_function" "crop_lambda" {
  filename         = data.archive_file.crop_lambda_zip.output_path
  function_name    = "image-processor-${var.environment}-crop"
  role             = aws_iam_role.crop_lambda.arn
  handler          = "index.handler"
  runtime          = "nodejs22.x"
  memory_size      = 512
  timeout          = 60
  source_code_hash = data.archive_file.crop_lambda_zip.output_base64sha256

  vpc_config {
    subnet_ids         = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      S3_BUCKET        = aws_s3_bucket.data_bucket.id
      PROCESSED_PREFIX = "processed/"
    }
  }

  tags = {
    Name = "image-processor-${var.environment}-crop"
  }

  depends_on = [
    aws_iam_role_policy_attachment.crop_basic,
    aws_iam_role_policy_attachment.crop_vpc,
    aws_iam_role_policy.crop_s3_access,
    aws_iam_role_policy.crop_sqs_access
  ]
}

# Event Source Mapping: SQS → Crop Lambda
resource "aws_lambda_event_source_mapping" "sqs_crop_trigger" {
  event_source_arn        = aws_sqs_queue.main_queue.arn
  function_name           = aws_lambda_function.crop_lambda.arn
  batch_size              = 5
  function_response_types = ["ReportBatchItemFailures"]
  enabled                 = true

  depends_on = [
    aws_lambda_function.crop_lambda,
    aws_sqs_queue.main_queue
  ]
}