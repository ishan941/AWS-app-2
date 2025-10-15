pipeline {
    agent any
    
    environment {
        NODEJS_HOME = tool 'Node 20'
        PATH = "$NODEJS_HOME/bin:$PATH"
        DOCKER_IMAGE_PREFIX = 'aws-app'
        DOCKER_REGISTRY = 'your-registry.amazonaws.com' // Update with your ECR registry
        AWS_REGION = 'us-east-1' // Update with your AWS region
        
        // Environment-specific variables
        DEV_NAMESPACE = 'aws-app-dev'
        PROD_NAMESPACE = 'aws-app-prod'
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.GIT_COMMIT_SHORT = sh(
                        script: "git rev-parse --short HEAD",
                        returnStdout: true
                    ).trim()
                    env.BUILD_VERSION = "${env.BUILD_NUMBER}-${env.GIT_COMMIT_SHORT}"
                }
            }
        }
        
        stage('Install Dependencies') {
            steps {
                sh '''
                    echo "Installing root dependencies..."
                    npm ci
                    
                    echo "Building shared package..."
                    npm run build:shared
                '''
            }
        }
        
        stage('Lint and Test') {
            parallel {
                stage('Lint Web') {
                    steps {
                        sh 'npm run lint -w apps/web'
                    }
                }
                stage('Lint Backend') {
                    steps {
                        sh 'npm run lint -w apps/backend'
                    }
                }
                stage('Test Web') {
                    steps {
                        sh 'npm run test -w apps/web'
                    }
                    post {
                        always {
                            publishTestResults testResultsPattern: 'apps/web/coverage/junit.xml'
                        }
                    }
                }
                stage('Test Backend') {
                    steps {
                        sh 'npm run test -w apps/backend'
                    }
                    post {
                        always {
                            publishTestResults testResultsPattern: 'apps/backend/coverage/junit.xml'
                        }
                    }
                }
            }
        }
        
        stage('Build Applications') {
            parallel {
                stage('Build Web') {
                    steps {
                        sh 'npm run build -w apps/web'
                    }
                    post {
                        always {
                            archiveArtifacts artifacts: 'apps/web/dist/**', allowEmptyArchive: true
                        }
                    }
                }
                stage('Build Backend') {
                    steps {
                        sh 'npm run build -w apps/backend'
                    }
                    post {
                        always {
                            archiveArtifacts artifacts: 'apps/backend/dist/**', allowEmptyArchive: true
                        }
                    }
                }
            }
        }
        
        stage('Docker Build') {
            parallel {
                stage('Build Web Image') {
                    steps {
                        script {
                            def webImage = docker.build("${DOCKER_IMAGE_PREFIX}-web:${BUILD_VERSION}", "-f apps/web/Dockerfile .")
                            env.WEB_IMAGE = webImage.imageName()
                        }
                    }
                }
                stage('Build Backend Image') {
                    steps {
                        script {
                            def backendImage = docker.build("${DOCKER_IMAGE_PREFIX}-backend:${BUILD_VERSION}", "-f apps/backend/Dockerfile .")
                            env.BACKEND_IMAGE = backendImage.imageName()
                        }
                    }
                }
            }
        }
        
        stage('Security Scan') {
            parallel {
                stage('Dependency Audit') {
                    steps {
                        sh '''
                            echo "Auditing dependencies..."
                            npm audit --audit-level moderate
                        '''
                    }
                }
                stage('Docker Image Scan') {
                    when {
                        anyOf {
                            branch 'main'
                            branch 'develop'
                        }
                    }
                    steps {
                        script {
                            // Using Trivy for container scanning (install in Dockerfile if needed)
                            sh """
                                echo "Scanning Docker images for vulnerabilities..."
                                # docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy:latest image ${WEB_IMAGE}
                                # docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy:latest image ${BACKEND_IMAGE}
                            """
                        }
                    }
                }
            }
        }
        
        stage('Integration Tests') {
            when {
                anyOf {
                    branch 'main'
                    branch 'develop'
                }
            }
            steps {
                script {
                    sh '''
                        echo "Starting integration tests with Docker Compose..."
                        docker-compose -f docker-compose.test.yml up --build --abort-on-container-exit
                        docker-compose -f docker-compose.test.yml down
                    '''
                }
            }
        }
        
        stage('Deploy to Development') {
            when {
                branch 'develop'
            }
            steps {
                script {
                    deployToEnvironment('development', env.BUILD_VERSION)
                }
            }
        }
        
        stage('Deploy to Production') {
            when {
                branch 'main'
            }
            steps {
                script {
                    // Add manual approval for production deployments
                    input message: 'Deploy to Production?', ok: 'Deploy',
                          submitterParameter: 'DEPLOYER'
                    
                    deployToEnvironment('production', env.BUILD_VERSION)
                }
            }
        }
    }
    
    post {
        always {
            // Clean up Docker images to save space
            sh '''
                docker image prune -f
                docker system prune -f --volumes
            '''
        }
        success {
            echo 'Pipeline succeeded!'
            // Add Slack/email notifications here
        }
        failure {
            echo 'Pipeline failed!'
            // Add failure notifications here
        }
        cleanup {
            cleanWs()
        }
    }
}

def deployToEnvironment(String environment, String version) {
    echo "Deploying version ${version} to ${environment}..."
    
    withCredentials([
        string(credentialsId: 'aws-access-key', variable: 'AWS_ACCESS_KEY_ID'),
        string(credentialsId: 'aws-secret-key', variable: 'AWS_SECRET_ACCESS_KEY')
    ]) {
        script {
            if (environment == 'production') {
                // Production deployment using AWS ECS/EKS or EC2
                sh """
                    # Tag and push images to ECR
                    aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${DOCKER_REGISTRY}
                    
                    docker tag ${DOCKER_IMAGE_PREFIX}-web:${version} ${DOCKER_REGISTRY}/${DOCKER_IMAGE_PREFIX}-web:${version}
                    docker tag ${DOCKER_IMAGE_PREFIX}-backend:${version} ${DOCKER_REGISTRY}/${DOCKER_IMAGE_PREFIX}-backend:${version}
                    
                    docker push ${DOCKER_REGISTRY}/${DOCKER_IMAGE_PREFIX}-web:${version}
                    docker push ${DOCKER_REGISTRY}/${DOCKER_IMAGE_PREFIX}-backend:${version}
                    
                    # Deploy using your preferred method (ECS, EKS, EC2, etc.)
                    echo "Deploying to production infrastructure..."
                    # Add your production deployment commands here
                """
            } else {
                // Development deployment (could be to a dev server or staging environment)
                sh """
                    echo "Deploying to development environment..."
                    
                    # Example: Deploy to development server
                    docker-compose -f docker-compose.dev.yml down || true
                    
                    # Update image tags in docker-compose.dev.yml
                    sed -i "s/image: aws-app-web:.*/image: aws-app-web:${version}/" docker-compose.dev.yml
                    sed -i "s/image: aws-app-backend:.*/image: aws-app-backend:${version}/" docker-compose.dev.yml
                    
                    docker-compose -f docker-compose.dev.yml up -d
                """
            }
        }
    }
}