output "site_bucket" { value = aws_s3_bucket.site.bucket }
output "cloudfront_distribution_id" { value = aws_cloudfront_distribution.site.id }

output "deploy_role_arn" { value = aws_iam_role.deploy.arn }
output "tf_plan_role_arn" { value = aws_iam_role.tf_plan.arn }
output "tf_apply_role_arn" { value = aws_iam_role.tf_apply.arn }
