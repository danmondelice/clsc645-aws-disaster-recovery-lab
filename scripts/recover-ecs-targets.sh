#!/usr/bin/env bash
# Companion to preserved instructor scripts: only registers this service's running task IPs.
set -euo pipefail
export AWS_PAGER=""
if [[ $# -ne 5 ]]; then
  echo "Usage: $0 REGION CLUSTER SERVICE TARGET_GROUP_ARN EXPECTED_ACCOUNT_ID" >&2
  exit 2
fi
region=$1; cluster=$2; service=$3; target_group=$4; expected_account=$5
[[ $region == us-east-1 || $region == us-west-2 ]] || exit 2
[[ $(aws sts get-caller-identity --query Account --output text) == "$expected_account" ]] || { echo 'Wrong AWS account' >&2; exit 1; }
[[ $target_group == arn:aws:elasticloadbalancing:"$region":"$expected_account":targetgroup/* ]] || exit 2
service_json=$(aws ecs describe-services --region "$region" --cluster "$cluster" --services "$service")
jq -e --arg tg "$target_group" '.failures | length == 0' <<< "$service_json" >/dev/null
jq -e --arg tg "$target_group" '.services[0].loadBalancers[] | select(.targetGroupArn == $tg and .containerName == "wordpress" and .containerPort == 80)' <<< "$service_json" >/dev/null
[[ $(aws elbv2 describe-target-groups --region "$region" --target-group-arns "$target_group" --query 'TargetGroups[0].TargetType' --output text) == ip ]] || exit 1
tasks_json=$(aws ecs list-tasks --region "$region" --cluster "$cluster" --service-name "$service" --desired-status RUNNING)
# Process one ARN at a time so no unquoted array expansion can select other services.
found=0
while IFS= read -r task; do
  [[ -n $task ]] || continue
  task_json=$(aws ecs describe-tasks --region "$region" --cluster "$cluster" --tasks "$task")
  while IFS= read -r ip; do
    [[ -n $ip ]] || continue
    aws elbv2 register-targets --region "$region" --target-group-arn "$target_group" --targets "Id=$ip,Port=80"
    found=$((found + 1))
  done < <(jq -r --arg group "service:$service" '.tasks[] | select(.lastStatus == "RUNNING" and .group == $group) | .containers[] | select(.name == "wordpress") | .networkInterfaces[]?.privateIpv4Address' <<< "$task_json")
done < <(jq -r '.taskArns[]' <<< "$tasks_json")
[[ $found -gt 0 ]] || { echo 'No running WordPress task IPs found; inspect ECS service events.' >&2; exit 1; }
aws elbv2 wait target-in-service --region "$region" --target-group-arn "$target_group"
echo 'Targets registered and healthy. Verify site content and login separately.'
