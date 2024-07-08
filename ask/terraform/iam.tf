resource "aws_iam_role" "lambda_exec_role" {
  name        = "${var.function_name}"
  path        = "/"
  description = "Allows Lambda Function to call AWS services on your behalf."

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "policy" {
  name        = "${var.function_name}-policy"
  path        = "/"
  description = "${var.function_name}-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:${var.aws_region}:${var.aws_account}:log-group:/aws/lambda/${var.function_name}:*"
      },
      {
        Action = [
          "dynamodb:Query",
        ]
        Effect   = "Allow"
        Resource = "arn:aws:dynamodb:${var.aws_region}:${var.aws_account}:table/${var.dynamodb_table_name}/index/${var.dynamodb_table_index}"
      },
      {
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Effect   = "Allow"
        Resource = ["arn:aws:secretsmanager:${var.aws_region}:${var.aws_account}:secret:${var.FINDLY_SECRET_NAME}*"]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "policy_attachment" {
  policy_arn = aws_iam_policy.policy.arn
  role       = aws_iam_role.lambda_exec_role.name
}
