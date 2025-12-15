#!/usr/bin/env bash
set -euo pipefail

############################################
# Hardcoded values from Terraform
############################################
AWS_REGION="us-west-1"

ECS_CLUSTER="example-api-cluster"
ECS_SERVICE="example-api-service"

# Terraform: family = "${var.app_name}-task"
TASK_FAMILY="example-api-task"

# Terraform: container name = var.app_name
CONTAINER_NAME="example-app"

# Repo-specific: set your ECR repository name here
# (the part after ...amazonaws.com/)
ECR_REPOSITORY="example-app-fastapi"

############################################
# Derived values
############################################
AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query 'Account' --output text)"
IMAGE_REF="ghcr.io/denisiomytnysiano/example-app/fastapi-ping:91eec67"

echo "==> AWS identity:"
aws sts get-caller-identity >/dev/null
echo "    Account: ${AWS_ACCOUNT_ID}"
echo "    Region : ${AWS_REGION}"

echo "==> Deploying image ${IMAGE_REF}"
echo "    Cluster  : ${ECS_CLUSTER}"
echo "    Service  : ${ECS_SERVICE}"
echo "    Family   : ${TASK_FAMILY}"
echo "    Container: ${CONTAINER_NAME}"

############################################
# Ensure the cluster/service exist (helps with clearer errors)
############################################
aws ecs describe-clusters --clusters "${ECS_CLUSTER}" --query 'clusters[0].clusterName' --output text >/dev/null
aws ecs describe-services --cluster "${ECS_CLUSTER}" --services "${ECS_SERVICE}" --query 'services[0].serviceName' --output text >/dev/null

############################################
# Get the currently-used task definition ARN
############################################
CURRENT_TASK_DEF_ARN="$(aws ecs describe-services \
  --cluster "${ECS_CLUSTER}" \
  --services "${ECS_SERVICE}" \
  --query 'services[0].taskDefinition' \
  --output text)"

if [[ -z "${CURRENT_TASK_DEF_ARN}" || "${CURRENT_TASK_DEF_ARN}" == "None" ]]; then
  echo "ERROR: Could not determine current task definition ARN for ${ECS_SERVICE}" >&2
  exit 2
fi

echo "==> Current task definition: ${CURRENT_TASK_DEF_ARN}"

############################################
# Fetch current task definition JSON
############################################
aws ecs describe-task-definition --task-definition "${CURRENT_TASK_DEF_ARN}" > taskdef.json

############################################
# Build new task definition JSON:
# - update container image by container name
# - strip read-only fields
############################################
NEW_TASK_DEF="$(jq --arg IMAGE "${IMAGE_REF}" --arg CNAME "${CONTAINER_NAME}" '
  .taskDefinition
  | (.containerDefinitions[] | select(.name == $CNAME) | .image) = $IMAGE
  | del(
      .taskDefinitionArn,
      .revision,
      .status,
      .requiresAttributes,
      .compatibilities,
      .registeredAt,
      .registeredBy
    )
' taskdef.json)"

# Fail fast if container name didn't match
if ! echo "${NEW_TASK_DEF}" | jq -e --arg CNAME "${CONTAINER_NAME}" '.containerDefinitions[] | select(.name == $CNAME)' >/dev/null; then
  echo "ERROR: No container named '${CONTAINER_NAME}' found in the task definition." >&2
  echo "Available containers are:" >&2
  jq -r '.taskDefinition.containerDefinitions[].name' taskdef.json >&2
  exit 3
fi

echo "${NEW_TASK_DEF}" > new-taskdef.json

############################################
# Register new revision
############################################
echo "==> Registering new task definition revision..."
NEW_TASK_DEF_ARN="$(aws ecs register-task-definition \
  --cli-input-json file://new-taskdef.json \
  --query 'taskDefinition.taskDefinitionArn' \
  --output text)"

if [[ -z "${NEW_TASK_DEF_ARN}" || "${NEW_TASK_DEF_ARN}" == "None" ]]; then
  echo "ERROR: Failed to register new task definition revision." >&2
  exit 4
fi

echo "==> New task definition: ${NEW_TASK_DEF_ARN}"

############################################
# Update service and wait for stability
############################################
echo "==> Updating service..."
aws ecs update-service \
  --cluster "${ECS_CLUSTER}" \
  --service "${ECS_SERVICE}" \
  --task-definition "${NEW_TASK_DEF_ARN}" \
  --force-new-deployment >/dev/null

echo "==> Waiting for service to become stable..."
aws ecs wait services-stable --cluster "${ECS_CLUSTER}" --services "${ECS_SERVICE}"

echo "✅ Done. Service ${ECS_SERVICE} is now deploying ${IMAGE_REF}"
