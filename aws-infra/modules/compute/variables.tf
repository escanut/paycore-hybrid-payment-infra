variable "kms_key_arn" {
  type = string
}

variable "secret_key" {
  type = string
}

variable "cloudflare_token" {
  type = string
}

variable "callback_api_key" {
  type = string
}

variable "db_password" {
  type = string
}

variable "db_username" {
  type = string
}

variable "bucket_name" {
  type = string
}

variable "sns_topic_arn" {
  type = string
}

variable "proxmox_vpn_ip" {
  type = string
}

variable "sqs_queue_arn" {
  type = string
}

variable "region_name" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_id" {
  type = string
}