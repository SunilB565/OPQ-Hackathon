# Hackathon Microservices Repo

This repository contains two Node microservices (`opq-notes-service` and `opq-storage-service`), Dockerfiles, a Jenkins CI pipeline, and Terraform to deploy both services to AWS ECS Fargate (dev and prod).

What this repo does
- Implements OPQ Notes: a front-end API (`opq-notes-service`) that lists notes and requests access, and a storage API (`opq-storage-service`) that holds notes, students and access requests.
- Builds Docker images for both services and pushes to AWS ECR.
- Scans images with Trivy and scans Terraform with Checkov.
- Runs tests (Jest) and publishes JUnit results to Jenkins.
- Deploys infra to AWS (VPC, subnets, ALB, ECS Fargate tasks, service discovery, Prometheus, Grafana) for `dev` and `prod`.
- Adds HTTPS via ACM/Route53 for a provided domain (optional, configured by `domain_name`).

Files of interest
- `services/opq-notes-service` (service listening on port 3000)
- `services/opq-storage-service` (service listening on port 4000)
- `jenkins/Jenkinsfile` (CI pipeline)
- `jenkins/agent/Dockerfile` (example Jenkins agent image with required tools)
- `terraform/dev` and `terraform/prod` (infrastructure for each environment)
- `tests/integration/dev_integration_test.sh` (integration test executed after dev deploy)

High-level pipeline stages (in `jenkins/Jenkinsfile`)
- Checkout
- Node Build & Test (npm ci, npm test) — tests must pass before continuing
- Publish JUnit test results
- Sonar scan
- Docker build (dev images: `dev-<short-sha>`)
- Trivy image scan
- Push dev images to ECR
- Checkov Terraform scan
- Terraform deploy `dev` (creates infra, ALB, ECS services, Prometheus, Grafana)
- Integration tests (against dev ALB)
- Create & push prod images (tagged `prod-<short-sha>`)
- Terraform deploy `prod`

Prerequisites (before you run pipeline)
- An AWS account and an IAM principal (user or role) with permissions for ECR, ECS, IAM, CloudWatch, ALB, VPC, S3, DynamoDB, ACM, Route53, and Route53 record management. Use `jenkins/iam/jenkins-ci-policy.json` as a starting example and tighten to least-privilege later.
- Jenkins (master) with a build agent able to run Docker builds. Alternatively use the `jenkins-agent:latest` image built from `jenkins/agent/Dockerfile`.
- Docker on the Jenkins agent machine to build and push images (or a Docker-in-Docker capable setup).
- Domain name (you will provide `domain_name` in the pipeline / Terraform variables).

Credentials & environment variables you will add to Jenkins (all required)
- `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` (or configure an instance role)
- `AWS_ACCOUNT_ID` (string)
- `AWS_REGION` (string, default `us-east-1`)
- `ADMIN_TOKEN` (secret text) — used by the storage service `approve` endpoint and the integration test
- `SONAR_HOST_URL` and `SONAR_LOGIN` (if you run Sonar)

Top-level setup steps (copy-and-run commands)

1) Push this repository to your Git server (GitHub/GitLab/Bitbucket).

2) Build and publish Jenkins agent image (optional — you can run agents differently)
```bash
docker build -t jenkins-agent:latest -f jenkins/agent/Dockerfile jenkins/agent
# optional: push to your registry
docker tag jenkins-agent:latest <REGISTRY>/jenkins-agent:latest
docker push <REGISTRY>/jenkins-agent:latest
```

3) Create Terraform remote backend (S3 + DynamoDB) — run locally or from a build machine
```bash
bash terraform/backend_setup/create-backend.sh us-east-1 my-unique-terraform-bucket hackathon-lock
# Replace my-unique-terraform-bucket and hackathon-lock with unique names.
```
Edit `terraform/dev/backend.tf` and `terraform/prod/backend.tf` to replace `BUCKET_NAME` and `LOCK_TABLE` with the bucket/table you created, or pass them via `terraform init -backend-config` in the pipeline.

