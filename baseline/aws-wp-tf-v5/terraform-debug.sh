#!/bin/bash
# Terraform Troubleshooting Script
# This script collects environment information, Terraform logs, and AWS configuration
# to help diagnose issues with Terraform deployments.
#
# Usage: ./terraform-debug.sh [optional-output-filename]

# Set output file name
if [ -z "$1" ]; then
  OUTPUT_FILE="terraform-debug-info-$(date +%Y%m%d-%H%M%S).txt"
else
  OUTPUT_FILE="$1"
fi

echo "Collecting debug information to $OUTPUT_FILE..."

# Create output file and add header
cat > "$OUTPUT_FILE" << EOL
==========================================================
TERRAFORM TROUBLESHOOTING REPORT
Generated: $(date)
==========================================================

EOL

# Function to add section headers
add_section() {
  echo "" >> "$OUTPUT_FILE"
  echo "===========================================================" >> "$OUTPUT_FILE"
  echo "= $1" >> "$OUTPUT_FILE"
  echo "===========================================================" >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
}

# System Information
add_section "SYSTEM INFORMATION"
echo "Hostname: $(hostname)" >> "$OUTPUT_FILE"
echo "Operating System: $(uname -a)" >> "$OUTPUT_FILE"
if [ -f /etc/os-release ]; then
  echo "OS Details: $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '"')" >> "$OUTPUT_FILE"
fi
echo "Current Directory: $(pwd)" >> "$OUTPUT_FILE"
echo "User: $(whoami)" >> "$OUTPUT_FILE"

# Environment Variables
add_section "ENVIRONMENT VARIABLES"
echo "PATH: $PATH" >> "$OUTPUT_FILE"
echo "HOME: $HOME" >> "$OUTPUT_FILE"
echo "SHELL: $SHELL" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "AWS-related environment variables (credentials redacted):" >> "$OUTPUT_FILE"
env | grep -i aws | sed 's/\(AWS_SECRET_ACCESS_KEY=\).*/\1[REDACTED]/g' | sed 's/\(AWS_SESSION_TOKEN=\).*/\1[REDACTED]/g' >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "Terraform-related environment variables:" >> "$OUTPUT_FILE"
env | grep -i terraform >> "$OUTPUT_FILE"

# Installed Software Versions
add_section "SOFTWARE VERSIONS"
echo "Terraform Version:" >> "$OUTPUT_FILE"
terraform version 2>&1 >> "$OUTPUT_FILE" || echo "Terraform not found or not in PATH" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "AWS CLI Version:" >> "$OUTPUT_FILE"
aws --version 2>&1 >> "$OUTPUT_FILE" || echo "AWS CLI not found or not in PATH" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "Git Version:" >> "$OUTPUT_FILE"
git --version 2>&1 >> "$OUTPUT_FILE" || echo "Git not found or not in PATH" >> "$OUTPUT_FILE"

# AWS Configuration (without credentials)
add_section "AWS CONFIGURATION"
echo "AWS Region:" >> "$OUTPUT_FILE"
aws configure get region 2>&1 >> "$OUTPUT_FILE" || echo "AWS CLI not configured" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "AWS Profile:" >> "$OUTPUT_FILE"
aws configure list 2>&1 | grep profile >> "$OUTPUT_FILE" || echo "No profile information available" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "AWS Identity (account number only):" >> "$OUTPUT_FILE"
aws sts get-caller-identity --query "Account" --output text 2>&1 >> "$OUTPUT_FILE" || echo "Unable to get AWS identity" >> "$OUTPUT_FILE"

# Terraform Files
add_section "TERRAFORM FILES"
echo "Terraform files in current directory:" >> "$OUTPUT_FILE"
find . -maxdepth 1 -name "*.tf" | sort >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "Terraform state files:" >> "$OUTPUT_FILE"
find . -maxdepth 1 -name "*.tfstate*" | sort >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "Terraform lock file exists: $([ -f .terraform.lock.hcl ] && echo 'Yes' || echo 'No')" >> "$OUTPUT_FILE"
echo "Terraform directory exists: $([ -d .terraform ] && echo 'Yes' || echo 'No')" >> "$OUTPUT_FILE"

# Terraform State
add_section "TERRAFORM STATE"
echo "Terraform state list:" >> "$OUTPUT_FILE"
terraform state list 2>&1 >> "$OUTPUT_FILE" || echo "Unable to list Terraform state" >> "$OUTPUT_FILE"

