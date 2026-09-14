#!/bin/bash
set -euo pipefail

# ==================================================
# DemoApp ECS Blue/Green Infrastructure Setup
# Safe to run repeatedly in AWS Academy Learner Lab
# ==================================================

REGION="us-east-1"

CLUSTER="demo-cluster"
SERVICE="demoapp-service"

SG_NAME="demoapp-sg"
ALB_NAME="demoapp-alb"
TG1_NAME="demoapp-tg-1"
TG2_NAME="demoapp-tg-2"

echo "=========================================="
echo " DemoApp ECS Blue/Green Infrastructure"
echo "=========================================="

ACCOUNT_ID=$(aws sts get-caller-identity \
  --query Account \
  --output text)

echo "Account: $ACCOUNT_ID"
echo "Region:  $REGION"

# --------------------------------------------------
# 1. Find the default VPC
# --------------------------------------------------

VPC_ID=$(aws ec2 describe-vpcs \
  --region "$REGION" \
  --filters "Name=is-default,Values=true" \
  --query "Vpcs[0].VpcId" \
  --output text)

if [ -z "$VPC_ID" ] || [ "$VPC_ID" = "None" ]; then
  echo "ERROR: No default VPC found in $REGION."
  exit 1
fi

echo "VPC:     $VPC_ID"

# --------------------------------------------------
# 2. Find two subnets in different Availability Zones
# --------------------------------------------------

SUBNET_INFO=$(aws ec2 describe-subnets \
  --region "$REGION" \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query "sort_by(Subnets,&AvailabilityZone)[].[SubnetId,AvailabilityZone]" \
  --output text)

SUBNET1=$(echo "$SUBNET_INFO" | awk 'NR==1 {print $1}')
AZ1=$(echo "$SUBNET_INFO" | awk 'NR==1 {print $2}')

SUBNET2=$(echo "$SUBNET_INFO" | awk -v az="$AZ1" '$2 != az {print $1; exit}')
AZ2=$(echo "$SUBNET_INFO" | awk -v az="$AZ1" '$2 != az {print $2; exit}')

if [ -z "$SUBNET1" ] || [ -z "$SUBNET2" ]; then
  echo "ERROR: Two subnets in different Availability Zones are required."
  exit 1
fi

echo "Subnet 1: $SUBNET1 ($AZ1)"
echo "Subnet 2: $SUBNET2 ($AZ2)"

# --------------------------------------------------
# Helper functions
# --------------------------------------------------

get_tg_arn() {
  aws elbv2 describe-target-groups \
    --names "$1" \
    --region "$REGION" \
    --query "TargetGroups[0].TargetGroupArn" \
    --output text 2>/dev/null || true
}

get_tg_vpc() {
  aws elbv2 describe-target-groups \
    --names "$1" \
    --region "$REGION" \
    --query "TargetGroups[0].VpcId" \
    --output text 2>/dev/null || true
}

create_target_group() {
  aws elbv2 create-target-group \
    --name "$1" \
    --protocol HTTP \
    --port 3000 \
    --vpc-id "$VPC_ID" \
    --target-type ip \
    --health-check-path / \
    --region "$REGION" \
    --query "TargetGroups[0].TargetGroupArn" \
    --output text
}

ensure_target_group() {
  local name="$1"
  local arn
  local tg_vpc

  arn=$(get_tg_arn "$name")

  if [ -n "$arn" ] && [ "$arn" != "None" ]; then
    tg_vpc=$(get_tg_vpc "$name")

    if [ "$tg_vpc" = "$VPC_ID" ]; then
      echo "Reusing Target Group: $name" >&2
      printf '%s\n' "$arn"
      return
    fi

    echo "Removing old Target Group $name from VPC $tg_vpc..." >&2

    aws elbv2 delete-target-group \
      --target-group-arn "$arn" \
      --region "$REGION" >/dev/null

    sleep 2
  fi

  echo "Creating Target Group: $name" >&2
  create_target_group "$name"
}

