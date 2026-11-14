# --- SES ---
resource "aws_sesv2_email_identity" "domain" {
  email_identity = var.domain_name
}

resource "aws_route53_record" "ses_dkim" {
  count   = 3
  zone_id = data.aws_route53_zone.this.zone_id
  name    = "${aws_sesv2_email_identity.domain.dkim_signing_attributes[0].tokens[count.index]}._domainkey.${var.domain_name}"
  type    = "CNAME"
  ttl     = 1800
  records = ["${aws_sesv2_email_identity.domain.dkim_signing_attributes[0].tokens[count.index]}.dkim.amazonses.com"]
}

resource "aws_route53_record" "dmarc" {
  count   = var.create_dmarc_record ? 1 : 0
  zone_id = data.aws_route53_zone.this.zone_id
  name    = "_dmarc.${var.domain_name}"
  type    = "TXT"
  ttl     = 3600
  records = ["v=DMARC1; p=none"]
}

resource "aws_sesv2_email_identity" "recipient" {
  email_identity = var.contact_recipient_email # AWS emails you a link to click
}

# --- Lambda ---
data "archive_file" "contact" {
  type        = "zip"
  source_file = "${path.module}/lambda/contact.py"
  output_path = "${path.module}/.build/contact.zip"
}

resource "aws_cloudwatch_log_group" "contact_lambda" {
  name              = "/aws/lambda/${var.project_name}-contact"
  retention_in_days = 30
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "contact_lambda" {
  name               = "${var.project_name}-contact-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

data "aws_iam_policy_document" "contact_lambda" {
  statement {
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.contact_lambda.arn}:*"]
  }
  statement {
    actions   = ["ses:SendEmail"]
    resources = [aws_sesv2_email_identity.domain.arn, aws_sesv2_email_identity.recipient.arn]
    condition {
      test     = "StringEquals"
      variable = "ses:FromAddress"
      values   = ["noreply@${var.domain_name}"]
    }
  }
}

resource "aws_iam_role_policy" "contact_lambda" {
  name   = "contact-lambda"
  role   = aws_iam_role.contact_lambda.id
  policy = data.aws_iam_policy_document.contact_lambda.json
}

resource "aws_lambda_function" "contact" {
  function_name    = "${var.project_name}-contact"
  role             = aws_iam_role.contact_lambda.arn
  runtime          = "python3.13"
  handler          = "contact.handler"
  filename         = data.archive_file.contact.output_path
  source_code_hash = data.archive_file.contact.output_base64sha256
  architectures    = ["arm64"] # cheaper than x86
  memory_size      = 128
  timeout          = 10

  environment {
    variables = {
      SENDER_ADDRESS    = "noreply@${var.domain_name}"
      RECIPIENT_ADDRESS = var.contact_recipient_email
      SITE_NAME         = var.domain_name
    }
  }
  depends_on = [aws_cloudwatch_log_group.contact_lambda, aws_iam_role_policy.contact_lambda]
}

# --- API Gateway (HTTP API) ---
resource "aws_apigatewayv2_api" "contact" {
  name          = "${var.project_name}-contact"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "contact" {
  api_id                 = aws_apigatewayv2_api.contact.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.contact.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "contact" {
  api_id    = aws_apigatewayv2_api.contact.id
  route_key = "POST /api/contact"
  target    = "integrations/${aws_apigatewayv2_integration.contact.id}"
}

resource "aws_cloudwatch_log_group" "contact_api" {
  name              = "/aws/apigateway/${var.project_name}-contact"
  retention_in_days = 30
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.contact.id
  name        = "$default"
  auto_deploy = true
  default_route_settings {
    throttling_burst_limit = 5
    throttling_rate_limit  = 2
  }
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.contact_api.arn
    format = jsonencode({
      requestId = "$context.requestId", ip = "$context.identity.sourceIp"
      route = "$context.routeKey", status = "$context.status"
    })
  }
}

resource "aws_lambda_permission" "api" {
  statement_id  = "AllowApiGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.contact.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.contact.execution_arn}/*/*/api/contact"
}
