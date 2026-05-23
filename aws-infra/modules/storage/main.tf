# S3 will be used for storing raw transaction log
resource "aws_s3_bucket" "transactions" {

  bucket = var.bucket_name
  
  # if this were production, we would use object lock
  # and set the lock to compliance mode

  # object_lock_enabled = true
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "bucket" {
  
  bucket = aws_s3_bucket.transactions.id
  
  versioning_configuration {
    status = "Enabled"
  }

}

# For demonstation

# resource "aws_s3_bucket_object_lock_configuration" "this" {
#  bucket = aws_s3_bucket.paycore_transactions.id

#  rule {
#      default_retention {
#      mode = "COMPLIANCE"
#      days = 365
#    }
#  }
# }

resource "aws_s3_bucket_server_side_encryption_configuration" "bucket" {
  
  bucket = aws_s3_bucket.transactions.id

  rule {
    apply_server_side_encryption_by_default {

      sse_algorithm = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}


resource "aws_s3_bucket_public_access_block" "bucket" {

  bucket = aws_s3_bucket.transactions.id
  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true

}