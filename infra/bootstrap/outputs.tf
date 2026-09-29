output "state_bucket_name" {
  value = aws_s3_bucket.terraform_state_bucket.bucket
}

output "plan_role_arn" {
  value = aws_iam_role.plan_role.arn
}

output "apply_role_arn" {
  value = aws_iam_role.apply.arn
}
