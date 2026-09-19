#!/bin/bash

# 3-Step WordPress Disaster Recovery Lab - Backup Script
# This script backs up the ELB configuration for WordPress (SIMPLIFIED VERSION)

# Set error handling
set -e

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Print header
echo -e "${YELLOW}=========================================${NC}"
echo -e "${YELLOW}WordPress Disaster Recovery - Backup${NC}"
echo -e "${YELLOW}=========================================${NC}"
echo

# Load configuration
CONFIG_FILE="dr_config.txt"
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}Configuration file not found. Please run setup.sh first.${NC}"
    exit 1
fi

source $CONFIG_FILE

# Timestamp for backup
TIMESTAMP=$(date +"%Y-%m-%d-%H-%M-%S")

# Find load balancers
echo "Finding load balancers..."
LOAD_BALANCERS=$(aws elbv2 describe-load-balancers \
    --region $REGION \
    --query "LoadBalancers[].LoadBalancerArn" \
    --output text)

# Check if any load balancers were found
if [ -z "$LOAD_BALANCERS" ]; then
    echo -e "${RED}No load balancers found. Please check your AWS environment.${NC}"
    exit 1
fi

# List available load balancers for selection
echo "Available load balancers:"
IFS=$' \t\n'
LB_ARRAY=($LOAD_BALANCERS)
for i in "${!LB_ARRAY[@]}"; do
    # Extract load balancer name from ARN
    LB_NAME=$(aws elbv2 describe-load-balancers \
        --region $REGION \
        --load-balancer-arns ${LB_ARRAY[$i]} \
        --query "LoadBalancers[0].LoadBalancerName" \
        --output text)
    echo "  $((i+1)). $LB_NAME"
done

# Ask user to select a load balancer
echo
echo -n "Enter the number of the WordPress load balancer to back up: "
read SELECTION

# Validate selection
if [[ ! $SELECTION =~ ^[0-9]+$ ]] || [ $SELECTION -lt 1 ] || [ $SELECTION -gt ${#LB_ARRAY[@]} ]; then
    echo -e "${RED}Invalid selection. Please run the script again.${NC}"
    exit 1
fi

# Get the selected load balancer
ELB_ARN=${LB_ARRAY[$((SELECTION-1))]}
ELB_NAME=$(aws elbv2 describe-load-balancers \
    --region $REGION \
    --load-balancer-arns $ELB_ARN \
    --query "LoadBalancers[0].LoadBalancerName" \
    --output text)
echo "Using load balancer: $ELB_NAME"

# Get the DNS name of the load balancer
ELB_DNS=$(aws elbv2 describe-load-balancers \
    --region $REGION \
    --load-balancer-arns $ELB_ARN \
    --query "LoadBalancers[0].DNSName" \
    --output text)
echo "Load balancer DNS: $ELB_DNS"

# Get target groups attached to the load balancer
TARGET_GROUPS=$(aws elbv2 describe-target-groups \
    --region $REGION \
    --load-balancer-arn $ELB_ARN \
    --query "TargetGroups[].TargetGroupArn" \
    --output text)

# Check if any target groups were found
if [ -z "$TARGET_GROUPS" ]; then
    echo -e "${RED}No target groups found for the selected load balancer.${NC}"
    exit 1
fi

# Save target group information directly to config file
echo "ELB_ARN=$ELB_ARN" >> $CONFIG_FILE
echo "ELB_NAME=$ELB_NAME" >> $CONFIG_FILE
echo "ELB_DNS=$ELB_DNS" >> $CONFIG_FILE
echo "TARGET_GROUPS=$TARGET_GROUPS" >> $CONFIG_FILE
echo "BACKUP_TIMESTAMP=$TIMESTAMP" >> $CONFIG_FILE

# Count the number of target groups
TG_COUNT=$(echo "$TARGET_GROUPS" | wc -w)
echo "Found $TG_COUNT target group(s) attached to the load balancer."

# Verify target groups have targets
IFS=$' \t\n'
TG_ARRAY=($TARGET_GROUPS)
for TG_ARN in "${TG_ARRAY[@]}"; do
    # Get target group name
    TG_NAME=$(aws elbv2 describe-target-groups \
        --region $REGION \
        --target-group-arns $TG_ARN \
        --query "TargetGroups[0].TargetGroupName" \
        --output text)
    
    # Count targets
    TARGET_COUNT=$(aws elbv2 describe-target-health \
        --region $REGION \
        --target-group-arn $TG_ARN \
        --query "length(TargetHealthDescriptions)" \
        --output text)
    
    echo "Target group $TG_NAME has $TARGET_COUNT registered target(s)."
done

# Test the website URL quickly
echo "Testing website URL..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -m 5 http://$ELB_DNS)
if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 400 ]; then
    echo -e "${GREEN}Website is accessible at http://$ELB_DNS (HTTP code: $HTTP_CODE)${NC}"
else
    echo -e "${YELLOW}Website may not be accessible at http://$ELB_DNS (HTTP code: $HTTP_CODE)${NC}"
fi

echo
echo -e "${GREEN}Backup completed successfully!${NC}"
echo -e "${GREEN}ELB configuration is ready for disaster recovery.${NC}"
echo
echo -e "${YELLOW}Next step: Run bash ./simulate_disaster.sh to simulate a disaster.${NC}"
echo -e "${YELLOW}=========================================${NC}"