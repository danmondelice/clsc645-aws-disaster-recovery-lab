#!/bin/bash

# 3-Step WordPress Disaster Recovery Lab - Simulate Disaster Script
# This script simulates a disaster by deregistering targets from the ELB

# Set error handling
set -e

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Print header
echo -e "${YELLOW}=========================================${NC}"
echo -e "${YELLOW}WordPress Disaster Recovery - Simulate Disaster${NC}"
echo -e "${YELLOW}=========================================${NC}"
echo

# Load configuration
CONFIG_FILE="dr_config.txt"
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}Configuration file not found. Please run setup.sh and backup.sh first.${NC}"
    exit 1
fi

# Extract needed variables safely without sourcing the entire file
echo "Extracting configuration variables..."
REGION=$(grep "^REGION=" $CONFIG_FILE | cut -d'=' -f2)
ELB_ARN=$(grep "^ELB_ARN=" $CONFIG_FILE | cut -d'=' -f2)
ELB_DNS=$(grep "^ELB_DNS=" $CONFIG_FILE | cut -d'=' -f2)
TARGET_GROUPS=$(grep "^TARGET_GROUPS=" $CONFIG_FILE | cut -d'=' -f2)
BUCKET_NAME=$(grep "^BUCKET_NAME=" $CONFIG_FILE | cut -d'=' -f2)

# Check if backup was created
if [ -z "$ELB_ARN" ] || [ -z "$TARGET_GROUPS" ]; then
    echo -e "${RED}Backup information not found. Please run backup.sh first.${NC}"
    exit 1
fi

# Confirm disaster simulation
echo -e "${RED}WARNING: This will simulate a disaster by deregistering targets from the load balancer.${NC}"
echo -e "${RED}The WordPress website will become unavailable.${NC}"
echo
read -p "Are you sure you want to continue? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Disaster simulation cancelled."
    exit 0
fi

# Timestamp for disaster
DISASTER_TIMESTAMP=$(date +"%Y-%m-%d-%H-%M-%S")
echo "DISASTER_TIMESTAMP=$DISASTER_TIMESTAMP" >> $CONFIG_FILE

# Test the website before disaster
echo "Testing website before disaster..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$ELB_DNS)
if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 400 ]; then
    echo -e "${GREEN}Website is accessible at http://$ELB_DNS (HTTP code: $HTTP_CODE)${NC}"
else
    echo -e "${YELLOW}Website may not be accessible at http://$ELB_DNS (HTTP code: $HTTP_CODE)${NC}"
    echo -e "${YELLOW}Continuing with disaster simulation anyway...${NC}"
fi

# Deregister targets from all target groups
echo "Deregistering targets from load balancer target groups..."
IFS=$' \t\n'
TG_ARRAY=($TARGET_GROUPS)
for TG_ARN in "${TG_ARRAY[@]}"; do
    # Get target group name
    TG_NAME=$(aws elbv2 describe-target-groups \
        --region $REGION \
        --target-group-arns $TG_ARN \
        --query "TargetGroups[0].TargetGroupName" \
        --output text)
    
    echo "Processing target group: $TG_NAME"
    
    # Get target IDs directly from AWS instead of config file
    echo "Getting current targets for $TG_NAME..."
    TARGET_IDS=$(aws elbv2 describe-target-health \
        --region $REGION \
        --target-group-arn $TG_ARN \
        --query "TargetHealthDescriptions[].Target.Id" \
        --output text)
    
    # Check if there are any targets
    if [ -z "$TARGET_IDS" ]; then
        echo "No targets found in target group $TG_NAME"
        continue
    fi
    
    # Deregister each target
    for TARGET_ID in $TARGET_IDS; do
        echo "Deregistering target $TARGET_ID from target group $TG_NAME"
        aws elbv2 deregister-targets \
            --region $REGION \
            --target-group-arn $TG_ARN \
            --targets Id=$TARGET_ID
    done
    
    echo -e "${GREEN}All targets deregistered from target group $TG_NAME${NC}"
done

# Wait for targets to be deregistered
echo "Waiting for targets to be fully deregistered (this may take a minute)..."
sleep 30

# Test the website after disaster
echo "Testing website after disaster..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$ELB_DNS)
if [ "$HTTP_CODE" -ge 400 ] || [ "$HTTP_CODE" -eq 0 ]; then
    echo -e "${GREEN}Disaster simulation successful! Website is down (HTTP code: $HTTP_CODE)${NC}"
else
    echo -e "${YELLOW}Warning: Website may still be accessible (HTTP code: $HTTP_CODE)${NC}"
    echo -e "${YELLOW}This could be due to caching or other factors.${NC}"
fi

# Upload updated configuration to S3
aws s3 cp $CONFIG_FILE s3://$BUCKET_NAME/config/

echo
echo -e "${GREEN}Disaster simulation completed!${NC}"
echo -e "${RED}WordPress website has been made unavailable to simulate a disaster.${NC}"
echo
echo -e "${YELLOW}Next step: Run bash ./recover.sh to recover WordPress from backup.${NC}"
echo -e "${YELLOW}=========================================${NC}"