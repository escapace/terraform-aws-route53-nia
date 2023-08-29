<!-- BEGIN_TF_DOCS -->

## Resources

| Name                                                                                                                  | Type     |
| --------------------------------------------------------------------------------------------------------------------- | -------- |
| [aws_route53_record.a](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record)    | resource |
| [aws_route53_record.aaaa](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.srv](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record)  | resource |

## Inputs

| Name               | Description                                                                                                     | Type                                                                                                                                                                                                                                                                                                                                                | Default    | Required |
| ------------------ | --------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------- | :------: |
| domain             | By default, Consul responds to DNS queries in the "consul" domain. This flag can be used to change that domain. | `string`                                                                                                                                                                                                                                                                                                                                            | `"consul"` |    no    |
| prefer_wan_address | If set to true, on node lookups will prefer a node's configured WAN address.                                    | `bool`                                                                                                                                                                                                                                                                                                                                              | `false`    |    no    |
| region             | AWS Region                                                                                                      | `string`                                                                                                                                                                                                                                                                                                                                            | n/a        |   yes    |
| services           | Consul services monitored by Consul-Terraform-Sync                                                              | `map( object({ id = string name = string kind = string address = string port = number meta = map(string) tags = list(string) namespace = string status = string node = string node_id = string node_address = string node_datacenter = string node_tagged_addresses = map(string) node_meta = map(string) cts_user_defined_meta = map(string) }) )` | n/a        |   yes    |
| ttl                | The TTL of the records.                                                                                         | `number`                                                                                                                                                                                                                                                                                                                                            | `1`        |    no    |
| zone_id            | The ID of the hosted zone.                                                                                      | `string`                                                                                                                                                                                                                                                                                                                                            | n/a        |   yes    |

<!-- END_TF_DOCS -->
