output "sqs_queue_arn" {
     value = aws_sqs_queue.queue.arn 
}

output "sqs_queue_url" { 
    value = aws_sqs_queue.queue.url
}

output "sns_topic_arn" { 
    value = aws_sns_topic.fraud_alerts.arn
}