output "bastion_public_ip"      { value = aws_instance.bastion.public_ip }
output "master_private_ips"     { value = [for i in aws_instance.master : i.private_ip] }
output "worker_private_ips"     { value = [for i in aws_instance.worker : i.private_ip] }
output "api_nlb_dns"            { value = aws_lb.api.dns_name }
output "vpc_id"                 { value = aws_vpc.this.id }
output "public_subnet_ids"      { value = [for s in aws_subnet.public : s.id] }
output "private_subnet_ids"     { value = [for s in aws_subnet.private : s.id] }
