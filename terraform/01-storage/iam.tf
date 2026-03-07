############################################
# IAM Role for MediaConvert
############################################

data "aws_iam_policy_document" "mediaconvert_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["mediaconvert.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "mediaconvert" {
  name               = "${local.name_prefix}-mediaconvert-role"
  assume_role_policy = data.aws_iam_policy_document.mediaconvert_assume_role.json
}

data "aws_iam_policy_document" "mediaconvert_s3_access" {
  statement {
    sid     = "ReadSource"
    effect  = "Allow"
    actions = ["s3:GetObject", "s3:ListBucket"]
    resources = [
      aws_s3_bucket.source.arn,
      "${aws_s3_bucket.source.arn}/*"
    ]
  }

  statement {
    sid     = "WriteOutput"
    effect  = "Allow"
    actions = ["s3:PutObject", "s3:GetBucketLocation"]
    resources = [
      aws_s3_bucket.output.arn,
      "${aws_s3_bucket.output.arn}/*"
    ]
  }
}

resource "aws_iam_policy" "mediaconvert_s3_access" {
  name        = "${local.name_prefix}-mediaconvert-s3-access"
  description = "Allows MediaConvert to read from the source bucket and write to the output bucket"
  policy      = data.aws_iam_policy_document.mediaconvert_s3_access.json
}

resource "aws_iam_role_policy_attachment" "mediaconvert_s3_access" {
  role       = aws_iam_role.mediaconvert.name
  policy_arn = aws_iam_policy.mediaconvert_s3_access.arn
}
