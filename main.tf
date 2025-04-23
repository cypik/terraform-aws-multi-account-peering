module "labels" {
  source      = "cypik/labels/aws"
  version     = "1.0.2"
  name        = var.name
  environment = var.environment
  attributes  = var.attributes
  repository  = var.repository
  managedby   = var.managedby
  label_order = var.label_order
}

provider "aws" {
  alias   = "accepter"
  region  = var.accepter_region
  profile = var.profile_name

  assume_role {
    role_arn = var.accepter_role_arn
  }
}

data "aws_caller_identity" "peer" {
  provider = aws.accepter
}

data "aws_region" "peer" {
  provider = aws.accepter
}

resource "aws_vpc_peering_connection" "default" {
  count         = var.enable_peering == true ? 1 : 0
  peer_owner_id = data.aws_caller_identity.peer.account_id
  peer_region   = data.aws_region.peer.id
  vpc_id        = var.requestor_vpc_id
  peer_vpc_id   = var.acceptor_vpc_id
  auto_accept   = false
  tags = merge(
    module.labels.tags,
    {
      "Name" = format("%s-%s", module.labels.name, module.labels.environment)
    }
  )
}

resource "aws_vpc_peering_connection_accepter" "peer" {
  count                     = var.enable_peering == true ? 1 : 0
  provider                  = aws.accepter
  vpc_peering_connection_id = aws_vpc_peering_connection.default[0].id
  auto_accept               = true
  tags                      = module.labels.tags
}

data "aws_vpc" "requestor" {
  count = var.enable_peering == true ? 1 : 0
  id    = var.requestor_vpc_id
}

data "aws_route_table" "requestor" {
  count = var.enable_peering == true ? length(distinct(sort(data.aws_subnets.requestor[0].ids))) : 0

  subnet_id = element(
    distinct(sort(data.aws_subnets.requestor[0].ids)),
    count.index
  )
}

data "aws_subnets" "requestor" {
  count = var.enable_peering == true ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.requestor[0].id]
  }
}

data "aws_vpc" "acceptor" {
  provider = aws.accepter
  count    = var.enable_peering == true ? 1 : 0
  id       = var.acceptor_vpc_id
}

data "aws_subnets" "acceptor" {
  provider = aws.accepter
  count    = var.enable_peering == true ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.acceptor[0].id]
  }
}

data "aws_route_tables" "acceptor" {
  provider = aws.accepter
  count    = var.enable_peering == true ? length(distinct(sort(data.aws_subnets.acceptor[0].ids))) : 0

  vpc_id = data.aws_vpc.acceptor[0].id
}
resource "aws_route" "requestor" {

  count = var.enable_peering == true ? length(
    distinct(sort([for rt in data.aws_route_table.requestor : rt.route_table_id]))
  ) * length(data.aws_vpc.acceptor[0].cidr_block_associations) : 0

  route_table_id = element(
    distinct(sort([for rt in data.aws_route_table.requestor : rt.route_table_id])),
    ceil(
      count.index / length(data.aws_vpc.acceptor[0].cidr_block_associations)
    )
  )

  destination_cidr_block = data.aws_vpc.acceptor[0].cidr_block_associations[
    count.index % length(data.aws_vpc.acceptor[0].cidr_block_associations)
  ]["cidr_block"]

  vpc_peering_connection_id = aws_vpc_peering_connection.default[0].id

  depends_on = [
    data.aws_route_table.requestor,
    aws_vpc_peering_connection.default,
  ]
}


resource "aws_route" "acceptor" {
  provider = aws.accepter

  count = var.enable_peering == true ? length(
    distinct(sort(data.aws_route_tables.acceptor[0].ids))
  ) * length(data.aws_vpc.requestor[0].cidr_block_associations) : 0

  route_table_id = element(
    distinct(sort(data.aws_route_tables.acceptor[0].ids)),
    ceil(
      count.index / length(data.aws_vpc.requestor[0].cidr_block_associations)
    )
  )

  destination_cidr_block = data.aws_vpc.requestor[0].cidr_block_associations[
    count.index % length(data.aws_vpc.requestor[0].cidr_block_associations)
  ]["cidr_block"]

  vpc_peering_connection_id = aws_vpc_peering_connection.default[0].id

  depends_on = [
    data.aws_route_tables.acceptor,
    aws_vpc_peering_connection.default,
  ]
}
