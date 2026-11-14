# ===================== 1. The announcement board =====================
resource "aws_sns_topic" "order_events" {
  name = "${var.name}-order-events"
}

# ===================== 2. The waiting line and its problem tray =====================
resource "aws_sqs_queue" "dlq" {
  name                      = "${var.name}-order-notifications-dlq"
  message_retention_seconds = 1209600 # keep failed messages 14 days, so there's time to investigate
  sqs_managed_sse_enabled   = true
}

resource "aws_sqs_queue" "notifications" {
  name                       = "${var.name}-order-notifications"
  visibility_timeout_seconds = 60 # must be longer than the Lambda timeout (10s); AWS recommends 6x
  sqs_managed_sse_enabled    = true

  # After 3 failed receives, move the message to the dead-letter queue
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3
  })
}

# Permission: ONLY this SNS topic may put messages into this queue
data "aws_iam_policy_document" "queue_from_topic" {
  statement {
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.notifications.arn]

    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_sns_topic.order_events.arn]
    }
  }
}

resource "aws_sqs_queue_policy" "notifications" {
  queue_url = aws_sqs_queue.notifications.id
  policy    = data.aws_iam_policy_document.queue_from_topic.json
}

# Connect the board to the queue. Raw delivery = the queue gets exactly our JSON, with no SNS wrapper.
resource "aws_sns_topic_subscription" "queue" {
  topic_arn            = aws_sns_topic.order_events.arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.notifications.arn
  raw_message_delivery = true

  depends_on = [aws_sqs_queue_policy.notifications]
}

# ===================== 3. The outgoing mail topic (your email) =====================
resource "aws_sns_topic" "notifications" {
  name = "${var.name}-notifications"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.notifications.arn
  protocol  = "email"
  endpoint  = var.notification_email # AWS emails a link you must click to confirm
}

# ===================== 4. The Lambda that turns events into emails =====================
data "archive_file" "notifier" {
  type        = "zip"
  source_file = "${path.module}/lambda/handler.py"
  output_path = "${path.module}/notifier.zip"
}

resource "aws_cloudwatch_log_group" "notifier" {
  name              = "/aws/lambda/${var.name}-order-notifier"
  retention_in_days = 7
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "notifier" {
  name               = "${var.name}-order-notifier-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

# Write logs to CloudWatch (AWS-managed policy)
resource "aws_iam_role_policy_attachment" "notifier_logs" {
  role       = aws_iam_role.notifier.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Least privilege: read ONE queue, publish to ONE topic
data "aws_iam_policy_document" "notifier" {
  statement {
    actions   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
    resources = [aws_sqs_queue.notifications.arn]
  }

  statement {
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.notifications.arn]
  }
}

resource "aws_iam_role_policy" "notifier" {
  name   = "consume-queue-and-notify"
  role   = aws_iam_role.notifier.id
  policy = data.aws_iam_policy_document.notifier.json
}

resource "aws_lambda_function" "notifier" {
  function_name    = "${var.name}-order-notifier"
  role             = aws_iam_role.notifier.arn
  runtime          = "python3.12"
  handler          = "handler.handler" # file handler.py, function handler
  filename         = data.archive_file.notifier.output_path
  source_code_hash = data.archive_file.notifier.output_base64sha256
  timeout          = 10
  memory_size      = 128

  environment {
    variables = {
      NOTIFICATION_TOPIC_ARN = aws_sns_topic.notifications.arn
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.notifier,
    aws_iam_role_policy_attachment.notifier_logs,
  ]
}

# The link between queue and function: Lambda polls the queue for you
resource "aws_lambda_event_source_mapping" "notifier" {
  event_source_arn        = aws_sqs_queue.notifications.arn
  function_name           = aws_lambda_function.notifier.arn
  batch_size              = 5
  function_response_types = ["ReportBatchItemFailures"] # enables the partial-failure reply

  depends_on = [aws_iam_role_policy.notifier] # the role needs queue access before the mapping is created
}

# ===================== 5. An alarm when messages end up in the problem tray =====================
resource "aws_cloudwatch_metric_alarm" "dlq_not_empty" {
  alarm_name          = "${var.name}-order-notifications-dlq-not-empty"
  alarm_description   = "Order notifications failed repeatedly and landed in the dead-letter queue"
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  dimensions          = { QueueName = aws_sqs_queue.dlq.name }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.notifications.arn]
}