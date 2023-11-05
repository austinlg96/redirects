output "function" {
  value = {
    arn           = aws_lambda_function.main.arn
    invoke_arn    = aws_lambda_function.main.invoke_arn
    function_name = aws_lambda_function.main.function_name
  }
}

output "role" {
  value = {
    name = aws_iam_role.main.name
    arn  = aws_iam_role.main.arn
  }
}
