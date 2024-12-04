provider "aws" {
  region = "us-west-2"  # Replace with your AWS region
}

# ---------------------------
# Data Resources
# ---------------------------

# Get available availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Get AWS account ID
data "aws_caller_identity" "current" {}

# ---------------------------
# VPC and Networking Setup
# ---------------------------

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "Netflix-VPC"
  }
}

resource "aws_subnet" "public" {
  count                  = 2
  vpc_id                 = aws_vpc.main.id
  cidr_block             = "10.0.${count.index}.0/24"
  map_public_ip_on_launch = true
  availability_zone      = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "Public Subnet ${count.index + 1}"
  }
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 2}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "Private Subnet ${count.index + 1}"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "Internet Gateway"
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.main.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "NAT Gateway"
  }
}

resource "aws_eip" "main" {
  tags = {
    Name = "Elastic IP for NAT Gateway"
  }
}

# Route Table for Public Subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "Public Route Table"
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ---------------------------
# Security Groups
# ---------------------------

resource "aws_security_group" "backend_sg" {
  name        = "backend-security-group"
  description = "Security group for backend EC2 instance"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Backend Security Group"
  }
}

# ---------------------------
# IAM Role Setup (for EC2)
# ---------------------------

resource "aws_iam_role" "ec2_role" {
  name               = "EC2Role-netflix-clone"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
      }
    ]
  })
}

# IAM Policy for EC2 Role
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.ec2_role.name
}

# ---------------------------
# Create IAM Instance Profile
# ---------------------------

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "EC2InstanceProfile-netflix-clone"
  role = aws_iam_role.ec2_role.name
}

# ---------------------------
# EC2 Instance Setup
# ---------------------------

resource "aws_instance" "backend" {
  ami                    = "ami-055e3d4f0bbeb5878"  # Amazon Linux 2 AMI in us-west-2
  instance_type          = "t3.micro"
  iam_instance_profile   = aws_iam_instance_profile.ec2_instance_profile.name
  
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.backend_sg.id]

  # Removed key_name to resolve the error
  # If you need SSH access, create a key pair in AWS Console first

  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install -y docker
              sudo service docker start
              sudo usermod -a -G docker ec2-user
              sudo systemctl enable docker
              EOF

  tags = {
    Name = "Backend EC2 Instance"
  }

  # Optional: Add root volume configuration
  root_block_device {
    volume_type = "gp3"
    volume_size = 30
    encrypted   = true
  }
}


# ---------------------------
# Elastic Cache Setup
# ---------------------------
resource "aws_elasticache_subnet_group" "redis_subnet_group" {
  name       = "streaming-redis-subnet-group"
  subnet_ids = aws_subnet.private[*].id
}

resource "aws_security_group" "redis_sg" {
  name        = "redis-security-group"
  description = "Security group for Redis ElastiCache"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.backend_sg.id]
  }
}

# ---------------------------
# Auto Scaling Setup
# ---------------------------

resource "aws_launch_template" "backend_template" {
  name_prefix   = "backend-launch-template"
  image_id      = "ami-055e3d4f0bbeb5878"
  instance_type = "t3.micro"

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.backend_sg.id]
  }

  user_data = base64encode(<<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install -y docker
              sudo service docker start
              sudo usermod -a -G docker ec2-user
              sudo systemctl enable docker
              EOF
  )
}

resource "aws_autoscaling_group" "backend_asg" {
  desired_capacity    = 2
  max_size            = 4
  min_size            = 1
  vpc_zone_identifier = aws_subnet.private[*].id
  target_group_arns   = [aws_lb_target_group.backend_tg.arn]

  launch_template {
    id      = aws_launch_template.backend_template.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "Backend ASG Instance"
    propagate_at_launch = true
  }
}

# ---------------------------
# LoadBalancer Setup
# ---------------------------

resource "aws_lb" "streaming_lb" {
  name               = "streaming-load-balancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = aws_subnet.public[*].id
}

resource "aws_security_group" "lb_sg" {
  name        = "load-balancer-sg"
  description = "Security group for load balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb_target_group" "backend_tg" {
  name     = "backend-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    path                = "/"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
  }
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.streaming_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_tg.arn
  }
}

# ---------------------------
# Frontend: S3 and CloudFront
# ---------------------------

resource "aws_s3_bucket" "frontend" {
  bucket = "netflix-clone-frontend-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "Frontend S3 Bucket"
  }
}

resource "aws_s3_bucket_versioning" "frontend_versioning" {
  bucket = aws_s3_bucket.frontend.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "frontend_lifecycle" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    id     = "MoveToGlacier"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }
}

