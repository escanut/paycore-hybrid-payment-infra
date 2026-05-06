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
  
  source = "../modules/VPN_Networking"

  vpc_cidr = var.vpc_cidr
  region_name = var.region_name
  on_prem_public_key = var.on_prem_public_key
  wg_private_keys = var.wg_private_keys
}