############################################
# S3 Event Notification for Source Bucket
############################################
resource "aws_lambda_permission" "allow_s3_to_call_trigger" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.trigger.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = local.source_media_bucket_arn
}

resource "aws_s3_bucket_notification" "source_media" {
  bucket = local.source_media_bucket_id

  lambda_function {
    lambda_function_arn = aws_lambda_function.trigger.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_s3_to_call_trigger]
}

############################################
# EventBridge Rules for MediaConvert
############################################
resource "aws_cloudwatch_event_rule" "mediaconvert_job_state" {
  name        = "${local.name_prefix}-mediaconvert-state"
  description = "Capture MediaConvert Job State Changes"

  event_pattern = jsonencode({
    source      = ["aws.mediaconvert"]
    detail-type = ["MediaConvert Job State Change"]
    detail = {
      status = ["COMPLETE", "ERROR", "CANCELED"]
    }
  })
}

resource "aws_cloudwatch_event_target" "invoke_job_completion_lambda" {
  rule      = aws_cloudwatch_event_rule.mediaconvert_job_state.name
  target_id = "JobCompletionLambda"
  arn       = aws_lambda_function.job_completion.arn
}

resource "aws_lambda_permission" "allow_eventbridge_to_call_job_completion" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.job_completion.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.mediaconvert_job_state.arn
}
