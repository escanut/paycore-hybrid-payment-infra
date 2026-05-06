variable "region_name" {
  type = string
}

variable "vpc_cidr" {
  
  type = string
}

variable "wg_private_keys" {
  type = list(string)
}

variable "on_prem_public_key" {
  type = string
}
