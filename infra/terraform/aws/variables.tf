variable "region" {
  type    = string
  default = "us-east-1"
}

variable "cluster_name" {
  type    = string
  default = "ha-cluster"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "az_count" {
  type    = number
  default = 3
}

variable "create_route53" {
  type    = bool
  default = false
}

variable "hosted_zone_id" {
  type    = string
  default = ""
}

variable "api_fqdn" {
  type    = string
  default = "api.k8s.subrotosharma.site"
}

variable "apps_wildcard_fqdn" {
  type    = string
  default = "*.apps.subrotosharma.site"
}

variable "lb_internal" {
  type    = bool
  default = true
}

variable "my_ip_cidr" {
  type    = string
  default = "0.0.0.0/0"
}

variable "instance_type_master" {
  type    = string
  default = "t3.xlarge"
}

variable "instance_type_worker" {
  type    = string
  default = "t3.xlarge"
}

variable "root_volume_gb" {
  type    = number
  default = 80
}

variable "key_pair_name" {
  type    = string
  default = null
}
