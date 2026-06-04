## -- VPC -- ##
resource "aws_vpc" "vpc" {
  cidr_block = var.vpc_cidr

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-vpc"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
## -- Availability Zoness -- ##
data "aws_availability_zones" "zones" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.zones.names, 0, 3)
}
## -- Internet Gateway -- ##
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name        = "${var.project_name}-${var.environment}-igw"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
## -- NAT Gateway -- ##
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name        = "${var.project_name}-${var.environment}-nat-eip"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.allocation_id
  subnet_id     = aws_subnet.public[0].id

  depends_on = [aws_internet_gateway.igw]


  tags = {
    Name        = "${var.project_name}-${var.environment}-nat-eip"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_subnet" "public" {
  count = 3

  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-${var.environment}-public-${count.index + 1}"
    Tier = "public"

    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}
## -- Private App Subnets -- ##
resource "aws_subnet" "private_app" {
  count             = 3
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 6, count.index + 4)
  availability_zone = local.azs[count.index]

  tags = {
    Name = "${var.project_name}-${var.environment}-public-${count.index + 1}"
    Tier = "app"

    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }


}
## -- Private Data Subnets -- ##
resource "aws_subnet" "private_data" {
  count             = 3
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 100)
  availability_zone = local.azs[count.index]

  tags = {
    Name = "${var.project_name}-${var.environment}-public-${count.index + 1}"
    Tier = "data"
  }
}
## -- Private App Route Table -- ##
resource "aws_route_table" "private_app" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-private-app-rt"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
## -- Private Data Route Table -- ##
resource "aws_route_table" "private_data" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name        = "${var.project_name}-${var.environment}-private-data-rt"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
## -- Public Route Table -- ##
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-public-rt"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
## -- Route Table Associations -- ##
resource "aws_route_table_association" "public" {
  count = 3

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_app" {
  count = 3

  subnet_id      = aws_subnet.private_app[count.index].id
  route_table_id = aws_route_table.private_app.id

}

resource "aws_route_table_association" "private_data" {
  count = 3

  subnet_id      = aws_subnet.private_data[count.index].id
  route_table_id = aws_route_table.private_data.id
}
## -- VPC Endpoints -- ##

## -- S3 Gateway Endpoint (routes S3 traffic off NAT) -- ##
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.vpc.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"

  # Attach to all private route tables so pods + RDS/Redis reach S3 without NAT
  route_table_ids = concat(
    aws_route_table.private_app[*].id,
    [aws_route_table.private_data.id]
  )

  tags = {
    Name        = "${var.project_name}-${var.environment}-vpce-s3"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

## -- ECR API Endpoint (control plane: authentication, image metadata) -- ##
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.vpc.id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private_app[*].id
  security_group_ids  = [var.vpc_endpoint_sg_id]
  private_dns_enabled = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-vpce-ecr-api"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

## -- ECR DKR Endpoint (data plane: actual image layer pulls) -- ##
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.vpc.id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private_app[*].id
  security_group_ids  = [var.vpc_endpoint_sg_id]
  private_dns_enabled = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-vpce-ecr-dkr"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

## -- CloudWatch Logs Endpoint -- ##
resource "aws_vpc_endpoint" "cloudwatch_logs" {
  vpc_id              = aws_vpc.vpc.id
  service_name        = "com.amazonaws.${var.aws_region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private_app[*].id
  security_group_ids  = [var.vpc_endpoint_sg_id]
  private_dns_enabled = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-vpce-cwlogs"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
## -- STS Endpoint (pod IAM role assumption via IRSA) -- ##
resource "aws_vpc_endpoint" "sts" {
  vpc_id              = aws_vpc.vpc.id
  service_name        = "com.amazonaws.${var.aws_region}.sts"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private_app[*].id
  security_group_ids  = [var.vpc_endpoint_sg_id]
  private_dns_enabled = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-vpce-sts"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

## -- Secrets Manager Endpoint (External Secrets Operator) -- ##
resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = aws_vpc.vpc.id
  service_name        = "com.amazonaws.${var.aws_region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private_app[*].id
  security_group_ids  = [var.vpc_endpoint_sg_id]
  private_dns_enabled = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-vpce-secretsmanager"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}