# --------------------------------------------------
# 3. Ensure ECS cluster
# --------------------------------------------------

CLUSTER_STATUS=$(aws ecs describe-clusters \
  --clusters "$CLUSTER" \
  --region "$REGION" \
  --query "clusters[0].status" \
  --output text 2>/dev/null || true)

if [ "$CLUSTER_STATUS" = "ACTIVE" ]; then
  echo "Reusing ECS Cluster: $CLUSTER"
else
  echo "Creating ECS Cluster: $CLUSTER"

  aws ecs create-cluster \
    --cluster-name "$CLUSTER" \
    --region "$REGION" >/dev/null
fi

# --------------------------------------------------
# 4. Check existing ECS service VPC
# --------------------------------------------------

SERVICE_STATUS=$(aws ecs describe-services \
  --cluster "$CLUSTER" \
  --services "$SERVICE" \
  --region "$REGION" \
  --query "services[0].status" \
  --output text 2>/dev/null || true)

if [ "$SERVICE_STATUS" = "ACTIVE" ]; then

  SERVICE_SUBNET=$(aws ecs describe-services \
    --cluster "$CLUSTER" \
    --services "$SERVICE" \
    --region "$REGION" \
    --query "services[0].networkConfiguration.awsvpcConfiguration.subnets[0]" \
    --output text)

  SERVICE_VPC=$(aws ec2 describe-subnets \
    --subnet-ids "$SERVICE_SUBNET" \
    --region "$REGION" \
    --query "Subnets[0].VpcId" \
    --output text 2>/dev/null || true)

  if [ "$SERVICE_VPC" != "$VPC_ID" ]; then
    echo "Existing ECS service belongs to old VPC $SERVICE_VPC."
    echo "Recreating ECS service..."

    aws ecs delete-service \
      --cluster "$CLUSTER" \
      --service "$SERVICE" \
      --force \
      --region "$REGION" >/dev/null

    echo "Waiting for old ECS service to become inactive..."

    aws ecs wait services-inactive \
      --cluster "$CLUSTER" \
      --services "$SERVICE" \
      --region "$REGION"

    SERVICE_STATUS="INACTIVE"
  else
    echo "Reusing ECS Service: $SERVICE"
  fi
fi

# --------------------------------------------------
# 5. Ensure Security Group
# --------------------------------------------------

SG_ID=$(aws ec2 describe-security-groups \
  --region "$REGION" \
  --filters \
    "Name=vpc-id,Values=$VPC_ID" \
    "Name=group-name,Values=$SG_NAME" \
  --query "SecurityGroups[0].GroupId" \
  --output text)

if [ -z "$SG_ID" ] || [ "$SG_ID" = "None" ]; then

  echo "Creating Security Group: $SG_NAME"

  SG_ID=$(aws ec2 create-security-group \
    --group-name "$SG_NAME" \
    --description "DemoApp ECS Blue Green security group" \
    --vpc-id "$VPC_ID" \
    --region "$REGION" \
    --query GroupId \
    --output text)

else
  echo "Reusing Security Group: $SG_ID"
fi

for PORT in 80 8080 3000; do

  RULE_EXISTS=$(aws ec2 describe-security-group-rules \
    --region "$REGION" \
    --filters "Name=group-id,Values=$SG_ID" \
    --query "length(SecurityGroupRules[?IsEgress==\`false\` && IpProtocol=='tcp' && FromPort==\`$PORT\` && ToPort==\`$PORT\` && CidrIpv4=='0.0.0.0/0'])" \
    --output text)

  if [ "$RULE_EXISTS" = "0" ]; then
    echo "Adding inbound TCP/$PORT"

    aws ec2 authorize-security-group-ingress \
      --group-id "$SG_ID" \
      --protocol tcp \
      --port "$PORT" \
      --cidr 0.0.0.0/0 \
      --region "$REGION" >/dev/null
  else
    echo "Inbound TCP/$PORT already exists. Reusing."
  fi
