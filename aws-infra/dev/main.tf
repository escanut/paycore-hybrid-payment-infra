provider "aws" {
  region = var.region_name

  default_tags {
    tags = {
      Environment = "dev"
      Project = "paycore"
      Owner = "victor"
      ManagedBy = "terraform"
    }
  }
}

module "networking" {
  
  source = "../modules/vpn_networking"

  vpc_cidr = var.vpc_cidr
  region_name = var.region_name
  on_prem_public_key = var.on_prem_public_key
  wg_private_keys = var.wg_private_keys
  ec2_pub_key = var.ec2_pub_key
}

module "compute" {
  source = "../modules/compute"
  
  kms_key_arn = module.kms.key_arn
  bucket_name = module.storage.s3_bucket_name
  sns_topic_arn = module.messaging.sns_topic_arn
  sqs_queue_arn = module.messaging.sqs_queue_arn
  region_name = var.region_name
  secret_key = var.secret_key
  cloudflare_token = var.cloudflare_token
  callback_api_key = var.callback_api_key
  proxmox_vpn_ip = var.proxmox_vpn_ip
  db_username = var.db_username
  db_password = var.db_password
  subnet_ids = module.networking.public_subnet_ids
  security_group_id = module.networking.lambda_security_group_id

}

module "kms" {
  source = "../modules/kms"
}

module "messaging" {
  source = "../modules/messaging"
  email = var.email
}

module "storage" {
  source = "../modules/storage"
  
  kms_key_arn = module.kms.key_arn
  bucket_name = var.bucket_name
}

