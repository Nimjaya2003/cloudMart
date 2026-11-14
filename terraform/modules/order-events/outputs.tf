output "topic_arn" {
  value = aws_sns_topic.order_events.arn
}

output "queue_url" {
  value = aws_sqs_queue.notifications.id
}

output "dlq_url" {
  value = aws_sqs_queue.dlq.id
}

output "function_name" {
  value = aws_lambda_function.notifier.function_name
}