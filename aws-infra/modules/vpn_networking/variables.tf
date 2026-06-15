variable "vpc_cidr" {
  
  type = string
}

variable "wg_private_keys" {
  type = string
  sensitive = true
}

variable "on_prem_public_key" {
  type = string
}

variable "region_name" {
  type = string
}

variable "ec2_pub_key" {
  type = string
}