output "wg_eips" {
  description = "All elastic ips"
  value = module.networking.wg_eips
}