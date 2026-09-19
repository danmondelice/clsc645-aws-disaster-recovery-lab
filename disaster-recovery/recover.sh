#!/bin/bash

# 3-Step WordPress Disaster Recovery Lab - Recovery Script
# This script recovers WordPress by re-registering targets to the ELB

# Set error handling
set -e

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Print header
echo -e "${YELLOW}=========================================${NC}"
echo -e "${YELLOW}WordPress Disaster Recovery - Recovery${NC}"
echo -e "${YELLOW}=========================================${NC}"
echo

# Load configuration
CONFIG_FILE="dr_config.txt"
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}Configuration file not found. Please run setup.sh, backup.sh, and simulate_disaster.sh first.${NC}"
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

# Timestamp for recovery
RECOVERY_TIMESTAMP=$(date +"%Y-%m-%d-%H-%M-%S")
echo "RECOVERY_TIMESTAMP=$RECOVERY_TIMESTAMP" >> $CONFIG_FILE

# Test the website before recovery
echo "Testing website before recovery..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$ELB_DNS)
if [ "$HTTP_CODE" -ge 400 ] || [ "$HTTP_CODE" -eq 0 ]; then
    echo -e "${YELLOW}Website is currently down (HTTP code: $HTTP_CODE)${NC}"
else
    echo -e "${YELLOW}Warning: Website appears to be accessible (HTTP code: $HTTP_CODE)${NC}"
    echo -e "${YELLOW}Continuing with recovery anyway...${NC}"
fi

# Re-register targets to all target groups
echo "Re-registering targets to load balancer target groups..."
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
    
    # Try to get the original targets that were registered before the disaster
    echo "Attempting to find original targets for $TG_NAME..."
    
    # First, try to get targets from the target group directly
    # This might work if some targets are still registered
    CURRENT_TARGETS=$(aws elbv2 describe-target-health \
        --region $REGION \
        --target-group-arn $TG_ARN \
        --query "TargetHealthDescriptions[].Target.Id" \
        --output text)
    
    if [ -n "$CURRENT_TARGETS" ]; then
        echo "Found existing targets in the target group."
        TARGET_IDS="$CURRENT_TARGETS"
    else
        # If no targets found, look for EC2 instances with specific tags
        # that might indicate they're WordPress instances
        echo "Looking for EC2 instances with WordPress-related tags..."
        EC2_INSTANCES=$(aws ec2 describe-instances \
            --region $REGION \
            --filters "Name=instance-state-name,Values=running" \
                     "Name=tag:Name,Values=*wordpress*,*web*,*app*" \
            --query "Reservations[].Instances[].InstanceId" \
            --output text)
        
        if [ -n "$EC2_INSTANCES" ]; then
            echo "Found EC2 instances with WordPress-related tags."
            TARGET_IDS="$EC2_INSTANCES"
        else
            # As a last resort, try to find any running EC2 instances
            echo "Looking for any running EC2 instances..."
            EC2_INSTANCES=$(aws ec2 describe-instances \
                --region $REGION \
                --filters "Name=instance-state-name,Values=running" \
                --query "Reservations[].Instances[].InstanceId" \
                --output text)
            
            if [ -n "$EC2_INSTANCES" ]; then
                echo "Found running EC2 instances."
                TARGET_IDS="$EC2_INSTANCES"
            else
                # If still no targets, try to find the subnet IDs associated with the target group
                echo "No EC2 instances found. Looking for specific IP addresses..."
                
                # Get the VPC ID from the target group
                VPC_ID=$(aws elbv2 describe-target-groups \
                    --region $REGION \
                    --target-group-arns $TG_ARN \
                    --query "TargetGroups[0].VpcId" \
                    --output text)
                
                # Get subnet IDs for the target group (these are likely the app subnets)
                SUBNET_IDS=$(aws elbv2 describe-load-balancers \
                    --region $REGION \
                    --load-balancer-arns $ELB_ARN \
                    --query "LoadBalancers[0].AvailabilityZones[].SubnetId" \
                    --output text)
                
                # Get private IPs from EC2 instances in these subnets
                # Exclude IPs used by the load balancer
                for SUBNET_ID in $SUBNET_IDS; do
                    echo "Checking subnet $SUBNET_ID for potential targets..."
                    
                    # Get IPs from network interfaces in this subnet
                    # Exclude those attached to the load balancer
                    SUBNET_IPS=$(aws ec2 describe-network-interfaces \
                        --region $REGION \
                        --filters "Name=subnet-id,Values=$SUBNET_ID" \
                                 "Name=description,Values=*" \
                                 "Name=status,Values=in-use" \
                        --query "NetworkInterfaces[?!contains(Description, 'ELB')].PrivateIpAddress" \
                        --output text)
                    
                    if [ -n "$SUBNET_IPS" ]; then
                        echo "Found potential target IPs in subnet $SUBNET_ID"
                        if [ -z "$TARGET_IDS" ]; then
                            TARGET_IDS="$SUBNET_IPS"
                        else
                            TARGET_IDS="$TARGET_IDS $SUBNET_IPS"
                        fi
                    fi
                done
            fi
        fi
    fi
    
    # Check if there are any targets
    if [ -z "$TARGET_IDS" ]; then
        echo -e "${YELLOW}No targets found to register with target group $TG_NAME${NC}"
        continue
    fi
    
    # Convert to array
    IFS=$' \t\n' read -r -a ID_ARRAY <<< "$TARGET_IDS"
    
    # Get the target group port
    TARGET_GROUP_PORT=$(aws elbv2 describe-target-groups \
        --region $REGION \
        --target-group-arns $TG_ARN \
        --query "TargetGroups[0].Port" \
        --output text)
    
    # If port is not available, use default port 80
    if [ -z "$TARGET_GROUP_PORT" ]; then
        TARGET_GROUP_PORT=80
    fi
    
    # Register each target with error handling
    REGISTERED_COUNT=0
    for TARGET_ID in "${ID_ARRAY[@]}"; do
        echo "Attempting to register target $TARGET_ID with port $TARGET_GROUP_PORT to target group $TG_NAME"
        
        # Register the target with error handling
        if aws elbv2 register-targets \
            --region $REGION \
            --target-group-arn $TG_ARN \
            --targets Id=$TARGET_ID,Port=$TARGET_GROUP_PORT 2>/dev/null; then
            
            echo -e "${GREEN}Successfully registered target $TARGET_ID${NC}"
            REGISTERED_COUNT=$((REGISTERED_COUNT+1))
        else
            echo -e "${YELLOW}Failed to register target $TARGET_ID - it may already be registered or unavailable${NC}"
        fi
    done
    
    # Check if we registered any targets
    if [ $REGISTERED_COUNT -gt 0 ]; then
        echo -e "${GREEN}Successfully registered $REGISTERED_COUNT target(s) to target group $TG_NAME${NC}"
    else
        echo -e "${YELLOW}Warning: Failed to register any targets to target group $TG_NAME${NC}"
    fi
