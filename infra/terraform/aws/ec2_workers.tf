resource "aws_instance" "worker" {
  count                       = 6
  ami                         = data.aws_ami.ubuntu_2204.id
  instance_type               = var.instance_type_worker
  subnet_id                   = aws_subnet.private[count.index % var.az_count].id
  vpc_security_group_ids      = [aws_security_group.nodes.id]
  key_name                    = var.key_pair_name
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.nodes.name
  user_data                   = file("${path.module}/user-data.sh")

  root_block_device {
    volume_size = var.root_volume_gb
    volume_type = "gp3"
  }

  tags = {
    Name                                        = "${var.cluster_name}-w${count.index + 1}"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    "k8s.io/role"                               = "worker"
  }
}
