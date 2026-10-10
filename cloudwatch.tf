# Logs de las Lambdas: retención de 14 días

resource "aws_cloudwatch_log_group" "upload_lambda" {
  name              = "/aws/lambda/image-processor-${var.environment}-upload"
  retention_in_days = 14

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "crop_lambda" {
  name              = "/aws/lambda/image-processor-${var.environment}-crop"
  retention_in_days = 14

  tags = local.common_tags
}

# Tema SNS para las alertas del proyecto

resource "aws_sns_topic" "alerts" {
  name = "${local.name}-alerts"

  tags = local.common_tags
}

# Email opcional para recibir las alertas

variable "alarm_email" {
  description = "Email opcional para recibir alertas de SNS"
  type        = string
  default     = null
}

resource "aws_sns_topic_subscription" "email_alerts" {
  count = var.alarm_email != null && var.alarm_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# Alarma cuando hay mensajes visibles en la DLQ

resource "aws_cloudwatch_metric_alarm" "dlq_messages_visible" {
  alarm_name        = "${local.name}-dlq-messages-visible"
  alarm_description = "Hay mensajes pendientes en la Dead Letter Queue"

  namespace   = "AWS/SQS"
  metric_name = "ApproximateNumberOfMessagesVisible"
  dimensions = {
    QueueName = aws_sqs_queue.dlq.name
  }

  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 1
  datapoints_to_alarm = 1

  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.alerts.arn]

  tags = local.common_tags
}
