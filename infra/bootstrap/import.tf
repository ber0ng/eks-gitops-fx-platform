# Bucket created for terraform state storage. This is a one-time operation and should be removed after the initial bootstrap is complete.
import {
  to = aws_s3_bucket.terraform_state_bucket
  id = "fxwatch-tfstate"
}
