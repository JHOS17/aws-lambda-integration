resource "aws_security_group" "lambda" {
  name        = "${local.name}-lambda-sg"
  description = "Security group for image processing Lambdas"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "HTTPS outbound"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name}-lambda-sg"
  })
}