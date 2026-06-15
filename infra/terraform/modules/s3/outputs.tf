output "ingest_bucket_name" {
  value = aws_s3_bucket.ingest.bucket
}

output "delivery_bucket_name" {
  value = aws_s3_bucket.delivery.bucket
}

output "assets_bucket_name" {
  value = aws_s3_bucket.assets.bucket
}

output "ingest_bucket_arn" {
  value = aws_s3_bucket.ingest.arn
}

output "delivery_bucket_arn" {
  value = aws_s3_bucket.delivery.arn
}

output "assets_bucket_arn" {
  value = aws_s3_bucket.assets.arn
}