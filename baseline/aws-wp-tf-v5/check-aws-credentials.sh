#!/bin/bash

echo "Checking AWS credentials..."

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "AWS CLI is not installed. Please install it first."
    exit 1
fi

# Try to get caller identity
echo "Attempting to get caller identity..."
aws sts get-caller-identity

if [ $? -eq 0 ]; then
    echo "✅ AWS credentials are valid!"
else
    echo "❌ AWS credentials are invalid or not properly configured."
    echo "Please check your credentials in:"
    echo "  - ~/.aws/credentials"
    echo "  - Environment variables (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN)"
    echo "  - Or update your terraform.tfvars file with valid credentials including aws_session_token"
fi