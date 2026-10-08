variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment"
  type        = string

  validation {
    condition     = contains(["dev", "qa", "prod"], var.environment)
    error_message = "Environment must be dev, qa or prod."
  }
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "image-processor"
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_a_cidr" {
  type    = string
  default = "10.0.1.0/24"
}

variable "public_subnet_b_cidr" {
  type    = string
  default = "10.0.2.0/24"
}

variable "private_subnet_a_cidr" {
  type    = string
  default = "10.0.11.0/24"
}

variable "private_subnet_b_cidr" {
  type    = string
  default = "10.0.12.0/24"
}

# --- VARIABLES REQUERIDAS PARA LAMBDAS (PR 3) ---

variable "upload_lambda_role_arn" {
  type        = string
  description = "ARN del rol de IAM para Upload Lambda (creado en PR 4)"
  default     = "arn:aws:iam::123456789012:role/upload-lambda-role"
}

variable "crop_lambda_role_arn" {
  type        = string
  description = "ARN del rol de IAM para Crop Lambda (creado en PR 4)"
  default     = "arn:aws:iam::123456789012:role/crop-lambda-role"
}

variable "lambda_security_group_id" {
  type        = string
  description = "ID del Security Group para Lambdas (creado en PR 4)"
  default     = "sg-12345678"
}