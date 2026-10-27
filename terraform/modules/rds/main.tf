resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-db-subnets"
  subnet_ids = var.db_subnet_ids
  tags       = { Name = "${var.name}-db-subnets" }
}

resource "aws_db_instance" "this" {
  identifier = "${var.name}-db"

  engine         = "postgres"
  engine_version = "16"
  instance_class = var.instance_class

  allocated_storage = var.allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  port     = 5432

  # RDS generates the password and keeps it in Secrets Manager
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.db_sg_id]
  publicly_accessible    = false
  multi_az               = var.multi_az

  backup_retention_period    = 1
  auto_minor_version_upgrade = true
  apply_immediately          = true

  # Dev settings: make destroy quick and clean. Production would flip these.
  skip_final_snapshot = true
  deletion_protection = false

  tags = { Name = "${var.name}-db" }
}