done

# Wait for targets to be registered and healthy
echo "Waiting for targets to be registered and healthy (this may take a minute)..."
sleep 30

# Test the website after recovery
echo "Testing website after recovery..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$ELB_DNS)
if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 400 ]; then
    echo -e "${GREEN}Recovery successful! Website is accessible at http://$ELB_DNS (HTTP code: $HTTP_CODE)${NC}"
else
    echo -e "${YELLOW}Warning: Website may still be down (HTTP code: $HTTP_CODE)${NC}"
    echo -e "${YELLOW}It may take a few more minutes for the targets to become healthy.${NC}"
fi

# Upload updated configuration to S3
aws s3 cp $CONFIG_FILE s3://$BUCKET_NAME/config/

# Provide verification instructions
echo
echo -e "${YELLOW}Verification Instructions:${NC}"
echo "1. Wait a few minutes for all targets to become healthy"
echo "2. Access your WordPress site at http://$ELB_DNS"
echo "3. Verify all content is present and accessible"
echo "4. Verify you can log in to the WordPress admin panel"

echo
echo -e "${GREEN}Recovery completed successfully!${NC}"
echo -e "${GREEN}WordPress website has been restored by re-registering targets to the load balancer.${NC}"
echo
echo -e "${YELLOW}Final step: Verify WordPress is functioning correctly.${NC}"
echo -e "${YELLOW}When you're done, run 'bash ./cleanup.sh' to clean up resources.${NC}"
echo -e "${YELLOW}=========================================${NC}"