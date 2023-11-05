moved {
  from = aws_iam_policy.sns_pub
  to   = module.sns.module.publish_perms.aws_iam_policy.main
}

moved {
  from = aws_iam_role_policy_attachment.publish_msg_sns_topic
  to   = module.sns.module.publish_perms.aws_iam_role_policy_attachment.main["iam_for_publish_msg"]
}

moved {
  from = aws_sns_topic.page_request
  to   = module.sns.aws_sns_topic.main
}
