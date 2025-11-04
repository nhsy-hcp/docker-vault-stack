# Compute trust policy identifiers
# If trust_policy_arns is provided, use it; otherwise default to current session ARN
locals {
  computed_trust_policy_arns = length(var.trust_policy_arns) > 0 ? var.trust_policy_arns : [data.aws_caller_identity.current.arn]
}

# IAM trust policy for Vault to assume the role
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type = "AWS"
      # Allow specified IAM principals or default to current session
      identifiers = local.computed_trust_policy_arns
    }

    actions = [
      "sts:AssumeRole",
      "sts:SetSourceIdentity"
    ]
  }
}

# IAM policy document for Secrets Manager permissions
data "aws_iam_policy_document" "secrets_manager" {
  statement {
    sid    = "VaultSecretsManagerSync"
    effect = "Allow"

    actions = [
      "secretsmanager:CreateSecret",
      "secretsmanager:UpdateSecret",
      "secretsmanager:DeleteSecret",
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:PutSecretValue",
      "secretsmanager:TagResource",
      "secretsmanager:UntagResource"
    ]

    resources = ["arn:aws:secretsmanager:*:*:secret:vault/*"]
  }

  statement {
    sid    = "VaultSecretsManagerList"
    effect = "Allow"

    actions = [
      "secretsmanager:ListSecrets"
    ]

    resources = ["*"]
  }
}

# IAM role for Vault secrets sync
resource "aws_iam_role" "vault_secrets_sync" {
  name               = var.secrets_sync_role_name
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = {
    ManagedBy   = "Terraform"
    Purpose     = "Vault Secrets Sync"
    Environment = "training"
  }
}

# IAM policy for Secrets Manager access
resource "aws_iam_policy" "vault_secrets_sync" {
  name        = "${var.secrets_sync_role_name}-policy"
  description = "Permissions for Vault to sync secrets to AWS Secrets Manager"
  policy      = data.aws_iam_policy_document.secrets_manager.json

  tags = {
    ManagedBy   = "Terraform"
    Purpose     = "Vault Secrets Sync"
    Environment = "training"
  }
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "vault_secrets_sync" {
  role       = aws_iam_role.vault_secrets_sync.name
  policy_arn = aws_iam_policy.vault_secrets_sync.arn
}