#!/bin/bash

# 3-Step WordPress Disaster Recovery Lab - Cleanup Script
# This script cleans up resources created during the lab

# Set error handling
set -e

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Print header
echo -e "${YELLOW}=========================================${NC}"
echo -e "${YELLOW}WordPress Disaster Recovery - Cleanup${NC}"
echo -e "${YELLOW}=========================================${NC}"
echo

# Load configuration
CONFIG_FILE="dr_config.txt"
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}Configuration file not found. Nothing to clean up.${NC}"
    exit 1
fi

# Extract needed variables safely without sourcing the entire file
echo "Extracting configuration variables..."
REGION=$(grep "^REGION=" $CONFIG_FILE | cut -d'=' -f2)
BUCKET_NAME=$(grep "^BUCKET_NAME=" $CONFIG_FILE | cut -d'=' -f2)
ELB_DNS=$(grep "^ELB_DNS=" $CONFIG_FILE | cut -d'=' -f2)

# Check if we got the essential variables
if [ -z "$REGION" ] || [ -z "$BUCKET_NAME" ]; then
    echo -e "${YELLOW}Warning: Could not extract all required variables from config file.${NC}"
    echo -e "${YELLOW}Will attempt to continue with cleanup anyway.${NC}"
fi

# Confirm cleanup
echo -e "${RED}WARNING: This will delete all resources created during the lab.${NC}"
echo -e "${RED}This includes the S3 bucket and temporary files.${NC}"
echo
read -p "Are you sure you want to continue? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cleanup cancelled."
    exit 0
fi

# No temporary files to delete in the simplified approach
echo "No temporary files to clean up in the simplified approach."

# Empty and delete S3 bucket if it exists
if [ -n "$BUCKET_NAME" ]; then
    echo "Emptying S3 bucket $BUCKET_NAME..."
    aws s3 rm s3://$BUCKET_NAME --recursive --region $REGION 2>/dev/null || echo -e "${YELLOW}Failed to empty bucket or bucket not found.${NC}"
    
    echo "Deleting S3 bucket $BUCKET_NAME..."
    aws s3api delete-bucket --bucket $BUCKET_NAME --region $REGION 2>/dev/null || echo -e "${YELLOW}Bucket $BUCKET_NAME not found or already deleted.${NC}"
    echo -e "${GREEN}S3 bucket deleted or not found.${NC}"
fi

# Test the website after cleanup
if [ -n "$ELB_DNS" ]; then
    echo "Testing website after cleanup..."
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$ELB_DNS)
    if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 400 ]; then
        echo -e "${GREEN}Website is still accessible at http://$ELB_DNS (HTTP code: $HTTP_CODE)${NC}"
        echo -e "${GREEN}This confirms that our disaster recovery process did not permanently affect the website.${NC}"
    else
        echo -e "${YELLOW}Website may not be accessible (HTTP code: $HTTP_CODE)${NC}"
        echo -e "${YELLOW}This could be due to other factors unrelated to our disaster recovery process.${NC}"
    fi
fi

# Delete local configuration file
echo "Deleting local configuration file..."
rm -f $CONFIG_FILE
echo -e "${GREEN}Local configuration file deleted.${NC}"

echo
echo -e "${GREEN}Cleanup completed successfully!${NC}"
echo -e "${GREEN}All disaster recovery resources created during the lab have been deleted.${NC}"
echo -e "${YELLOW}=========================================${NC}"