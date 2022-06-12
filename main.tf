variable "region" {
  description = "AWS Region"
  type        = string
}

variable "ttl" {
  description = "The TTL of the records."
  type        = number
  default     = 1
}

variable "domain" {
  description = "By default, Consul responds to DNS queries in the \"consul\" domain. This flag can be used to change that domain."
  type        = string
  default     = "consul"
}

provider "aws" {
  region = var.region
}

variable "services" {
  description = "Consul services monitored by Consul-Terraform-Sync"
  type = map(
    object({
      id        = string
      name      = string
      kind      = string
      address   = string
      port      = number
      meta      = map(string)
      tags      = list(string)
      namespace = string
      status    = string

      node                  = string
      node_id               = string
      node_address          = string
      node_datacenter       = string
      node_tagged_addresses = map(string)
      node_meta             = map(string)

      cts_user_defined_meta = map(string)
    })
  )
}

variable "zone_id" {
  type        = string
  description = "The ID of the hosted zone."
}

locals {
  exclude_kind = ["ingress-gateway", "connect-proxy"]

  services = distinct([
    for service in values(var.services) : service
    if !contains(local.exclude_kind, service.kind)
    && service.status == "passing"
  ])

  service_names = distinct([
    for service in local.services : service.name
  ])

  records = flatten([
    for name in local.service_names : flatten([
      for service in local.services : flatten([
        [
          {
            name  = "${service.name}.service.${var.domain}"
            type  = try(regex(":", service.address), null) == null ? "A" : "AAAA"
            value = service.address
          },
          {
            name  = "${service.name}.service.${service.node_datacenter}.${var.domain}"
            type  = try(regex(":", service.address), null) == null ? "A" : "AAAA"
            value = service.address
          },
          {
            name  = "${service.name}.service.${var.domain}"
            type  = "SRV"
            value = "1 1 ${service.port} ${service.address}"
          },
          {
            name  = "${service.name}.service.${service.node_datacenter}.${var.domain}"
            type  = "SRV"
            value = "1 1 ${service.port} ${service.address}"
          },
        ],
        [
          for tag in service.tags : {
            name  = "${tag}.${service.name}.service.${var.domain}"
            type  = try(regex(":", service.address), null) == null ? "A" : "AAAA"
            value = service.address
          }
        ],
        [
          for tag in service.tags : {
            name  = "${tag}.${service.name}.service.${service.node_datacenter}.${var.domain}"
            type  = try(regex(":", service.address), null) == null ? "A" : "AAAA"
            value = service.address
          }
        ],
        [
          for tag in service.tags : {
            name  = "${tag}.${service.name}.service.${var.domain}"
            type  = "SRV"
            value = "1 1 ${service.port} ${service.address}"
          }
        ],
        [
          for tag in service.tags : {
            name  = "${tag}.${service.name}.service.${service.node_datacenter}.${var.domain}"
            type  = "SRV"
            value = "1 1 ${service.port} ${service.address}"
          }
        ],
      ]) if service.name == name
    ])
  ])

  record_names = distinct([for record in local.records : record.name])

  a_records_by_name    = { for name in local.record_names : name => distinct([for record in local.records : record.value if record.name == name && record.type == "A"]) }
  aaaa_records_by_name = { for name in local.record_names : name => distinct([for record in local.records : record.value if record.name == name && record.type == "AAAA"]) }
  srv_records_by_name  = { for name in local.record_names : name => distinct([for record in local.records : record.value if record.name == name && record.type == "SRV"]) }

  a_records    = { for key, value in local.a_records_by_name : key => value if length(value) > 0 }
  aaaa_records = { for key, value in local.aaaa_records_by_name : key => value if length(value) > 0 }
  srv_records  = { for key, value in local.srv_records_by_name : key => value if length(value) > 0 }

  # values = {
  #   A = local.A
  #   AAAA = local.AAAA
  #   SRV = local.SRV
  # }
}

resource "aws_route53_record" "a" {
  for_each = local.a_records

  type    = "A"
  zone_id = var.zone_id
  ttl     = var.ttl
  name    = each.key
  records = each.value
}

resource "aws_route53_record" "aaaa" {
  for_each = local.aaaa_records

  type    = "AAAA"
  zone_id = var.zone_id
  ttl     = var.ttl
  name    = each.key
  records = each.value
}

resource "aws_route53_record" "srv" {
  for_each = local.srv_records

  type    = "SRV"
  zone_id = var.zone_id
  ttl     = var.ttl
  name    = each.key
  records = each.value
}

# resource "null_resource" "null_resource" {
#   provisioner "local-exec" {
#     command = "echo '${jsonencode(local.SRV)}' | jq > test.json"
#   }
#
#   triggers = {
#     values = sha1(jsonencode(local.SRV))
#   }
# }
