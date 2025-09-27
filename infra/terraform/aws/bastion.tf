resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.ubuntu_2204.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  key_name                    = var.key_pair_name
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.nodes.name

  user_data = <<-CLOUD
    #cloud-config
    packages:
      - unzip
      - awscli
      - jq
      - htop
    runcmd:
      - apt-get update -y
      - snap install amazon-ssm-agent --classic || true
      - systemctl enable --now snap.amazon-ssm-agent.amazon-ssm-agent || true
  CLOUD

  tags = { Name = "${var.cluster_name}-bastion" }
}
