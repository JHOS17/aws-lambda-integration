# S3 Gateway Endpoint: agrega una ruta a S3 en las tablas de rutas privadas
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    aws_route_table.private_a.id,
    aws_route_table.private_b.id
  ]

  tags = merge(local.common_tags, {
    Name = "${local.name}-s3-endpoint"
  })
}

# Security Group del endpoint SQS: solo acepta HTTPS desde las Lambdas
resource "aws_security_group" "sqs_endpoint" {
  name        = "${local.name}-sqs-endpoint-sg"
  description = "Security group for the SQS interface endpoint"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTPS from Lambda security group"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda.id]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name}-sqs-endpoint-sg"
  })
}

# SQS Interface Endpoint en las subredes privadas
resource "aws_vpc_endpoint" "sqs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.sqs"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]

  security_group_ids = [aws_security_group.sqs_endpoint.id]

  tags = merge(local.common_tags, {
    Name = "${local.name}-sqs-endpoint"
  })
}