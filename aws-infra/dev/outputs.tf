# Networking outputs
output "instance_public_ips" {
  value = module.networking.instance_public_ips
}

output "wg_gateway_eip" {
  value = module.networking.wg_gateway_eip
}

output "instance_ids" {
  value = module.networking.instance_ids
}

output "lambda_security_group_id" {
  value = module.networking.lambda_security_group_id
}

output "public_subnet_ids" {
  value = module.networking.public_subnet_ids
}

# Compute outputs


# Kms outputs
output "key_arn" {
  value = module.kms.key_arn
}

output "key_id" {
  value = module.kms.key_id
}


# Messaging outputs
output "sqs_queue_arn" {
     value = module.messaging.sqs_queue_arn
}

output "sqs_queue_url" { 
    value = module.messaging.sqs_queue_url
}

output "sns_topic_arn" { 
    value = module.messaging.sns_topic_arn
}

# Storage outputs
output "s3_bucket_name" {
  value = module.storage.s3_bucket_name
}

output "s3_bucket_arn" {
  value = module.storage.s3_bucket_arn
}


