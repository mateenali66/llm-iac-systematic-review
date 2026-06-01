resource "aws_s3_bucket" "company_prod_data" {
  bucket = "company-prod-data"
  tags = {
    Environment = "production"
    Purpose     = "application-logs-and-backups"
  }
}

resource "aws_s3_bucket_versioning" "company_prod_data" {
  bucket = aws_s3_bucket.company_prod_data.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "company_prod_data" {
  bucket = aws_s3_bucket.company_prod_data.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "company_prod_data" {
  bucket = aws_s3_bucket.company_prod_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "company_prod_data" {
  bucket = aws_s3_bucket.company_prod_data.id

  rule {
    id     = "log-retention"
    status = "Enabled"

    filter {
      prefix = "logs/"
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }

  rule {
    id     = "backup-retention"
    status = "Enabled"

    filter {
      prefix = "backups/"
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 180
      storage_class = "GLACIER"
    }

    expiration {
      days = 1095
    }
  }
}

resource "aws_s3_bucket_logging" "company_prod_data" {
  bucket = aws_s3_bucket.company_prod_data.id

  target_bucket = aws_s3_bucket.log_bucket.id
  target_prefix = "access-logs/"
}

resource "aws_s3_bucket" "log_bucket" {
  bucket = "company-prod-data-logs"
  tags = {
    Environment = "production"
    Purpose     = "s3-access-logs"
  }
}

resource "aws_s3_bucket_public_access_block" "log_bucket" {
  bucket = aws_s3_bucket.log_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "log_bucket" {
  bucket = aws_s3_bucket.log_bucket.id

  rule {
    id     = "log-retention"
    status = "Enabled"

    expiration {
      days = 90
    }
  }
}