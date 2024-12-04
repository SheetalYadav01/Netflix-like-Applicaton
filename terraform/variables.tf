variable "region" {
  description = "AWS region"
  default     = "us-west-2"
}

variable "db_username" {
  description = "Database master username"
  type        = string
  default     = "Netflix_clone"
}

variable "db_password" {
  description = "The password for the RDS master user"
  type        = string
  default     = "SecurePass123!"
}

variable "db_name" {
  description = "Name of the database"
  type        = string
  default     = "streamingdb"
}

variable "bucket_name" {
  description = "The name of the S3 bucket for frontend"
  default     = "s3-bucket-frontend-streaming"
}

