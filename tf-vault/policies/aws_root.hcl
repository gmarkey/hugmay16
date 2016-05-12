path "ssh/roles/aws_root" {
  policy = "write"
}

path "ssh/lookup" {
  policy = "write"
}

path "ssh/creds/aws_root" {
  policy = "write"
}

path "sys/revoke/ssh/creds/aws_root" {
  policy = "write"
}

path "aws/creds/admin" {
  policy = "read"
}
