#!/bin/bash
set -e

REGION="us-east-1"
CLUSTER="demo-cluster"
SERVICE="demoapp-service"
APP="demoapp"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "=== DemoApp ECS Blue/Green Infrastructure Setup ==="
echo "Account: $ACCOUNT_ID"

# --------------------------------------------------
# 1. Find VPC and two subnets
# --------------------------------------------------

VPC_ID=$(aws ec2 describe-vpcs \
  --region $REGION \
  --query "Vpcs[0].VpcId" \
  --output text)

SUBNETS=($(aws ec2 describe-subnets \
  --region $REGION \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query "Subnets[].SubnetId" \
  --output text))

SUBNET1=${SUBNETS[0]}
SUBNET2=${SUBNETS[1]}

echo "VPC: $VPC_ID"
echo "Subnet 1: $SUBNET1"
echo "Subnet 2: $SUBNET2"

# --------------------------------------------------
# 2. Create ECS cluster if necessary
# --------------------------------------------------

aws ecs describe-clusters \
  --clusters $CLUSTER \
  --region $REGION \
  --query "clusters[?status=='ACTIVE'].clusterName" \
  --output text | grep -q "$CLUSTER" || \
aws ecs create-cluster \
  --cluster-name $CLUSTER \
  --region $REGION > /dev/null

# --------------------------------------------------
# 3. Create Security Group
# --------------------------------------------------

SG_ID=$(aws ec2 describe-security-groups \
  --region $REGION \
  --filters \
    "Name=vpc-id,Values=$VPC_ID" \
    "Name=group-name,Values=demoapp-sg" \
  --query "SecurityGroups[0].GroupId" \
  --output text)

if [ "$SG_ID" = "None" ]; then
  SG_ID=$(aws ec2 create-security-group \
    --group-name demoapp-sg \
    --description "Security group for DemoApp Blue Green deployment" \
    --vpc-id $VPC_ID \
    --region $REGION \
    --query GroupId \
    --output text)

  aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0 \
    --region $REGION

  aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp \
    --port 8080 \
    --cidr 0.0.0.0/0 \
    --region $REGION

  aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp \
    --port 3000 \
    --cidr 0.0.0.0/0 \
    --region $REGION
fi

echo "Security Group: $SG_ID"

# --------------------------------------------------
# 4. Create two Target Groups
# --------------------------------------------------

TG1=$(aws elbv2 describe-target-groups \
  --names demoapp-tg-1 \
  --region $REGION \
  --query "TargetGroups[0].TargetGroupArn" \
  --output text 2>/dev/null || true)

if [ -z "$TG1" ] || [ "$TG1" = "None" ]; then
  TG1=$(aws elbv2 create-target-group \
    --name demoapp-tg-1 \
    --protocol HTTP \
    --port 3000 \
    --vpc-id $VPC_ID \
    --target-type ip \
    --health-check-path / \
    --region $REGION \
    --query "TargetGroups[0].TargetGroupArn" \
    --output text)
fi

echo "Target Group 1 ready"

TG2=$(aws elbv2 describe-target-groups \
  --names demoapp-tg-2 \
  --region $REGION \
  --query "TargetGroups[0].TargetGroupArn" \
  --output text 2>/dev/null || true)

if [ -z "$TG2" ] || [ "$TG2" = "None" ]; then
  TG2=$(aws elbv2 create-target-group \
    --name demoapp-tg-2 \
    --protocol HTTP \
    --port 3000 \
    --vpc-id $VPC_ID \
    --target-type ip \
    --health-check-path / \
    --region $REGION \
    --query "TargetGroups[0].TargetGroupArn" \
    --output text)
fi

echo "Target Group 2 ready"

# --------------------------------------------------
# 5. Create Application Load Balancer
# --------------------------------------------------

ALB_ARN=$(aws elbv2 describe-load-balancers \
  --names demoapp-alb \
  --region $REGION \
  --query "LoadBalancers[0].LoadBalancerArn" \
  --output text 2>/dev/null || true)

if [ -z "$ALB_ARN" ] || [ "$ALB_ARN" = "None" ]; then
  ALB_ARN=$(aws elbv2 create-load-balancer \
    --name demoapp-alb \
    --type application \
    --scheme internet-facing \
    --security-groups $SG_ID \
    --subnets $SUBNET1 $SUBNET2 \
    --region $REGION \
    --query "LoadBalancers[0].LoadBalancerArn" \
    --output text)
fi

echo "Waiting for ALB..."

aws elbv2 wait load-balancer-available \
  --load-balancer-arns $ALB_ARN \
  --region $REGION

echo "ALB ready"

# --------------------------------------------------
# 6. Create Production and Test listeners
# --------------------------------------------------

PROD_LISTENER=$(aws elbv2 describe-listeners \
  --load-balancer-arn $ALB_ARN \
  --region $REGION \
  --query "Listeners[?Port==\`80\`].ListenerArn" \
  --output text)

if [ -z "$PROD_LISTENER" ]; then
  PROD_LISTENER=$(aws elbv2 create-listener \
    --load-balancer-arn $ALB_ARN \
    --protocol HTTP \
    --port 80 \
    --default-actions Type=forward,TargetGroupArn=$TG1 \
    --region $REGION \
    --query "Listeners[0].ListenerArn" \
    --output text)
fi

TEST_LISTENER=$(aws elbv2 describe-listeners \
  --load-balancer-arn $ALB_ARN \
  --region $REGION \
  --query "Listeners[?Port==\`8080\`].ListenerArn" \
  --output text)

if [ -z "$TEST_LISTENER" ]; then
  TEST_LISTENER=$(aws elbv2 create-listener \
    --load-balancer-arn $ALB_ARN \
    --protocol HTTP \
    --port 8080 \
    --default-actions Type=forward,TargetGroupArn=$TG2 \
    --region $REGION \
    --query "Listeners[0].ListenerArn" \
    --output text)
fi

echo "Listeners ready"

# --------------------------------------------------
# 7. Register initial ECS Task Definition
# --------------------------------------------------

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
  --region $REGION \
  --query "taskDefinition.taskDefinitionArn" \
  --output text)

echo "Task Definition: $TASKDEF_ARN"

# --------------------------------------------------
# 8. Create ECS Service
# --------------------------------------------------

SERVICE_EXISTS=$(aws ecs describe-services \
  --cluster $CLUSTER \
  --services $SERVICE \
  --region $REGION \
  --query "services[0].status" \
  --output text)

if [ "$SERVICE_EXISTS" != "ACTIVE" ]; then

  aws ecs create-service \
    --cluster $CLUSTER \
    --service-name $SERVICE \
    --task-definition $TASKDEF_ARN \
    --desired-count 1 \
    --launch-type FARGATE \
    --deployment-controller type=CODE_DEPLOY \
    --network-configuration \
      "awsvpcConfiguration={subnets=[$SUBNET1,$SUBNET2],securityGroups=[$SG_ID],assignPublicIp=ENABLED}" \
    --load-balancers \
      "targetGroupArn=$TG1,containerName=demoapp,containerPort=3000" \
    --region $REGION > /dev/null
fi

# --------------------------------------------------
# 9. Display results
# --------------------------------------------------

ALB_DNS=$(aws elbv2 describe-load-balancers \
  --load-balancer-arns $ALB_ARN \
  --region $REGION \
  --query "LoadBalancers[0].DNSName" \
  --output text)

echo ""
echo "=========================================="
echo "Infrastructure ready!"
echo "=========================================="
echo ""
echo "Cluster:         $CLUSTER"
echo "Service:         $SERVICE"
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
echo "Wait 1-2 minutes for the ECS task to become healthy."
