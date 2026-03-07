############################################
# List Videos Lambda
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

data "archive_file" "list_videos_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../../lambdas/list-videos"
  output_path = "${path.module}/.terraform/archives/list-videos.zip"
}

resource "aws_iam_role" "list_videos_lambda" {
  name               = "${local.name_prefix}-list-videos-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "list_videos_basic_execution" {
  role       = aws_iam_role.list_videos_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "list_videos_policy" {
  statement {
    effect  = "Allow"
    actions = ["dynamodb:Query", "dynamodb:Scan", "dynamodb:GetItem"]
    resources = [
      local.catalog_table_arn,
      "${local.catalog_table_arn}/index/StatusCreatedAtIndex"
    ]
  }
}

resource "aws_iam_policy" "list_videos_policy" {
  name   = "${local.name_prefix}-list-videos-policy"
  policy = data.aws_iam_policy_document.list_videos_policy.json
}

resource "aws_iam_role_policy_attachment" "list_videos_lambda" {
  role       = aws_iam_role.list_videos_lambda.name
  policy_arn = aws_iam_policy.list_videos_policy.arn
}

resource "aws_lambda_function" "list_videos" {
  filename         = data.archive_file.list_videos_lambda.output_path
  function_name    = "${local.name_prefix}-list-videos"
  role             = aws_iam_role.list_videos_lambda.arn
  handler          = "main.handler"
  runtime          = "python3.12"
  source_code_hash = data.archive_file.list_videos_lambda.output_base64sha256
  timeout          = 15

  environment {
    variables = {
      CATALOG_TABLE = local.catalog_table_name
    }
  }
}

resource "aws_lambda_permission" "allow_apigateway_to_call_list_videos" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.list_videos.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.video_api.execution_arn}/*/*"
}
