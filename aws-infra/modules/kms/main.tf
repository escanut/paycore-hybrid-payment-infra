
resource "aws_kms_key" "paycore" {

  deletion_window_in_days = 7
  enable_key_rotation = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/victorojeje"
        }
        Action = "kms:*"
        Resource = "*"
      },

      {
        # To give Iam access
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = "kms:*"
        Resource = "*"
      },

      {
        # For s3
        Effect = "Allow"
        Principal = {
        Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
        
      }
    ]
  })

}


resource "aws_kms_alias" "paycore" {

  name = "alias/paycore"
  target_key_id = aws_kms_key.paycore.key_id
 
}

data "aws_caller_identity" "current" {}