4) Configure Jenkins job (Pipeline)
- Create a new Pipeline job (multibranch or pipeline) and point to this repo's `Jenkinsfile`.
- Ensure the Jenkins agent can run the tools: Docker, awscli, terraform, trivy, checkov, nodejs, npm, python3, curl, sonar-scanner.
- Add Jenkins Credentials (Credentials > System > Global credentials):
	- AWS credentials (access key/secret)
	- `SONAR_LOGIN` (secret text) if using Sonar
	- `ADMIN_TOKEN` (secret text)
- Add these environment variables to the job (or configure them at global level): `AWS_ACCOUNT_ID`, `AWS_REGION` (optional), `SONAR_HOST_URL`.

5) Make helper scripts executable (if you edit locally before push)
```bash
chmod +x scripts/trivy_scan.sh scripts/checkov_scan.sh terraform/backend_setup/create-backend.sh tests/integration/dev_integration_test.sh
```

6) Commit & push your code to Git and start the Jenkins job
- The pipeline will run automatically through the stages described above.

How credentials and domain are used in the pipeline
- `ADMIN_TOKEN` is exported into Terraform as `TF_VAR_admin_token` and injected into the storage ECS task environment. The integration test uses it to approve requests.
- `AWS_*` credentials are used to create ECR repos, push images, and run Terraform.
- `SONAR_LOGIN` and `SONAR_HOST_URL` are required for Sonar scanning.
- `domain_name` (Terraform var) enables Route53/ACM creation and HTTPS. You can provide `domain_name` and set `create_hosted_zone=true` in the Terraform `apply` step to allow Terraform to create the hosted zone. Alternatively supply an existing `hosted_zone_id`.

Integration test flow (automated in pipeline)
1. Pipeline runs Terraform in `terraform/dev` and outputs the ALB DNS.
2. Pipeline runs `tests/integration/dev_integration_test.sh <alb_dns> <admin_token>`.
3. The test:
	 - Lists notes via `GET /api/storage/notes`.
	 - Creates a request for student `alice` via `POST /api/storage/requests`.
	 - Uses `X-ADMIN-TOKEN: <ADMIN_TOKEN>` to POST `/api/storage/approve`.
	 - Fetches `/api/storage/notes/1/content?student=alice` and verifies `content` in response.

Troubleshooting tips
- If ACM DNS validation fails: check the created Route53 records and ensure your registrar delegates the domain or that the hosted zone matches the domain.
- If the ALB target group shows unhealthy tasks: check container logs in CloudWatch (log groups created under `/ecs/...`) and ensure health check path (`/health`) returns 200.
- If Docker push fails: confirm `AWS_ACCOUNT_ID`, `AWS_REGION`, and that Jenkins agent can authenticate to ECR.

Security notes (do these before production)
- Replace `jenkins/iam/jenkins-ci-policy.json` with a least-privilege policy.
- Move secrets out of plain env vars and into Jenkins Credentials or AWS Secrets Manager.
- Add proper authentication for admin actions (we use `ADMIN_TOKEN` header for demo).

If you want me to also:
- A) Provide a Jenkins Job DSL or example job config to create the pipeline automatically, or
- B) Switch path-based ALB routing to host-based routing (subdomains) and update tests to use `https://api.<your-domain>`.

Contact
If you provide the `domain_name` and confirm you will add credentials in Jenkins, the pipeline will perform the full build, image push, infra creation, integration test and production promotion without manual infra steps.


Overview
- Two Node microservices in `services/`: `order-service` (port 3000) and `storage-service` (port 4000).
- Prometheus and Grafana are deployed as ECS tasks (for observability).
- CI pipeline (Jenkins) builds, tests, scans, pushes images to ECR, runs Checkov, deploys dev, creates prod images, and deploys prod.

Placeholders you must set in Jenkins or replace in pipeline
- `AWS_ACCOUNT_ID` — your AWS account ID
- `AWS_REGION` — default `us-east-1`
- `SONAR_HOST_URL` — SonarQube server URL
- `SONAR_LOGIN` — Sonar token

