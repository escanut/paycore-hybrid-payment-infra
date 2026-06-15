# Lambda setup for processing transactions from sqs


resource "aws_security_group" "lambda" {
  vpc_id = var.vpc_id

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "validator" {
    name = "paycore-validator-role"

    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Effect = "Allow"
                Principal = { Service = "lambda.amazonaws.com" }
                Action = "sts:AssumeRole"
            }
        ]
    })
}

resource "aws_iam_role_policy" "validator_policy" {
  
  role = aws_iam_role.validator.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
        {
            Effect = "Allow"
            Action = [
                "sqs:SendMessage",
                "sqs:ReceiveMessage",
                "sqs:DeleteMessage",
                "sqs:GetQueueAttributes",
                "sqs:ChangeMessageVisibility"

            ]

            Resource = var.sqs_queue_arn
        },

        {
            Effect = "Allow"
            Action = [
                "sns:Publish"
            ]
            Resource = var.sns_topic_arn
        },

        {
            Effect = "Allow"
            Action = [
                "ec2:CreateNetworkInterface",
                "ec2:DeleteNetworkInterface",
                "ec2:DescribeNetworkInterfaces",
                "ec2:DescribeInstances",
                "ec2:DescribeInstanceStatus",
                "ec2:DescribeVpnConnections"
            ]
            Resource = "*"
        },

        {
            Effect = "Allow"
            Action = [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ]
            Resource = "arn:aws:logs:*:*:*"
        },

        {
            Effect = "Allow"
            Action = [
                "secretsmanager:GetSecretValue"
            ]
            Resource = "arn:aws:secretsmanager:${var.region_name}:*:secret:paycore/internal/config*"

        },

        {
            Effect = "Allow"
            Action = [
                "kms:Decrypt",
                "kms:GenerateDataKey"
            ]
            Resource = var.kms_key_arn
        },

        {
            Effect = "Allow"
            Action = [
                "s3:PutObject"
            ]
            Resource = "arn:aws:s3:::${var.bucket_name}/transactions/*"
        }
    ]
  })
}

# File for lambda function
data "archive_file" "validator" {

  type = "zip"
  source_file = "${path.module}/scripts/validator.py"
  output_path = "${path.module}/scripts/validator.zip"


}

resource "aws_lambda_function" "validator" {
  filename = data.archive_file.validator.output_path
  function_name = "paycore-validator"
  role = aws_iam_role.validator.arn
  handler = "validator.lambda_handler" 
  runtime = "python3.12"
  source_code_hash = data.archive_file.validator.output_base64sha256
  timeout = 30

  vpc_config {
    subnet_ids = var.subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      SNS_TOPIC_ARN = var.sns_topic_arn
      S3_BUCKET = var.bucket_name
      SECRET_NAME = aws_secretsmanager_secret.config.name
      PROXMOX_VPN_IP = var.proxmox_vpn_ip
      REGION_NAME = var.region_name
    }
  }
}



resource "aws_lambda_event_source_mapping" "validator" {
  event_source_arn = var.sqs_queue_arn
  function_name = aws_lambda_function.validator.arn
  batch_size = 1
}

# Secrets manager to replace .env for both app config and db
resource "aws_secretsmanager_secret" "config" {
  name = "paycore/internal/config"
  kms_key_id = var.kms_key_arn
  recovery_window_in_days = 0 # For debugging and testing
}

resource "aws_secretsmanager_secret_version" "config" {
  secret_id = aws_secretsmanager_secret.config.id
  secret_string = jsonencode({
    secret_key = var.secret_key
    cloudflare_token = var.cloudflare_token
    callback_api_key = var.callback_api_key
  })
}


resource "aws_secretsmanager_secret" "db" {
  name = "paycore/internal/db"
  kms_key_id = var.kms_key_arn
  recovery_window_in_days = 0 # For debugging and testing
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    db_username = var.db_username
    db_password = var.db_password

  })
}