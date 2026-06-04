output "vpc_id" {
  description = "streaming platform VPC id"

  value = aws_vpc.vpc.id
}

output "public_subnet_cidrs" {
  description = "Public subnet IDs"

  value = aws_subnet.public[*].id
}

output "app_subnet_cidrs" {
  description = "private application subnet ids"

  value = aws_subnet.private_app[*].id
}

output "data_subnet_cidrs" {
  description = "private data subnet IDs"

  value = aws_subnet.private_data[*].id
}

output "availability_zones" {
  description = "AWS availability zones used"

  value = local.azs
}