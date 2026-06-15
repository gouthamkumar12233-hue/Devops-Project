# AWS CI/CD Pipeline Setup Guide

This is a complete CI/CD pipeline implementation using GitHub Actions and AWS services (ECS, ECR, ALB, CloudWatch).

## Architecture Overview

```
GitHub Repository → GitHub Actions → ECR → ECS Fargate
                        ↓
                    Code Quality
                   (Lint, Test)
                        ↓
                   Docker Build
                        ↓
                   Push to ECR
                        ↓
              Update ECS Task Definition
                        ↓
        Deploy to Dev/Prod Environment
                        ↓
                 Smoke Tests & Notify
```

## Components

- **GitHub Actions**: CI/CD orchestration
- **AWS ECR**: Docker image registry
- **AWS ECS Fargate**: Container orchestration
- **AWS ALB**: Load balancing
- **AWS CloudWatch**: Logging and monitoring
- **AWS Secrets Manager**: Secure credential storage

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **GitHub Repository** with admin access
3. **Node.js 18+** (for local development)
4. **Docker** installed locally
5. **AWS CLI** configured with credentials
6. **Terraform** (optional, for infrastructure setup)

## Setup Instructions

### Step 1: Clone and Configure Repository

```bash
git clone <repository-url>
cd my-app
```

### Step 2: Set Up AWS Infrastructure

#### Option A: Using Terraform (Recommended)

```bash
cd terraform/
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

#### Option B: Manual Setup

Create the following AWS resources:
1. **ECR Repository**: `my-app`
2. **ECS Cluster**: `my-app-cluster`
3. **ECS Task Definition**: `my-app-task-def`
4. **Application Load Balancer**
5. **CloudWatch Log Groups**: `/ecs/my-app-dev` and `/ecs/my-app-prod`
6. **VPC and Subnets**

### Step 3: Set GitHub Secrets

In your GitHub repository, add the following secrets (Settings → Secrets and variables → Actions):

```
AWS_ACCESS_KEY_ID          - Your AWS access key
AWS_SECRET_ACCESS_KEY      - Your AWS secret key
SLACK_WEBHOOK_URL          - (Optional) Slack webhook for notifications
```

Create these AWS Secrets Manager entries:
- `dev/db-password`
- `dev/api-key`
- `prod/db-password`
- `prod/api-key`

### Step 4: Configure Environment Variables

Create `.env` file in root directory:

```env
NODE_ENV=development
LOG_LEVEL=debug
```

### Step 5: Set Up GitHub Environments

Create two environments in GitHub (Settings → Environments):

1. **development**
   - Deployment branches: `develop`
   - Required reviewers: (optional)

2. **production**
   - Deployment branches: `main`
   - Required reviewers: 2-3 team members

### Step 6: Update Workflow File

Edit `.github/workflows/deploy-aws.yml`:

```yaml
# Update these values:
env:
  AWS_REGION: us-east-1              # Your region
  ECR_REPOSITORY: my-app              # Your ECR repo name
  ECS_SERVICE: my-app-service         # Your ECS service name
  ECS_CLUSTER: my-app-cluster         # Your ECS cluster name
```

### Step 7: Update IAM Roles

Create IAM roles for ECS:

#### ECS Task Execution Role
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": "arn:aws:secretsmanager:*:*:secret:*"
    }
  ]
}
```

#### ECS Task Role
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:Query",
        "s3:GetObject"
      ],
      "Resource": "*"
    }
  ]
}
```

## Deployment Process

### Development Deployment (develop branch)

1. Create feature branch: `git checkout -b feature/my-feature`
2. Make changes and commit: `git commit -m "Add feature"`
3. Push to develop: `git push origin develop`
4. GitHub Actions automatically runs:
   - Tests and linting
   - Builds Docker image
   - Pushes to ECR
   - Deploys to ECS dev environment
   - Sends Slack notification

### Production Deployment (main branch)

1. Create pull request to `main` branch
2. Code review required
3. Merge to main
4. GitHub Actions runs:
   - All tests and quality checks
   - Builds production Docker image
   - Deploys to ECS prod environment
   - Runs smoke tests
   - Requires manual approval (if configured)
   - Sends deployment notification

## Local Development

### Install Dependencies
```bash
npm install
```

### Development Server
```bash
npm run dev
```

### Running Tests
```bash
npm test                 # Run all tests once
npm run test:coverage    # Generate coverage report
npm run test:watch      # Watch mode
```

### Linting
```bash
npm run lint            # Check for issues
npm run lint:fix        # Auto-fix issues
```

### Building
```bash
npm run build
```

### Docker Locally
```bash
# Build
docker build -t my-app:local .

