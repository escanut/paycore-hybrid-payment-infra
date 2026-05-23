# SQS queue for receiving payload from fastapi
resource "aws_sqs_queue" "queue" {
    name = "paycore-transactions"
    visibility_timeout_seconds = 30
    message_retention_seconds = 86400
    receive_wait_time_seconds = 10

    redrive_policy = jsonencode({
        deadLetterTargetArn = aws_sqs_queue.dlq.arn
        maxReceiveCount = 3
    })

}

resource "aws_sqs_queue" "dlq" {
  name = "paycore-dlq"

}

# SNS to trigger alarm for errors
resource "aws_sns_topic" "fraud_alerts" {
  name = "paycore-fraud-alerts"
}

resource "aws_sns_topic_subscription" "fraud_email" {
    topic_arn = aws_sns_topic.fraud_alerts.arn
    protocol = "email"
    endpoint = var.email
}