Suggested resource names (examples only)
- S3 backend bucket names:
	- hackathon-terraform-state-yourteam-dev
	- hackathon-terraform-state-yourteam-prod
	- hackathon-tfstate-<region>-<yourname>
- Terraform DynamoDB lock table names:
	- hackathon-terraform-lock-dev
	- hackathon-terraform-lock-prod
- ECR repository names (recommended):
	- order-service
	- storage-service
- ECS service names (recommended):
	- order-service
	- storage-service
	- prometheus
	- grafana

Complete setup steps (copyable)

1) Create Terraform remote backend (recommended)

```bash
# create an S3 bucket and DynamoDB table (example)
bash terraform/backend_setup/create-backend.sh us-east-1 my-unique-terraform-bucket hackathon-lock

# Update terraform/dev/backend.tf and terraform/prod/backend.tf replacing BUCKET_NAME and LOCK_TABLE
# OR pass backend config at init time:
cd terraform/dev
terraform init -backend-config="bucket=my-unique-terraform-bucket" -backend-config="dynamodb_table=hackathon-lock"
```

2) Build and publish the Jenkins agent image (optional — you can also configure a machine with the toolchain)

```bash
# build locally
docker build -t jenkins-agent:latest -f jenkins/agent/Dockerfile jenkins/agent

# optionally push to a registry you use for Jenkins agents
docker tag jenkins-agent:latest <YOUR_REGISTRY>/jenkins-agent:latest
docker push <YOUR_REGISTRY>/jenkins-agent:latest
```

3) Configure Jenkins

- Plugins to install: Pipeline, Git, Credentials, Docker Pipeline, AWS Steps/CLI plugin, JUnit, SonarQube Scanner plugin.
- Credentials to add (use Jenkins Credentials store):
	- `aws-credentials` (AWS access key ID / secret) or configure instance role for Jenkins master/agent.
	- `sonar-token` (Secret text) — set as `SONAR_LOGIN` env var in the pipeline or in Jenkins global env.
	- (optional) Docker registry credentials if you push agent image to a private registry.

- Environment variables to set in the Jenkins job or globally:
	- `AWS_ACCOUNT_ID` — your AWS account id
	- `AWS_REGION` — e.g., `us-east-1`
	- `SONAR_HOST_URL` — Sonar server URL
	- `SONAR_LOGIN` — Sonar token (can be referenced from credentials)

4) How the `Jenkinsfile` in this repo works (summary)

- Checkout repository
- Node Build & Test: runs `npm ci` and `npm test` for each service. Tests must pass — otherwise pipeline stops.
- Publish Test Results: JUnit XMLs are published from `services/**/test-results/*.xml`.
- Sonar Scan: runs `sonar-scanner` for both services (requires `SONAR_HOST_URL` and `SONAR_LOGIN`).
- Docker Build: builds images and tags them as `dev-<short-sha>`.
- Trivy Scan: runs `trivy` against built images.
- Push to ECR: creates ECR repos (if needed) and pushes dev images.
- Checkov Terraform Scan: runs `checkov -d terraform`.
- Deploy Dev: runs `terraform init` and `terraform apply` in `terraform/dev`, passing dev image URIs via variables.
- Create Prod Image: tags and pushes prod images (`prod-<short-sha>`).
- Deploy Prod: runs `terraform init` and `terraform apply` in `terraform/prod`, passing prod image URIs via variables.

5) Running pipeline examples

Ensure Jenkins has access to Docker (the `Jenkinsfile` uses a docker-based agent and mounts `/var/run/docker.sock`).

6) Testing locally (if desired)

To run tests locally (optional):

```bash
cd services/order-service
npm ci
npm test

cd ../storage-service
npm ci
npm test
```

7) Notes on security

- The provided `jenkins/iam/jenkins-ci-policy.json` is permissive for convenience. Tighten IAM permissions to least privilege before production.
- Store secrets and tokens in Jenkins Credentials, not in files.

Support and extensions
- I can: add JUnit report filename templating, add a `post` block in `Jenkinsfile` to archive logs on failure, or harden IAM policies. Tell me which you want next.


