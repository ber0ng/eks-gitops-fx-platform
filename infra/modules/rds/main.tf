resource "aws_security_group" "sg_rds" {
  name        = "${var.name}-rds"
  description = "Postgres access for ${var.name}"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name}-rds"
  }
}

# Only sg (EKS nodes) can reach postgre
resource "aws_vpc_security_group_ingress_rule" "sg_postgre" {
  for_each = toset(var.allowed_security_group_ids)

  security_group_id            = aws_security_group.sg_rds.id
  referenced_security_group_id = each.value
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  description                  = "Postgres from ${each.value}"
}

resource "aws_db_instance" "db_instance" {
  identifier     = var.name
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.username

  # RDS generates its pw, stores it in Secrets manager and rotates it. Never appears in TF code or state
  manage_master_user_password = true

  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = [aws_security_group.sg_rds.id]
  publicly_accessible    = false
  multi_az               = var.multi_az

  backup_retention_period    = var.backup_retention_days
  auto_minor_version_upgrade = true

  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.name}-final"

  tags = {
    Name = var.name
  }
}
