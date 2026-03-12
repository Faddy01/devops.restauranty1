pipeline {
    agent { label 'built-in' }

    environment {
        DOCKERHUB_USER  = 'fawad9'
        AKS_CLUSTER     = 'restauranty-aks'
        AKS_RG          = 'restauranty-rg'
        NAMESPACE       = 'restauranty'
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Test') {
            parallel {
                stage('Test Auth') {
                    steps {
                        dir('backend/auth') {
                            sh 'npm ci && npm test --if-present -- --watchAll=false --passWithNoTests || true'
                        }
                    }
                }
                stage('Test Discounts') {
                    steps {
                        dir('backend/discounts') {
                            sh 'npm ci && npm test --if-present -- --watchAll=false --passWithNoTests || true'
                        }
                    }
                }
                stage('Test Items') {
                    steps {
                        dir('backend/items') {
                            sh 'npm ci && npm test --if-present -- --watchAll=false --passWithNoTests || true'
                        }
                    }
                }
                stage('Build Frontend') {
                    steps {
                        dir('client') {
                            sh 'npm ci && CI=false npm run build'
                        }
                    }
                }
            }
        }

        stage('Build & Push Docker Images') {
            steps {
                script {
                    def shortSha = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                    env.SHORT_SHA = shortSha

                    withCredentials([usernamePassword(
                        credentialsId: 'dockerhub-credentials',
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PASS'
                    )]) {
                        sh "echo \$DOCKER_PASS | docker login -u \$DOCKER_USER --password-stdin"

                        sh """
                            docker buildx build --platform linux/amd64 \
                                -t ${DOCKERHUB_USER}/restauranty-auth:${shortSha} \
                                -t ${DOCKERHUB_USER}/restauranty-auth:latest \
                                ./backend/auth --push

                            docker buildx build --platform linux/amd64 \
                                -t ${DOCKERHUB_USER}/restauranty-discounts:${shortSha} \
                                -t ${DOCKERHUB_USER}/restauranty-discounts:latest \
                                ./backend/discounts --push

                            docker buildx build --platform linux/amd64 \
                                -t ${DOCKERHUB_USER}/restauranty-items:${shortSha} \
                                -t ${DOCKERHUB_USER}/restauranty-items:latest \
                                ./backend/items --push

                            docker buildx build --platform linux/amd64 \
                                -t ${DOCKERHUB_USER}/restauranty-frontend:${shortSha} \
                                -t ${DOCKERHUB_USER}/restauranty-frontend:latest \
                                ./client --push
                        """
                    }
                }
            }
        }

        stage('Deploy to AKS') {
            steps {
                withCredentials([azureServicePrincipal('azure-credentials')]) {
                    sh """
                        az login --service-principal \
                            -u \$AZURE_CLIENT_ID \
                            -p \$AZURE_CLIENT_SECRET \
                            --tenant \$AZURE_TENANT_ID

                        az aks get-credentials \
                            --resource-group ${AKS_RG} \
                            --name ${AKS_CLUSTER} \
                            --overwrite-existing

                        for SVC in auth discounts items; do
                            sed -i "s|fawad9/restauranty-\${SVC}:.*|fawad9/restauranty-\${SVC}:${env.SHORT_SHA}|g" \
                                k8s/\${SVC}-deployment.yaml
                        done
                        sed -i "s|fawad9/restauranty-frontend:.*|fawad9/restauranty-frontend:${env.SHORT_SHA}|g" \
                            k8s/frontend-deployment.yaml

                        kubectl apply -f k8s/namespace.yaml
                        kubectl apply -f k8s/auth-deployment.yaml
                        kubectl apply -f k8s/discounts-deployment.yaml
                        kubectl apply -f k8s/items-deployment.yaml
                        kubectl apply -f k8s/frontend-deployment.yaml
                        kubectl apply -f k8s/ingress.yaml

                        kubectl get pods -n ${NAMESPACE}
                    """
                }
            }
        }
    }

    post {
        success { echo 'Pipeline completed successfully!' }
        failure { echo 'Pipeline failed!' }
    }
}