done

echo "Security Group: $SG_ID"

# --------------------------------------------------
# 6. Check existing ALB VPC
# --------------------------------------------------

ALB_ARN=$(aws elbv2 describe-load-balancers \
  --names "$ALB_NAME" \
  --region "$REGION" \
  --query "LoadBalancers[0].LoadBalancerArn" \
  --output text 2>/dev/null || true)

if [ -n "$ALB_ARN" ] && [ "$ALB_ARN" != "None" ]; then

  ALB_VPC=$(aws elbv2 describe-load-balancers \
    --names "$ALB_NAME" \
    --region "$REGION" \
    --query "LoadBalancers[0].VpcId" \
    --output text)

  if [ "$ALB_VPC" != "$VPC_ID" ]; then

    echo "Existing ALB belongs to old VPC $ALB_VPC."
    echo "Deleting old ALB..."

    aws elbv2 delete-load-balancer \
      --load-balancer-arn "$ALB_ARN" \
      --region "$REGION"

    aws elbv2 wait load-balancers-deleted \
      --load-balancer-arns "$ALB_ARN" \
      --region "$REGION"

    ALB_ARN=""
  else
    echo "Reusing ALB: $ALB_NAME"
  fi
fi

# --------------------------------------------------
# 7. Ensure Target Groups
# --------------------------------------------------

TG1=$(ensure_target_group "$TG1_NAME")
TG2=$(ensure_target_group "$TG2_NAME")

echo "Target Group 1 ready"
echo "Target Group 2 ready"

# --------------------------------------------------
# 8. Ensure ALB
# --------------------------------------------------

if [ -z "${ALB_ARN:-}" ] || [ "$ALB_ARN" = "None" ]; then

  echo "Creating ALB: $ALB_NAME"

  ALB_ARN=$(aws elbv2 create-load-balancer \
    --name "$ALB_NAME" \
    --type application \
    --scheme internet-facing \
    --security-groups "$SG_ID" \
    --subnets "$SUBNET1" "$SUBNET2" \
    --region "$REGION" \
    --query "LoadBalancers[0].LoadBalancerArn" \
    --output text)
fi

echo "Waiting for ALB..."

aws elbv2 wait load-balancer-available \
  --load-balancer-arns "$ALB_ARN" \
  --region "$REGION"

echo "ALB ready"

# --------------------------------------------------
# 9. Ensure Production listener :80
# --------------------------------------------------

PROD_LISTENER=$(aws elbv2 describe-listeners \
  --load-balancer-arn "$ALB_ARN" \
  --region "$REGION" \
  --query "Listeners[?Port==\`80\`].ListenerArn | [0]" \
  --output text)

if [ -z "$PROD_LISTENER" ] || [ "$PROD_LISTENER" = "None" ]; then

  echo "Creating Production listener :80"

  PROD_LISTENER=$(aws elbv2 create-listener \
    --load-balancer-arn "$ALB_ARN" \
    --protocol HTTP \
    --port 80 \
    --default-actions "Type=forward,TargetGroupArn=$TG1" \
    --region "$REGION" \
    --query "Listeners[0].ListenerArn" \
    --output text)

else

  echo "Production listener already exists. Ensuring TG1 routing."

  aws elbv2 modify-listener \
    --listener-arn "$PROD_LISTENER" \
    --default-actions "Type=forward,TargetGroupArn=$TG1" \
    --region "$REGION" >/dev/null
fi

# --------------------------------------------------
# 10. Ensure Test listener :8080
# --------------------------------------------------

TEST_LISTENER=$(aws elbv2 describe-listeners \
  --load-balancer-arn "$ALB_ARN" \
  --region "$REGION" \
  --query "Listeners[?Port==\`8080\`].ListenerArn | [0]" \
  --output text)

