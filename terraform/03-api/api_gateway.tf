############################################
# API Gateway HTTP API
############################################
resource "aws_apigatewayv2_api" "video_api" {
  name          = "${local.name_prefix}-video-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.video_api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "list_videos" {
  api_id             = aws_apigatewayv2_api.video_api.id
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
  integration_uri    = aws_lambda_function.list_videos.invoke_arn
}

resource "aws_apigatewayv2_route" "list_videos" {
  api_id    = aws_apigatewayv2_api.video_api.id
  route_key = "GET /api/videos"
  target    = "integrations/${aws_apigatewayv2_integration.list_videos.id}"
}

