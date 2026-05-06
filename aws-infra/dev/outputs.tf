
output "instance_public_ips" {
  value = module.networking.instance_public_ips
}

output "wg_gateway_eip" {
  value = module.networking.wg_gateway_eip
}

output "instance_ids" {
  value = module.networking.instance_ids
}