if [ -z "$TEST_LISTENER" ] || [ "$TEST_LISTENER" = "None" ]; then

  echo "Creating Test listener :8080"

  TEST_LISTENER=$(aws elbv2 create-listener \
    --load-balancer-arn "$ALB_ARN" \
    --protocol HTTP \
    --port 8080 \
    --default-actions "Type=forward,TargetGroupArn=$TG2" \
    --region "$REGION" \
    --query "Listeners[0].ListenerArn" \
    --output text)

else

  echo "Test listener already exists. Ensuring TG2 routing."

  aws elbv2 modify-listener \
    --listener-arn "$TEST_LISTENER" \
    --default-actions "Type=forward,TargetGroupArn=$TG2" \
    --region "$REGION" >/dev/null
fi

echo "Listeners ready"

# --------------------------------------------------
# 11. Reuse or register Task Definition
# --------------------------------------------------

SERVICE_STATUS=$(aws ecs describe-services \
  --cluster "$CLUSTER" \
  --services "$SERVICE" \
  --region "$REGION" \
  --query "services[0].status" \
  --output text 2>/dev/null || true)

if [ "$SERVICE_STATUS" = "ACTIVE" ]; then

  TASKDEF_ARN=$(aws ecs describe-services \
    --cluster "$CLUSTER" \
    --services "$SERVICE" \
    --region "$REGION" \
    --query "services[0].taskDefinition" \
    --output text)

  echo "Reusing Task Definition: $TASKDEF_ARN"

else

  IMAGE="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/demoapp:latest"

  cat > initial-taskdef.json <<EOF
{
  "family": "demoapp",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "arn:aws:iam::$ACCOUNT_ID:role/PipelineRole",
  "containerDefinitions": [
    {
      "name": "demoapp",
      "image": "$IMAGE",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 3000,
          "protocol": "tcp"
        }
      ]
    }
  ]
}
EOF

  TASKDEF_ARN=$(aws ecs register-task-definition \
    --cli-input-json file://initial-taskdef.json \
    --region "$REGION" \
    --query "taskDefinition.taskDefinitionArn" \
    --output text)

  echo "Task Definition: $TASKDEF_ARN"
fi

# --------------------------------------------------
# 12. Ensure ECS Service
# --------------------------------------------------

if [ "$SERVICE_STATUS" != "ACTIVE" ]; then

  echo "Creating ECS Service: $SERVICE"

  aws ecs create-service \
    --cluster "$CLUSTER" \
    --service-name "$SERVICE" \
    --task-definition "$TASKDEF_ARN" \
    --desired-count 1 \
    --launch-type FARGATE \
    --deployment-controller type=CODE_DEPLOY \
    --network-configuration \
      "awsvpcConfiguration={subnets=[$SUBNET1,$SUBNET2],securityGroups=[$SG_ID],assignPublicIp=ENABLED}" \
    --load-balancers \
      "targetGroupArn=$TG1,containerName=demoapp,containerPort=3000" \
    --region "$REGION" >/dev/null

else
  echo "ECS Service already exists. Reusing."
fi

# --------------------------------------------------
# 13. Results
# --------------------------------------------------

ALB_DNS=$(aws elbv2 describe-load-balancers \
  --load-balancer-arns "$ALB_ARN" \
  --region "$REGION" \
  --query "LoadBalancers[0].DNSName" \
  --output text)

echo ""
echo "=========================================="
echo " Infrastructure ready!"
echo "=========================================="
echo ""
echo "VPC:             $VPC_ID"
echo "Cluster:         $CLUSTER"
echo "Service:         $SERVICE"
echo "Security Group:  $SG_ID"
echo "Task Definition: $TASKDEF_ARN"
echo "Target Group 1:  $TG1"
echo "Target Group 2:  $TG2"
echo ""
echo "Production URL:"
echo "http://$ALB_DNS"
echo ""
echo "Test URL:"
echo "http://$ALB_DNS:8080"
echo ""
echo "This setup script can be run again safely."
