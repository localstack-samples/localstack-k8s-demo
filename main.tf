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

# arm64 matches Apple silicon. Use x86_64 on x86 machines (e.g. TF_VAR_lambda_architecture=x86_64),
# so the dependencies are built for the architecture the Lambda pod runs on.
variable "lambda_architecture" {
  type    = string
  default = "arm64"

  validation {
    condition     = contains(["arm64", "x86_64"], var.lambda_architecture)
    error_message = "lambda_architecture must be arm64 or x86_64."
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.7.3"

  manage_default_network_acl    = false
  manage_default_route_table    = false
  manage_default_security_group = false
}

module "db" {
  source     = "terraform-aws-modules/rds/aws"
  version    = "6.13.1"
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
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.12.0"

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
  docker_additional_options = [
    "--platform", var.lambda_architecture == "arm64" ? "linux/arm64" : "linux/amd64",
  ]

  architectures = [var.lambda_architecture]
  source_path   = "./lambda-src"
}
