resource "aws_s3_bucket" "glue_scripts" {
  bucket = "lal-glue-scripts-2026-12345"
}

resource "aws_s3_object" "glue_script" {

  bucket = aws_s3_bucket.glue_scripts.bucket

  key    = "scripts/firstgluejob.py"

  source = "./firstgluejob.py"

  etag = filemd5("./firstgluejob.py")
}

resource "aws_iam_role" "glue_role" {

  name = "lal-glue-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Service = "glue.amazonaws.com"
      }

      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "glue_service_role" {

  role = aws_iam_role.glue_role.name

  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy_attachment" "s3_access" {

  role = aws_iam_role.glue_role.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_policy" "custom_policy" {

  name = "lal-custom-policy-glue"

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject"
            ],
            "Resource": [
                "arn:aws:s3:::lal-sales-raw-2026/daily/*"
            ],
            "Condition": {
                "StringEquals": {
                    "aws:ResourceAccount": "802320708127"
                }
            }
        }
    ]
})
}

resource "aws_iam_role_policy_attachment" "custom_attach" {

  role = aws_iam_role.glue_role.name

  policy_arn = aws_iam_policy.custom_policy.arn
}

resource "aws_glue_job" "first_job" {

  name     = "second-glue-job"

  role_arn = aws_iam_role.glue_role.arn
  glue_version = "5.1"
    worker_type = "G.1X"
    number_of_workers = 2
    timeout = 10

  command {
    name = "glueetl"

    script_location = "s3://${aws_s3_bucket.glue_scripts.bucket}/${aws_s3_object.glue_script.key}"

    python_version = "3"
  }
}
resource "aws_s3_bucket" "processed" {
  bucket = "lal-sales-processed-terraform-2026"
}
resource "aws_s3_object" "processed_folder" {
  bucket = aws_s3_bucket.processed.bucket

  key = "output/"
}