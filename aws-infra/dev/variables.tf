# Networking variables
variable "region_name" {
  type = string
}

variable "vpc_cidr" {
  
  type = string
}

variable "ec2_pub_key" {
  type = string
}

variable "wg_private_keys" {
  type = list(string)
}

variable "on_prem_public_key" {
  type = string
}


# Compute variables

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

variable "proxmox_vpn_ip" {
  type = string
}



# Messaging variables
variable "email" {
  type = string
}

# Storage variables
variable "bucket_name" {
  type = string
}
