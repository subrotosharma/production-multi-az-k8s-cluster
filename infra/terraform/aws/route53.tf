# Set create_route53=true and provide hosted_zone_id to manage records here.
locals {
  # These locals assume the hosted zone matches the suffix of your FQDNs.
}

data "aws_route53_zone" "zone" {
  count  = var.create_route53 ? 1 : 0
  zone_id = var.hosted_zone_id
}

resource "aws_route53_record" "api" {
  count   = var.create_route53 ? 1 : 0
  zone_id = data.aws_route53_zone.zone[0].zone_id
  name    = var.api_fqdn
  type    = "A"
  alias {
    name                   = aws_lb.api.dns_name
    zone_id                = aws_lb.api.zone_id
    evaluate_target_health = false
  }
}
