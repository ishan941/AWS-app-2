#!/bin/bash

# Jenkins deployment script for AWS App
# This script handles deployment to different environments

set -e

ENVIRONMENT=${1:-development}
VERSION=${2:-latest}
AWS_REGION=${AWS_REGION:-us-east-1}

echo "🚀 Deploying AWS App to ${ENVIRONMENT} environment"
echo "📦 Version: ${VERSION}"
echo "🌍 AWS Region: ${AWS_REGION}"

# Function to deploy to development environment
deploy_development() {
    echo "🔧 Deploying to Development Environment..."
    
    # Update docker-compose with new image tags
    if [ -f "docker-compose.dev.yml" ]; then
        sed -i.bak "s/image: aws-app-web:.*/image: aws-app-web:${VERSION}/" docker-compose.dev.yml
        sed -i.bak "s/image: aws-app-backend:.*/image: aws-app-backend:${VERSION}/" docker-compose.dev.yml
        
        # Deploy using docker-compose
        docker-compose -f docker-compose.dev.yml down
        docker-compose -f docker-compose.dev.yml up -d
        
        # Wait for services to be healthy
        echo "⏳ Waiting for services to be ready..."
        sleep 30
        
        # Health check
        if curl -f http://localhost:3001/api/health > /dev/null 2>&1; then
            echo "✅ Development deployment successful!"
        else
            echo "❌ Development deployment failed - health check failed"
            exit 1
        fi
    else
        echo "❌ docker-compose.dev.yml not found"
        exit 1
    fi
}

# Function to deploy to production environment
deploy_production() {
    echo "🏭 Deploying to Production Environment..."
    
    # Login to AWS ECR
    aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${DOCKER_REGISTRY}
    
    # Tag and push images to ECR
    docker tag aws-app-web:${VERSION} ${DOCKER_REGISTRY}/aws-app-web:${VERSION}
    docker tag aws-app-backend:${VERSION} ${DOCKER_REGISTRY}/aws-app-backend:${VERSION}
    
    docker push ${DOCKER_REGISTRY}/aws-app-web:${VERSION}
    docker push ${DOCKER_REGISTRY}/aws-app-backend:${VERSION}
    
    echo "📤 Images pushed to ECR successfully"
    
    # Deploy based on your infrastructure choice
    if [ "$DEPLOYMENT_TYPE" = "ecs" ]; then
        deploy_to_ecs
    elif [ "$DEPLOYMENT_TYPE" = "ec2" ]; then
        deploy_to_ec2
    else
        echo "⚠️  No deployment type specified. Please set DEPLOYMENT_TYPE environment variable."
        exit 1
    fi
}

# Function to deploy to ECS
deploy_to_ecs() {
    echo "🐳 Deploying to AWS ECS..."
    
    # Update ECS service with new image
    aws ecs update-service \
        --cluster aws-app-cluster \
        --service aws-app-web-service \
        --force-new-deployment \
        --region ${AWS_REGION}
    
    aws ecs update-service \
        --cluster aws-app-cluster \
        --service aws-app-backend-service \
        --force-new-deployment \
        --region ${AWS_REGION}
    
    # Wait for deployment to complete
    aws ecs wait services-stable \
        --cluster aws-app-cluster \
        --services aws-app-web-service aws-app-backend-service \
        --region ${AWS_REGION}
    
    echo "✅ ECS deployment completed successfully!"
}

# Function to deploy to EC2
deploy_to_ec2() {
    echo "🖥️  Deploying to AWS EC2..."
    
    # SSH to EC2 instance and update containers
    ssh -i ${EC2_KEY_PATH} ${EC2_USER}@${EC2_HOST} << EOF
        cd /opt/aws-app
        
        # Pull latest images
        docker pull ${DOCKER_REGISTRY}/aws-app-web:${VERSION}
        docker pull ${DOCKER_REGISTRY}/aws-app-backend:${VERSION}
        
        # Update docker-compose with new tags
        sed -i "s/image: .*/aws-app-web:.*/image: ${DOCKER_REGISTRY}/aws-app-web:${VERSION}/" docker-compose.prod.yml
        sed -i "s/image: .*/aws-app-backend:.*/image: ${DOCKER_REGISTRY}/aws-app-backend:${VERSION}/" docker-compose.prod.yml
        
        # Deploy
        docker-compose -f docker-compose.prod.yml down
        docker-compose -f docker-compose.prod.yml up -d
        
        # Clean up old images
        docker image prune -f
EOF
    
    echo "✅ EC2 deployment completed successfully!"
}

# Function to rollback deployment
rollback() {
    local previous_version=$1
    echo "🔄 Rolling back to version: ${previous_version}"
    
    if [ "$ENVIRONMENT" = "production" ]; then
        # Rollback production deployment
        if [ "$DEPLOYMENT_TYPE" = "ecs" ]; then
            # ECS rollback logic
            aws ecs update-service \
                --cluster aws-app-cluster \
                --service aws-app-web-service \
                --task-definition aws-app-web:${previous_version} \
                --region ${AWS_REGION}
        fi
    else
        # Rollback development
        deploy_development
    fi
}

# Main deployment logic
case $ENVIRONMENT in
    "development"|"dev")
        deploy_development
        ;;
    "production"|"prod")
        deploy_production
        ;;
    "rollback")
        rollback $VERSION
        ;;
    *)
        echo "❌ Invalid environment: $ENVIRONMENT"
        echo "Valid options: development, production, rollback"
        exit 1
        ;;
esac

echo "🎉 Deployment completed successfully!"