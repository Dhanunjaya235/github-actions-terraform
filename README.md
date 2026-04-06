# github-actions-terraform

This repository provisions AWS infrastructure with Terraform and automates `plan` and `apply` through GitHub Actions.

At the moment, the Terraform code creates a single S3 bucket named `github-actions-demo-<environment>` and tags it with the selected environment and project name.

## What this repo does

- Runs `terraform fmt -check`, `terraform validate`, and `terraform plan` on pull requests.
- Uploads the generated Terraform plan file to Amazon S3.
- Runs `terraform apply` on pushes to environment branches.
- Stores Terraform state in an S3 backend.
- Uses GitHub Environments to separate `dev`, `test`, `uat`, and `prod`.

## Workflow behavior

### Terraform Plan

Workflow file: `.github/workflows/terraform-plan.yml`

- Trigger: pull requests targeting `dev`, `test`, `uat`, or `master`
- Resolves the target environment from the PR base branch
- Configures AWS credentials from GitHub secrets
- Runs:
  - `terraform init`
  - `terraform fmt -check`
  - `terraform validate`
  - `terraform plan`
- Uploads the generated `tfplan` file to:

```text
s3://github-actions-demo-artifacts/<env>/<pull_request_number>.tfplan
```

### Terraform Apply

Workflow file: `.github/workflows/terraform-apply.yml`

- Trigger: pushes to `dev`, `test`, `uat`, or `master`
- Resolves the environment from the pushed branch
- Downloads the previously uploaded plan file from S3
- Applies that exact saved plan with:

```bash
terraform apply -auto-approve tfplan
```

The apply workflow extracts the PR number from the merge commit message. Because of that, it expects the commit message to contain a value like `#12`.

## Branch to environment mapping

| Git branch | Deployment environment |
| --- | --- |
| `dev` | `dev` |
| `test` | `test` |
| `uat` | `uat` |
| `master` | `prod` |

Note: the workflow expressions also contain a `main -> prod` fallback, but `main` is not currently included in the workflow triggers.

## Required GitHub configuration

### Secrets

| Name | Purpose |
| --- | --- |
| `AWS_ACCESS_KEY_ID` | AWS access key used by GitHub Actions |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key used by GitHub Actions |

### Repository variables

| Name | Purpose |
| --- | --- |
| `AWS_REGION` | Required by the AWS credentials step and passed to Terraform plan |
| `PROJECT_NAME` | Optional project name used in tags, with a workflow fallback of `github-actions-demo` |
| `ENVIRONMENT` | Optional Terraform environment override, with a workflow fallback to the branch-derived environment |

### GitHub Environments

Create these environments in the repository if you want the workflow environment mapping to work cleanly:

- `dev`
- `test`
- `uat`
- `prod`

## Terraform configuration

### Versions

- Terraform: `>= 1.0`
- AWS provider: `~> 5.0`

### Backend

Terraform uses an S3 backend. The repository is currently configured to use:

- State bucket: `cognine-terraform-states`
- Backend region: `ap-south-1`
- State key pattern used by the workflows:

```text
github-actions-demo/<env>/terraform.tfstate
```

### Plan artifact storage

The plan workflow uploads plan files to this S3 bucket:

- Plan bucket: `github-actions-demo-artifacts`

Make sure both S3 buckets already exist or are created separately before using the workflows.

## Current Terraform resources

This repo currently manages:

- `aws_s3_bucket.main`

Bucket naming pattern:

```text
github-actions-demo-<environment>
```

Note: the bucket name prefix is currently hardcoded as `github-actions-demo`. The `project_name` variable affects tags, not the S3 bucket name.

Default Terraform variable values:

| Variable | Default |
| --- | --- |
| `aws_region` | `ap-south-1` |
| `environment` | `dev` |
| `project_name` | `github-actions-demo` |

## Outputs

Terraform exposes these outputs:

- `s3_bucket_id`
- `s3_bucket_arn`
- `s3_bucket_region`

## Repository structure

```text
.
|- .github/
|  |- workflows/
|     |- terraform-plan.yml
|     |- terraform-apply.yml
|- main.tf
|- variables.tf
|- outputs.tf
|- README.md
```

## Running Terraform locally

Example for the `dev` environment:

```bash
terraform init \
  -backend-config="bucket=cognine-terraform-states" \
  -backend-config="key=github-actions-demo/dev/terraform.tfstate"

terraform plan \
  -var="aws_region=ap-south-1" \
  -var="environment=dev" \
  -var="project_name=github-actions-demo"
```

## Notes

- Production is currently tied to the `master` branch.
- The `terraform apply` workflow depends on a previously uploaded plan file being available in S3.
- If the merge commit message does not contain a PR number, the apply workflow will fail during the PR number extraction step.
