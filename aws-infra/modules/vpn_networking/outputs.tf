output "instance_public_ips" {
  value = aws_instance.wg_ec2[*].public_ip
}

output "wg_gateway_eip" {
  value = aws_eip.wg_gateway.public_ip
}

output "instance_ids" {
  value = aws_instance.wg_ec2[*].id
}