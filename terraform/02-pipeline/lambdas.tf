############################################
# Common Lambda Assume Role Policy
############################################
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

############################################
# Trigger Lambda
############################################
data "archive_file" "trigger_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../../lambdas/trigger"
  output_path = "${path.module}/.terraform/archives/trigger.zip"
}

resource "aws_iam_role" "trigger_lambda" {
  name               = "${local.name_prefix}-trigger-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "trigger_lambda_basic_execution" {
  role       = aws_iam_role.trigger_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "trigger_lambda_policy" {
  statement {
    effect = "Allow"
    actions = [
      "mediaconvert:CreateJob",
      "mediaconvert:GetJob",
      "mediaconvert:DescribeEndpoints"
    ]
    resources = ["*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = [local.mediaconvert_role_arn]
  }

  statement {
    effect    = "Allow"
    actions   = ["dynamodb:PutItem"]
    resources = [aws_dynamodb_table.catalog.arn]
  }
}

resource "aws_iam_policy" "trigger_lambda_policy" {
  name   = "${local.name_prefix}-trigger-lambda-policy"
  policy = data.aws_iam_policy_document.trigger_lambda_policy.json
}

resource "aws_iam_role_policy_attachment" "trigger_lambda" {
  role       = aws_iam_role.trigger_lambda.name
  policy_arn = aws_iam_policy.trigger_lambda_policy.arn
}

resource "aws_lambda_function" "trigger" {
  filename         = data.archive_file.trigger_lambda.output_path
  function_name    = "${local.name_prefix}-trigger"
  role             = aws_iam_role.trigger_lambda.arn
  handler          = "main.handler"
  runtime          = "python3.12"
  source_code_hash = data.archive_file.trigger_lambda.output_base64sha256
  timeout          = 30

  environment {
    variables = {
      CATALOG_TABLE     = aws_dynamodb_table.catalog.name
      OUTPUT_BUCKET     = local.output_media_bucket_id
      MEDIACONVERT_ROLE = local.mediaconvert_role_arn
    }
  }
}

############################################
# Job Completion Lambda
############################################
data "archive_file" "job_completion_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../../lambdas/job-completion"
  output_path = "${path.module}/.terraform/archives/job-completion.zip"
}

resource "aws_iam_role" "job_completion_lambda" {
  name               = "${local.name_prefix}-job-completion-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "job_completion_basic_execution" {
  role       = aws_iam_role.job_completion_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "job_completion_policy" {
  statement {
    effect    = "Allow"
    actions   = ["dynamodb:UpdateItem", "dynamodb:GetItem"]
    resources = [aws_dynamodb_table.catalog.arn]
  }
}

resource "aws_iam_policy" "job_completion_policy" {
  name   = "${local.name_prefix}-job-completion-policy"
  policy = data.aws_iam_policy_document.job_completion_policy.json
}

resource "aws_iam_role_policy_attachment" "job_completion_lambda" {
  role       = aws_iam_role.job_completion_lambda.name
  policy_arn = aws_iam_policy.job_completion_policy.arn
}

resource "aws_lambda_function" "job_completion" {
  filename         = data.archive_file.job_completion_lambda.output_path
  function_name    = "${local.name_prefix}-job-completion"
  role             = aws_iam_role.job_completion_lambda.arn
  handler          = "main.handler"
  runtime          = "python3.12"
  source_code_hash = data.archive_file.job_completion_lambda.output_base64sha256
  timeout          = 30

  environment {
    variables = {
      CATALOG_TABLE = aws_dynamodb_table.catalog.name
    }
  }
}