# Run
docker run -p 3000:3000 my-app:local

# Test
curl http://localhost:3000/health
```

## Monitoring and Logging

### CloudWatch Logs

View logs in AWS Console:
1. Go to CloudWatch → Log Groups
2. Select `/ecs/my-app-dev` or `/ecs/my-app-prod`
3. View real-time logs and metrics

### CloudWatch Metrics

Monitor:
- CPU utilization
- Memory utilization
- Request count
- HTTP error rates
- Application response time

### ECS Service Monitoring

1. Go to ECS → Clusters → my-app-cluster
2. View running tasks
3. Check task logs and events

## Troubleshooting

### Deployment Fails

1. **Check GitHub Actions logs**: Go to Actions tab in GitHub
2. **View ECS task logs**: CloudWatch → Log Groups → `/ecs/my-app-dev`
3. **Verify IAM permissions**: Ensure role has necessary permissions
4. **Check Docker image**: Verify image exists in ECR

### Application Not Responding

1. Check health endpoint: `curl <ALB-DNS>/health`
2. Verify ECS task is running
3. Check security group rules
4. Review application logs in CloudWatch

### ECR Push Fails

```bash
# Verify credentials
aws ecr get-login-password --region us-east-1 | docker login \
  --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com

# Retry push
docker push <IMAGE_URI>
```

### Secrets Not Loading

1. Verify secrets exist in AWS Secrets Manager
2. Check IAM role has `secretsmanager:GetSecretValue` permission
3. Verify secret names match in task definition
4. Check region matches

## Performance Optimization

### Container Optimization
- Use multi-stage Docker builds (reduces image size)
- Minimize dependencies
- Use Alpine base images

### ECS Optimization
- Enable auto-scaling based on CPU/memory
- Use Fargate Spot for non-production
- Implement proper health checks

### Cost Optimization
- Use smaller instance sizes for dev
- Leverage Fargate Spot for 70% cost savings
- Set appropriate log retention

## Security Best Practices

1. **Secrets Management**
   - Store all secrets in AWS Secrets Manager
   - Never commit secrets to Git
   - Use IAM roles instead of access keys

2. **Image Scanning**
   - Enable ECR image scanning
   - Review vulnerability findings
   - Use minimal base images

3. **Network Security**
   - Use security groups to restrict traffic
   - Enable VPC Flow Logs
   - Run containers in private subnets

4. **Access Control**
   - Enforce code review requirements
   - Use GitHub branch protection
   - Limit deployment approvers

## CI/CD Pipeline Flow

```
Push to GitHub
      ↓
[Test] → Code quality checks, unit tests, coverage
      ↓
[Build] → Docker build, image scan, push to ECR
      ↓
[Deploy Dev] → Update task definition, deploy to dev
      ↓
[Deploy Prod] → Requires approval, deploy to prod
      ↓
[Smoke Tests] → Health checks, API validation
      ↓
[Notify] → Slack/Email notification
```

## Advanced Features

### Auto-Scaling

Add to `terraform-aws-infrastructure.tf`:

```hcl
resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = 4
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "ecs_policy_cpu" {
  policy_name       = "cpu-autoscaling"
  policy_type       = "TargetTrackingScaling"
  resource_id       = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 70.0
  }
}
```

### Blue-Green Deployment

Implement in workflow by:
1. Keeping two service definitions (blue/green)
2. Deploying to inactive service
3. Running tests against new version
4. Switching traffic once validated

## Support and Documentation

- [AWS ECS Documentation](https://docs.aws.amazon.com/ecs/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Docker Documentation](https://docs.docker.com/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest)

## License

MIT
