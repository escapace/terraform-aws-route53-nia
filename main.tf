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

variable "prefer_wan_address" {
  description = "If set to true, on node lookups will prefer a node's configured WAN address."
  type        = bool
  default     = false
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

  node_ids = distinct([
    for service in var.services : service.node_id
  ])

  node_tagged_addresses_preference_ipv4 = var.prefer_wan_address ? ["wan_ipv4", "lan_ipv4"] : ["lan_ipv4", "wan_ipv4"]
  node_tagged_addresses_preference_ipv6 = var.prefer_wan_address ? ["wan_ipv6", "lan_ipv6"] : ["lan_ipv6", "wan_ipv6"]

  node_records = [for value in flatten(values({
    for node_id in local.node_ids : node_id => [
      merge([
        for service in var.services : {
          name  = "${service.node}.node.${service.node_datacenter}.${var.domain}"
          type  = "A"
          value = coalesce(lookup(service.node_tagged_addresses, local.node_tagged_addresses_preference_ipv4[0], null), lookup(service.node_tagged_addresses, local.node_tagged_addresses_preference_ipv4[1], null))
        } if service.node_id == node_id && (contains(keys(service.node_tagged_addresses), "lan_ipv4") || contains(keys(service.node_tagged_addresses), "wan_ipv4"))
      ]...),
      merge([
        for service in var.services : {
          name  = "${service.node}.node.${var.domain}"
          type  = "A"
          value = coalesce(lookup(service.node_tagged_addresses, local.node_tagged_addresses_preference_ipv4[0], null), lookup(service.node_tagged_addresses, local.node_tagged_addresses_preference_ipv4[1], null))
        } if service.node_id == node_id && (contains(keys(service.node_tagged_addresses), "lan_ipv4") || contains(keys(service.node_tagged_addresses), "wan_ipv4"))
      ]...),
      merge([
        for service in var.services : {
          name  = "${service.node}.node.${service.node_datacenter}.${var.domain}"
          type  = "AAAA"
          value = coalesce(lookup(service.node_tagged_addresses, local.node_tagged_addresses_preference_ipv6[0], null), lookup(service.node_tagged_addresses, local.node_tagged_addresses_preference_ipv6[1], null))
        } if service.node_id == node_id && (contains(keys(service.node_tagged_addresses), "lan_ipv6") || contains(keys(service.node_tagged_addresses), "wan_ipv6"))
      ]...),
      merge([
        for service in var.services : {
          name  = "${service.node}.node.${var.domain}"
          type  = "AAAA"
          value = coalesce(lookup(service.node_tagged_addresses, local.node_tagged_addresses_preference_ipv6[0], null), lookup(service.node_tagged_addresses, local.node_tagged_addresses_preference_ipv6[1], null))
        } if service.node_id == node_id && (contains(keys(service.node_tagged_addresses), "lan_ipv6") || contains(keys(service.node_tagged_addresses), "wan_ipv6"))
      ]...)
    ]
  })) : value if length(keys(value)) == 3]

  service_records = flatten([
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

  records = flatten([local.service_records, local.node_records])

  record_names = distinct([for record in local.records : record.name])

  a_records_by_name    = { for name in local.record_names : name => distinct([for record in local.records : record.value if record.name == name && record.type == "A"]) }
  aaaa_records_by_name = { for name in local.record_names : name => distinct([for record in local.records : record.value if record.name == name && record.type == "AAAA"]) }
  srv_records_by_name  = { for name in local.record_names : name => distinct([for record in local.records : record.value if record.name == name && record.type == "SRV"]) }

  a_records    = { for key, value in local.a_records_by_name : key => value if length(value) > 0 }
  aaaa_records = { for key, value in local.aaaa_records_by_name : key => value if length(value) > 0 }
  srv_records  = { for key, value in local.srv_records_by_name : key => value if length(value) > 0 }
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
#     command = "echo '${jsonencode(local.values)}' | jq > test.json"
#   }
#
#   triggers = {
#     values = sha1(jsonencode(local.values))
#   }
# }
