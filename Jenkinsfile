pipeline {
    agent any
    
    environment {
        // הכתובת של המחשב המארח מתוך הקונטיינר
        JENKINS_REGISTRY = "172.17.0.1:5000"
        // המטרה למשיכת האימג' מתוך קוברנטיס עצמו
        K8S_REGISTRY = "k3d-mycluster-registry:5000"
        APP_NAME = "devops-app"
        // זה רק השם של הכספת - מאובטח לחלוטין
        KUBECONFIG_CREDENTIAL_ID = "k8s-config" 
        // הכתובת הישירה של הקוברנטיס שלך
        K8S_API = "https://172.17.0.1:39903"
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
                sh "docker build --target builder -t ${APP_NAME}-test ."
                sh "docker run --rm ${APP_NAME}-test npm test"
            }
        }

        stage('Build Docker Image') {
            steps {
                echo "Building Docker Image version: ${BUILD_NUMBER}"
                sh "docker build -t ${JENKINS_REGISTRY}/${APP_NAME}:${BUILD_NUMBER} -t ${JENKINS_REGISTRY}/${APP_NAME}:latest ."
            }
        }

        stage('Push Image') {
            steps {
                echo "Pushing image to host registry..."
                sh "docker push ${JENKINS_REGISTRY}/${APP_NAME}:${BUILD_NUMBER}"
                sh "docker push ${JENKINS_REGISTRY}/${APP_NAME}:latest"
            }
        }

        stage('Deploy to K8s') {
            steps {
                echo "Deploying to Kubernetes..."
                withCredentials([file(credentialsId: "${KUBECONFIG_CREDENTIAL_ID}", variable: 'KUBECONFIG')]) {
                    sh "/usr/local/bin/kubectl --server=${K8S_API} --insecure-skip-tls-verify=true apply -f k8s/deployment.yaml"
                    sh "/usr/local/bin/kubectl --server=${K8S_API} --insecure-skip-tls-verify=true apply -f k8s/service.yaml"
                    sh "/usr/local/bin/kubectl --server=${K8S_API} --insecure-skip-tls-verify=true set image deployment/devops-app-deployment devops-app-container=${K8S_REGISTRY}/${APP_NAME}:${BUILD_NUMBER}"
                    sh "/usr/local/bin/kubectl --server=${K8S_API} --insecure-skip-tls-verify=true rollout status deployment/devops-app-deployment"
                }
            }
        }

        stage('Smoke Test') {
            steps {
                echo "Running Smoke Test on /health endpoint..."
                withCredentials([file(credentialsId: "${KUBECONFIG_CREDENTIAL_ID}", variable: 'KUBECONFIG')]) {
                    sh '''
                    /usr/local/bin/kubectl --server=${K8S_API} --insecure-skip-tls-verify=true run smoke-test-pod --rm -i --restart=Never --image=curlimages/curl -- curl -s -f http://devops-app-service/health
                    '''
                }
            }
        }
    }

    post {
        failure {
            echo "🚨 Pipeline failed! Initiating Automatic Rollback... 🚨"
            withCredentials([file(credentialsId: "${KUBECONFIG_CREDENTIAL_ID}", variable: 'KUBECONFIG')]) {
                sh "/usr/local/bin/kubectl --server=${K8S_API} --insecure-skip-tls-verify=true rollout undo deployment/devops-app-deployment"
                sh "/usr/local/bin/kubectl --server=${K8S_API} --insecure-skip-tls-verify=true rollout status deployment/devops-app-deployment"
                echo "✅ Rollback completed successfully."
            }
        }
        success {
            echo "🎉 Pipeline finished successfully! The new version is live."
        }
    }
}