provider "aws" {
  region = "eu-central-1" # Frankfurt
}

resource "aws_s3_bucket" "terraform_state" {
    bucket = "terraform-statefiles-bucket"

    # Unabsichtliches Löschen dieses S3 Bucket verhindern.
    lifecycle {
        prevent_destroy = true
    }
}

# Versionieren aktivieren, um die Hisrorie der State-Dateien zu speichern.
resource "aws_s3_bucket_versioning" "enabled" {
    bucket = aws_s3_bucket.terraform_state.id
    versioning_configuration {
        status = "Enabled"
    }
}

# Serverseitige Verschlüsselung aktivieren
resource "aws_s3_bucket_server_side_encryption_configuration" "default" {
    bucket = aws_s3_bucket.terraform_state.id
    rule {
        apply_server_side_encryption_by_default {
            sse_algorithm = "AES256"
        }
    }
}

# Jeglichen öffentlichen Zugriff auf den S3 Bucket verhindern
resource "aws_s3_bucket_public_access_block" "public_access" {
    bucket = aws_s3_bucket.terraform_state.id
    block_public_acls = true
    block_public_policy = true
    ignore_public_acls = true
    restrict_public_buckets = true
}

resource "aws_dynamodb_table" "terraform_state_lock" {
    name = "terraform-state-lock"
    billing_mode = "PAY_PER_REQUEST"
    hash_key = "LockID"
    attribute {
        name = "LockID"
        type = "S"
    }
}

terraform {
    backend "s3" {
        bucket = "terraform-statefiles-bucket"
        key = "global/s3/terraform.tfstate"
        region = "eu-central-1"
        dynamodb_table = aws_dynamodb_table.terraform_state_lock.name
        encrypt = true
    }
}

output "s3_bucket_arn" {
    value = aws_s3_bucket.terraform_state.arn
    description = "Der ARN des S3 Buckets"
}

output "dynamodb_table_name" {
    value = aws_dynamodb_table.terraform_state_lock.name
    description = "Der Name der DynamoDB Tabelle"
}