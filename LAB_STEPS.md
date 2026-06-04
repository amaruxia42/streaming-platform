# Step 1 — Deploy Infrastructure

```bash
cd infra/terraform/environments/dev

terraform init

terraform plan

terraform apply
```

---

## Verify outputs 

```bash
terraform output
```

# Step 2 — Verify OIDC Provider Exists

```bash
aws iam list-open-id-connect-providers
```
You should see something similar to:

```bash
arn:aws:iam::<account-id>:oidc-provider/token.actions.githubusercontent.com
```
If not:

```bash
aws iam list-open-id-connect-providers
```

You should see something similar to:

```bash
arn:aws:iam::<account-id>:oidc-provider/token.actions.githubusercontent.com
```

If not:

```bash
cd infra/terraform/bootstrap/github-oidc

terraform init

terraform apply
```

# Step 3 — Verify GitHub Actions Role

Retrieve the role:

```bash
aws iam get-role \
  --role-name streaming-mvp-dev-github-actions-role
```




