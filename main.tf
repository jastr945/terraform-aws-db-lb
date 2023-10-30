provider "aws" {
  region = "us-east-2"
}

data "aws_availability_zones" "available" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.2"

  name                 = "demo"
  cidr                 = "10.0.0.0/16"
  azs                  = data.aws_availability_zones.available.names
  public_subnets       = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_db_subnet_group" "demo" {
  name       = "demo"
  subnet_ids = module.vpc.public_subnets

  tags = {
    Name = "demo"
  }
}

resource "aws_security_group" "rds" {
  name   = "demo_rds"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["192.80.0.0/16"]
  }

  egress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "demo_rds"
  }
}

resource "aws_db_parameter_group" "demo" {
  name   = "demo"
  family = "postgres14"

  parameter {
    name  = "log_connections"
    value = "1"
  }
}

provider "random" {}

resource "random_pet" "random" {
  length = 1
}

resource "aws_db_instance" "demo" {
  identifier             = "${var.db_name}-${random_pet.random.id}"
  instance_class         = "db.t3.micro"
  allocated_storage      = 5
  engine                 = "postgres"
  engine_version         = "14.1"
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.demo.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.demo.name
  publicly_accessible    = true
  skip_final_snapshot    = true
}

// Optional Load Balancer
resource "aws_lb" "aws_lb" {
  count              = var.deploy_lb == true ? 1 : 0
  name               = "${var.db_name}-aws-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.rds.id]
  subnets            = module.vpc.public_subnets

  enable_deletion_protection = false

  tags = {
    Environment = "Dev",
    Name = "demo_rds"
  }
}