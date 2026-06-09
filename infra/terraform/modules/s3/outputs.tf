output "ingest_bucket_name" {
  value = aws_s3_bucket.ingest.bucket
}

output "delivery_bucket_name" {
  value = aws_s3_bucket.delivery.bucket
}

output "assets_bucket_name" {
  value = aws_s3_bucket.assets.bucket
}