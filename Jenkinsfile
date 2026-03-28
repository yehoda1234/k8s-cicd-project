pipeline {
    agent any
    
    environment {
        REGISTRY = "k3d-mycluster-registry:5000"
        APP_NAME = "devops-app"
        IMAGE_NAME = "${REGISTRY}/${APP_NAME}"
        KUBECONFIG_CREDENTIAL_ID = "k8s-config" 
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Install & Test') {
            steps {
                echo "Building test environment and running tests..."
                // התיקון שלנו: בונים אימג' טסטים על בסיס ה-Dockerfile שלנו ומריצים בו את הטסט
                sh "docker build --target builder -t ${APP_NAME}-test ."
                sh "docker run --rm ${APP_NAME}-test npm test"
            }
        }

        stage('Build Docker Image') {
            steps {
                echo "Building Docker Image version: ${BUILD_NUMBER}"
                sh "docker build -t ${IMAGE_NAME}:${BUILD_NUMBER} -t ${IMAGE_NAME}:latest ."
            }
        }

        stage('Push Image') {
            steps {
                echo "Pushing image to local registry..."
                sh "docker push ${IMAGE_NAME}:${BUILD_NUMBER}"
                sh "docker push ${IMAGE_NAME}:latest"
            }
        }

        stage('Deploy to K8s') {
            steps {
                echo "Deploying to Kubernetes..."
                withCredentials([file(credentialsId: "${KUBECONFIG_CREDENTIAL_ID}", variable: 'KUBECONFIG')]) {
                    // הוספנו נתיב מלא לכל פקודות ה-kubectl
                    sh "/usr/local/bin/kubectl apply -f k8s/deployment.yaml"
                    sh "/usr/local/bin/kubectl apply -f k8s/service.yaml"
                    sh "/usr/local/bin/kubectl set image deployment/devops-app-deployment devops-app-container=${IMAGE_NAME}:${BUILD_NUMBER}"
                    sh "/usr/local/bin/kubectl rollout status deployment/devops-app-deployment"
                }
            }
        }

        stage('Smoke Test') {
            steps {
                echo "Running Smoke Test on /health endpoint..."
                withCredentials([file(credentialsId: "${KUBECONFIG_CREDENTIAL_ID}", variable: 'KUBECONFIG')]) {
                    sh '''
                    /usr/local/bin/kubectl run smoke-test-pod --rm -i --restart=Never --image=curlimages/curl -- curl -s -f http://devops-app-service/health
                    '''
                }
            }
        }
    }

    post {
        failure {
            echo "🚨 Pipeline failed! Initiating Automatic Rollback... 🚨"
            withCredentials([file(credentialsId: "${KUBECONFIG_CREDENTIAL_ID}", variable: 'KUBECONFIG')]) {
                sh "/usr/local/bin/kubectl rollout undo deployment/devops-app-deployment"
                sh "/usr/local/bin/kubectl rollout status deployment/devops-app-deployment"
                echo "✅ Rollback completed successfully."
            }
        }
        success {
            echo "🎉 Pipeline finished successfully! The new version is live."
        }
    }
}