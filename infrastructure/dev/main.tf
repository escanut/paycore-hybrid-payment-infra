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
}