# Terraform Plan
add_section "TERRAFORM PLAN OUTPUT"
echo "Running terraform plan (this may take a moment)..." >> "$OUTPUT_FILE"
terraform plan -no-color 2>&1 >> "$OUTPUT_FILE" || echo "Terraform plan failed" >> "$OUTPUT_FILE"

# Terraform Logs
add_section "TERRAFORM LOGS"
if [ -f terraform.log ]; then
  echo "Last 200 lines of terraform.log:" >> "$OUTPUT_FILE"
  tail -n 200 terraform.log >> "$OUTPUT_FILE"
else
  echo "No terraform.log file found" >> "$OUTPUT_FILE"
  echo "To enable Terraform logging, set the TF_LOG environment variable (e.g., export TF_LOG=TRACE)" >> "$OUTPUT_FILE"
fi

# Check for common issues
add_section "COMMON ISSUES CHECK"

# Check AWS credentials
echo "AWS credentials check:" >> "$OUTPUT_FILE"
if aws sts get-caller-identity > /dev/null 2>&1; then
  echo "  AWS credentials: Valid" >> "$OUTPUT_FILE"
else
  echo "  AWS credentials: Invalid or missing" >> "$OUTPUT_FILE"
  echo "  Possible solutions:" >> "$OUTPUT_FILE"
  echo "    - Configure AWS CLI with 'aws configure'" >> "$OUTPUT_FILE"
  echo "    - Set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables" >> "$OUTPUT_FILE"
  echo "    - Use an AWS credentials file (~/.aws/credentials)" >> "$OUTPUT_FILE"
fi

# Check required files
echo "" >> "$OUTPUT_FILE"
echo "Required Terraform files check:" >> "$OUTPUT_FILE"
for file in vpc.tf rds.tf ecs.tf alb.tf security-groups.tf variables.tf; do
  if [ -f "$file" ]; then
    echo "  $file: Found" >> "$OUTPUT_FILE"
  else
    echo "  $file: Missing" >> "$OUTPUT_FILE"
  fi
done

# Check Terraform initialization
echo "" >> "$OUTPUT_FILE"
echo "Terraform initialization check:" >> "$OUTPUT_FILE"
if [ -d .terraform ]; then
  echo "  Terraform is initialized" >> "$OUTPUT_FILE"
else
  echo "  Terraform is not initialized" >> "$OUTPUT_FILE"
  echo "  Run 'terraform init' to initialize the working directory" >> "$OUTPUT_FILE"
fi

# Check for common error patterns in recent logs
echo "" >> "$OUTPUT_FILE"
echo "Common error patterns in logs:" >> "$OUTPUT_FILE"

# Check for permission errors
if [ -f terraform.log ] && grep -q "AccessDenied\|unauthorized\|permission" terraform.log; then
  echo "  AWS permission issues detected" >> "$OUTPUT_FILE"
  echo "  Possible solutions:" >> "$OUTPUT_FILE"
  echo "    - Verify IAM permissions for your AWS user/role" >> "$OUTPUT_FILE"
  echo "    - Check if you need additional IAM policies" >> "$OUTPUT_FILE"
fi

# Check for resource limits
if [ -f terraform.log ] && grep -q "quota\|limit exceeded\|LimitExceeded" terraform.log; then
  echo "  AWS resource limits/quotas issues detected" >> "$OUTPUT_FILE"
  echo "  Possible solutions:" >> "$OUTPUT_FILE"
  echo "    - Request quota increases in AWS Service Quotas" >> "$OUTPUT_FILE"
  echo "    - Remove unused resources" >> "$OUTPUT_FILE"
fi

# Check for network issues
if [ -f terraform.log ] && grep -q "timeout\|connection refused\|no route to host" terraform.log; then
  echo "  Network connectivity issues detected" >> "$OUTPUT_FILE"
  echo "  Possible solutions:" >> "$OUTPUT_FILE"
  echo "    - Check your internet connection" >> "$OUTPUT_FILE"
  echo "    - Verify VPN/proxy settings if applicable" >> "$OUTPUT_FILE"
  echo "    - Check firewall rules" >> "$OUTPUT_FILE"
fi

# Final instructions
add_section "NEXT STEPS"
echo "Please share this file with your instructor for assistance." >> "$OUTPUT_FILE"
echo "File location: $(pwd)/$OUTPUT_FILE" >> "$OUTPUT_FILE"
echo "File size: $(du -h "$OUTPUT_FILE" | cut -f1)" >> "$OUTPUT_FILE"

echo ""
echo "Debug information collected in $OUTPUT_FILE"
echo "Please share this file with your instructor for assistance."
echo ""