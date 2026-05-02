output "wg_eips" {
  description = "All elastic ips"
  value = aws_eip.wg_eip[*].public_ip
}