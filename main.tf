terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

variable "OPENAI_API_KEY" {
  sensitive = true
  type      = string
}

resource "aws_secretsmanager_secret" "my_app_secrets" {
  name = "my-app-secrets"
}

resource "aws_secretsmanager_secret_version" "my_app_secrets" {
  secret_id     = aws_secretsmanager_secret.my_app_secrets.id
  secret_string = var.OPENAI_API_KEY
}

data "aws_iam_policy_document" "lambda_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "lambda_secrets_policy" {
  statement {
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue*"]
    resources = [aws_secretsmanager_secret.my_app_secrets.arn]
  }
}

resource "aws_iam_policy" "lambda_secrets_policy" {
  name   = "lambda-secrets-policy"
  policy = data.aws_iam_policy_document.lambda_secrets_policy.json
}

resource "aws_iam_role" "lambda_role" {
  name               = "explain-code-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_policy.json
}

resource "aws_iam_role_policy_attachment" "secrets" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_secrets_policy.arn
}

data "archive_file" "explain_code" {
  type        = "zip"
  source_file = "lambda_function.py"
  output_path = "lambda_function.zip"
}

resource "aws_lambda_function" "explain_code" {
  function_name    = "explain-code"
  filename         = data.archive_file.explain_code.output_path
  source_code_hash = data.archive_file.explain_code.output_base64sha256
  role             = aws_iam_role.lambda_role.arn
  runtime          = "python3.12"
  handler          = "lambda_function.lambda_handler"
  timeout          = 10

  environment {
    variables = {
      MY_APP_SECRETS_NAME = aws_secretsmanager_secret.my_app_secrets.name
    }
  }
}

resource "aws_lambda_function_url" "explain_code" {
  function_name      = aws_lambda_function.explain_code.function_name
  authorization_type = "NONE"
}

output "url" {
  value = aws_lambda_function_url.explain_code.function_url
}
