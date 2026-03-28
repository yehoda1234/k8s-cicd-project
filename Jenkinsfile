pipeline {
    agent any
    
    // הגדרת משתני סביבה שנשתמש בהם לאורך הפייפליין
    environment {
        REGISTRY = "k3d-mycluster-registry:5000"
        APP_NAME = "devops-app"
        IMAGE_NAME = "${REGISTRY}/${APP_NAME}"
        // השם של הסוד (Secret) שניצור בג'נקינס בשביל הקוברנטיס
        KUBECONFIG_CREDENTIAL_ID = "k8s-config" 
    }

    stages {
        stage('Checkout') {
            steps {
                // משיכת הקוד מ-Git
                checkout scm
            }
        }
        
        stage('Install & Test') {
            steps {
                echo "Installing dependencies and running tests..."
                // מכיוון שיש לנו קונטיינר Jenkins נקי, אנחנו משתמשים ב-Docker כדי להריץ סביבת Node זמנית לטסטים
                sh 'docker run --rm -v ${WORKSPACE}:/app -w /app node:18-alpine sh -c "npm install && npm test"'
            }
        }

        stage('Build Docker Image') {
            steps {
                echo "Building Docker Image version: ${BUILD_NUMBER}"
                // בניית האימג' עם שני תיוגים (Tags): מספר הבילד ו-latest
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
                // שימוש ב-Secret של ה-Kubeconfig כמו שהתרגיל דרש! לא שומרים סיסמאות בקוד
                withCredentials([file(credentialsId: "${KUBECONFIG_CREDENTIAL_ID}", variable: 'KUBECONFIG')]) {
                    sh "kubectl apply -f k8s/deployment.yaml"
                    sh "kubectl apply -f k8s/service.yaml"
                    // עדכון ה-Deployment לאימג' החדש שכרגע בנינו
                    sh "kubectl set image deployment/devops-app-deployment devops-app-container=${IMAGE_NAME}:${BUILD_NUMBER}"
                    // המתנה עד שה-Rolling Update מסתיים בהצלחה
                    sh "kubectl rollout status deployment/devops-app-deployment"
                }
            }
        }

        stage('Smoke Test') {
            steps {
                echo "Running Smoke Test on /health endpoint..."
                withCredentials([file(credentialsId: "${KUBECONFIG_CREDENTIAL_ID}", variable: 'KUBECONFIG')]) {
                    // אנחנו מריצים פוד זמני של curl בתוך הקלאסטר כדי לבדוק שהשירות מחזיר 200
                    sh '''
                    kubectl run smoke-test-pod --rm -i --restart=Never --image=curlimages/curl -- curl -s -f http://devops-app-service/health
                    '''
                }
            }
        }
    }

    // הבלוק שקופץ בסוף הריצה - פה מוגדר ה-Rollback האוטומטי!
    post {
        failure {
            echo "🚨 Pipeline failed! Initiating Automatic Rollback... 🚨"
            withCredentials([file(credentialsId: "${KUBECONFIG_CREDENTIAL_ID}", variable: 'KUBECONFIG')]) {
                // ביטול העדכון והחזרה לגרסה הקודמת
                sh "kubectl rollout undo deployment/devops-app-deployment"
                sh "kubectl rollout status deployment/devops-app-deployment"
                echo "✅ Rollback completed successfully."
            }
        }
        success {
            echo "🎉 Pipeline finished successfully! The new version is live."
        }
    }
}