output "connection_id" {
  value       = join("", [for conn in aws_vpc_peering_connection.default : conn.id])
  description = "VPC peering connection ID."
}

output "accept_status" {
  value       = join("", [for conn in aws_vpc_peering_connection.default : conn.accept_status])
  description = "The status of the VPC peering connection request."
}

output "tags" {
  value       = module.labels.tags
  description = "A mapping of tags to assign to the resource."
}