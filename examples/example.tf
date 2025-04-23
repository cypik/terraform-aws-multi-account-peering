provider "aws" {
  region = "us-west-1"
}

module "vpc-peering" {
  source            = "../"
  name              = "vpc-peering"
  enable_peering    = true
  accepter_role_arn = "arn:aws:iam::xxxxxxxxx:role/switch-role"
  accepter_region   = "us-east-1"
  acceptor_vpc_id   = "vpc-xxxxxxxxxxxxxxx"
  profile_name      = "test"
  requestor_vpc_id  = "vpc-xxxxxxxxxxxxxxx"
}