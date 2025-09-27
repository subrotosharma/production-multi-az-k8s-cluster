resource "aws_lb" "api" {
  name               = "${var.cluster_name}-api"
  load_balancer_type = "network"
  internal           = var.lb_internal
  subnets            = [for s in aws_subnet.public : s.id]
  security_groups    = [aws_security_group.nlb_api.id]
  tags               = { Name = "${var.cluster_name}-api-nlb" }
}

resource "aws_lb_target_group" "api" {
  name        = "${var.cluster_name}-api-6443"
  port        = 6443
  protocol    = "TCP"
  vpc_id      = aws_vpc.this.id
  target_type = "instance"
  health_check {
    enabled  = true
    port     = "6443"
    protocol = "TCP"
  }
}

resource "aws_lb_target_group_attachment" "api" {
  for_each         = { for i, inst in aws_instance.master : i => inst.id }
  target_group_arn = aws_lb_target_group.api.arn
  target_id        = each.value
  port             = 6443
}

resource "aws_lb_listener" "api" {
  load_balancer_arn = aws_lb.api.arn
  port              = 6443
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}
