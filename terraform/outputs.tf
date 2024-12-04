output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "ec2_public_ip" {
  value = aws_instance.backend.public_ip
}

output "cloudfront_domain" {
  value = aws_cloudfront_distribution.frontend.domain_name
}

output "rds_endpoint" {
  value = aws_db_instance.streaming_database.endpoint
}

output "elasticache_endpoint" {
  value = aws_elasticache_cluster.redis_cache.cache_nodes[0].address
}

output "load_balancer_dns" {
  value = aws_lb.streaming_lb.dns_name
}

output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.streaming_user_pool.id
}
output "s3_bucket_name" {
  value = aws_s3_bucket.frontend.bucket
}