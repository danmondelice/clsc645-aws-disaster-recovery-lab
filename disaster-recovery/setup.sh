#!/bin/bash

# 3-Step WordPress Disaster Recovery Lab - Setup Script
# This script creates an S3 bucket for disaster recovery

# Set error handling
set -e

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Print header
echo -e "${YELLOW}=========================================${NC}"
echo -e "${YELLOW}WordPress Disaster Recovery - Setup${NC}"
echo -e "${YELLOW}=========================================${NC}"
echo

# Configuration
REGION="us-east-1"
BUCKET_NAME="wp-disaster-recovery-$(date +%Y%m%d)-$(openssl rand -hex 4)"
TIMESTAMP=$(date +"%Y-%m-%d-%H-%M-%S")

# Save configuration for other scripts
CONFIG_FILE="dr_config.txt"

echo "Creating configuration file..."
echo "REGION=$REGION" > $CONFIG_FILE
echo "BUCKET_NAME=$BUCKET_NAME" >> $CONFIG_FILE
echo "SETUP_TIMESTAMP=$TIMESTAMP" >> $CONFIG_FILE
echo -e "${GREEN}Configuration saved to $CONFIG_FILE${NC}"
echo

# Create S3 bucket
echo "Creating S3 bucket for disaster recovery..."
# For us-east-1, we don't specify a LocationConstraint
if [ "$REGION" = "us-east-1" ]; then
    aws s3api create-bucket \
        --bucket $BUCKET_NAME \
        --region $REGION
else
    aws s3api create-bucket \
        --bucket $BUCKET_NAME \
        --region $REGION \
        --create-bucket-configuration LocationConstraint=$REGION
fi

# Verify bucket creation
echo "Verifying S3 bucket creation..."
if aws s3api head-bucket --bucket $BUCKET_NAME 2>/dev/null; then
    echo -e "${GREEN}S3 bucket $BUCKET_NAME created successfully!${NC}"
else
    echo -e "${RED}Failed to create S3 bucket $BUCKET_NAME${NC}"
    exit 1
fi

# Create directories in S3 bucket
echo "Creating directories in S3 bucket..."
touch empty.txt
aws s3 cp empty.txt s3://$BUCKET_NAME/backups/empty.txt
aws s3 cp empty.txt s3://$BUCKET_NAME/scripts/empty.txt
aws s3 cp empty.txt s3://$BUCKET_NAME/config/empty.txt
rm empty.txt

# Upload scripts to S3 bucket
echo "Uploading scripts to S3 bucket..."
aws s3 cp backup.sh s3://$BUCKET_NAME/scripts/
aws s3 cp recover.sh s3://$BUCKET_NAME/scripts/
aws s3 cp simulate_disaster.sh s3://$BUCKET_NAME/scripts/
aws s3 cp $CONFIG_FILE s3://$BUCKET_NAME/config/

# Install jq if not already installed
if ! command -v jq &> /dev/null; then
    echo "jq is required for JSON processing. Attempting to install..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y jq
    elif command -v yum &> /dev/null; then
        sudo yum install -y jq
    elif command -v brew &> /dev/null; then
        brew install jq
    else
        echo -e "${YELLOW}Could not automatically install jq. Please install it manually.${NC}"
    fi
fi

# Verify jq installation
if command -v jq &> /dev/null; then
    echo -e "${GREEN}jq is installed and ready for JSON processing.${NC}"
else
    echo -e "${YELLOW}Warning: jq is not installed. Some scripts may not work correctly.${NC}"
fi

echo
echo -e "${GREEN}Setup completed successfully!${NC}"
echo -e "${GREEN}S3 bucket $BUCKET_NAME is ready for disaster recovery.${NC}"
echo
echo -e "${YELLOW}Next step: Run bash ./backup.sh to create a backup of the ELB configuration.${NC}"
echo -e "${YELLOW}=========================================${NC}"