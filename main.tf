variable "database_user" {
  type    = string
  default = "user"
}

variable "database_name" {
  type    = string
  default = "demo"
}

variable "database_password" {
  type    = string
  default = "password"
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
}

module "db" {
  source     = "terraform-aws-modules/rds/aws"
  identifier = "k8sdb"

  engine               = "mysql"
  engine_version       = "8.4.5"
  major_engine_version = "8.4"
  instance_class       = "db.t3a.large"
  family               = "mysql8.4"

  db_name                     = var.database_name
  username                    = var.database_user
  password                    = var.database_password
  manage_master_user_password = false
  allocated_storage           = 5

  vpc_security_group_ids = [module.vpc.default_security_group_id]
}

module "lambda_function" {
  source = "terraform-aws-modules/lambda/aws"

  function_name = "myfunction"
  handler       = "index.handler"
  runtime       = "python3.12"

  environment_variables = {
    "DATABASE_URL"      = module.db.db_instance_address,
    "DATABASE_PORT"     = module.db.db_instance_port,
    "DATABASE_NAME"     = var.database_name
    "DATABASE_USER"     = var.database_user
    "DATABASE_PASSWORD" = var.database_password
  }

  build_in_docker = true
  # Only include if on a silicon mac
  docker_additional_options = [
    "--platform", "linux/arm64",
  ]


  architectures = ["arm64"]
  source_path   = "./lambda-src"
}
