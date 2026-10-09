output "environment" {
  description = "Deployment environment"
  value       = var.environment
}

output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id
  ]
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]
}

# Lambda
output "upload_lambda_arn" {
  description = "ARN de la función Upload Lambda para integración en API Gateway (PR 4)"
  value       = aws_lambda_function.upload_lambda.arn
}

output "upload_lambda_function_name" {
  description = "Nombre de la función Upload Lambda"
  value       = aws_lambda_function.upload_lambda.function_name
}

output "crop_lambda_arn" {
  description = "ARN de la función Crop Lambda"
  value       = aws_lambda_function.crop_lambda.arn
}

output "crop_lambda_function_name" {
  description = "Nombre de la función Crop Lambda"
  value       = aws_lambda_function.crop_lambda.function_name
}