resource "aws_s3_bucket_public_access_block" "frontend_public_access_block" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_cloudfront_origin_access_identity" "frontend_oai" {
  comment = "OAI for CloudFront accessing S3"
}

resource "aws_s3_bucket_policy" "frontend_policy" {
  bucket = aws_s3_bucket.frontend.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowCloudFrontAccess",
        Effect    = "Allow",
        Principal = {
          Service = "cloudfront.amazonaws.com"
        },
        Action    = "s3:GetObject",
        Resource  = "${aws_s3_bucket.frontend.arn}/*",
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.frontend.arn
          }
        }
      }
    ]
  })
}

resource "aws_cloudfront_distribution" "frontend" {
  origin {
    domain_name = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id   = "S3-Frontend-Origin"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.frontend_oai.cloudfront_access_identity_path
    }
  }

  default_cache_behavior {
    target_origin_id       = "S3-Frontend-Origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  enabled             = true
  is_ipv6_enabled     = true

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name = "Frontend CloudFront Distribution"
  }
}

# ---------------------------
# CloudWatch for Monitoring
# ---------------------------

# resource "aws_cloudwatch_log_group" "backend_logs" {
#   name = "/aws/ec2/backend-instance-logs"
#   retention_in_days = 30
# }

# ---------------------------
# IAM Configuration (for Lambda Execution)
# ---------------------------

resource "aws_iam_role" "lambda_role" {
  name               = "LambdaExecutionRole-netflix-clone"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_policy" {
  name        = "LambdaPolicy-netflix-clone"
  description = "Policy granting Lambda permissions"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = [
          "s3:GetObject",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          "${aws_s3_bucket.frontend.arn}/*",
          "arn:aws:logs:*:*:*"
        ]
        Effect   = "Allow"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_attachment" {
  policy_arn = aws_iam_policy.lambda_policy.arn
  role       = aws_iam_role.lambda_role.name
}

resource "aws_cognito_user_pool" "streaming_user_pool" {
  name = "streaming-user-pool"

 # ---------------------------
# MFA Configuration Setup
# ---------------------------
 
  mfa_configuration = "ON"
  software_token_mfa_configuration {
    enabled = true
  }

  # Password Policy#
  password_policy {
    minimum_length    = 12
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }
}

resource "aws_cognito_user_pool_client" "web_client" {
  name         = "streaming-web-client"
  user_pool_id = aws_cognito_user_pool.streaming_user_pool.id
}

# ---------------------------
# API Gateway Setup
# ---------------------------

resource "aws_api_gateway_rest_api" "streaming_api" {
  name        = "streaming-api"
  description = "API Gateway for Streaming Service"
}

resource "aws_api_gateway_resource" "movies" {
  rest_api_id = aws_api_gateway_rest_api.streaming_api.id
  parent_id   = aws_api_gateway_rest_api.streaming_api.root_resource_id
  path_part   = "movies"
}

resource "aws_db_subnet_group" "streaming_db_subnet" {
  name       = "streaming-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "Streaming DB Subnet Group"
  }
}

# ---------------------------
# Database Setup
# ---------------------------

resource "aws_security_group" "rds_sg" {
  name        = "rds-security-group"
  description = "Security group for RDS PostgreSQL instance"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.backend_sg.id]
  }
}

resource "aws_db_instance" "streaming_database" {
  identifier        = "streaming-database"
  engine            = "postgres"
  engine_version    = "13.13"  # Ensure this is a valid version
  instance_class    = "db.t3.micro"
  allocated_storage = 20

  db_subnet_group_name   = aws_db_subnet_group.streaming_db_subnet.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password  # Ensure this is a valid and secure password

  backup_retention_period = 7
  multi_az                = true
  storage_encrypted       = true
}


# ---------------------------
# ElastiCache Setup
# ---------------------------

resource "aws_elasticache_parameter_group" "redis_pg" {
  name   = "redis7-parameter-group"
  family = "redis7"
}

resource "aws_elasticache_subnet_group" "redis_subnet" {
  name       = "redis-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "Redis Subnet Group"
  }
}

resource "aws_elasticache_cluster" "redis_cache" {
  cluster_id           = "streaming-redis-cluster"
  engine               = "redis"
  node_type            = "cache.t2.micro"
  num_cache_nodes      = 1
  parameter_group_name = aws_elasticache_parameter_group.redis_pg.name
  subnet_group_name    = aws_elasticache_subnet_group.redis_subnet.name
  security_group_ids   = [aws_security_group.elasticache_sg.id]
}

resource "aws_security_group" "elasticache_sg" {
  name        = "elasticache-security-group"
  description = "Security group for ElastiCache"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # Allow all egress
    cidr_blocks = ["0.0.0.0/0"]
  }
}
