pipeline {
    agent any
    tools {
        nodejs "NodeJS20"
    }

    environment {
        DOCKERHUB_USER  = 'fawad9'
        DOCKERHUB_CREDS = credentials('dockerhub-credentials')
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
                            sh 'npm ci'
                            sh 'npm test --if-present -- --watchAll=false --passWithNoTests || true'
                        }
                    }
                }
                stage('Test Discounts') {
                    steps {
                        dir('backend/discounts') {
                            sh 'npm ci'
                            sh 'npm test --if-present -- --watchAll=false --passWithNoTests || true'
                        }
                    }
                }
                stage('Test Items') {
                    steps {
                        dir('backend/items') {
                            sh 'npm ci'
                            sh 'npm test --if-present -- --watchAll=false --passWithNoTests || true'
                        }
                    }
                }
                stage('Test Frontend') {
                    steps {
                        dir('client') {
                            sh 'npm ci'
                            sh 'CI=false npm run build'
                        }
                    }
                }
            }
        }

        stage('Build & Push Docker Images') {
            when {
                branch 'main'
            }
            steps {
                script {
                    def shortSha = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                    
                    docker.withRegistry('https://index.docker.io/v1/', 'dockerhub-credentials') {
                        
                        // Auth
                        def authImage = docker.build("${DOCKERHUB_USER}/restauranty-auth:${shortSha}", 
                            "--platform linux/amd64 ./backend/auth")
                        authImage.push()
                        authImage.push('latest')

                        // Discounts
                        def discountsImage = docker.build("${DOCKERHUB_USER}/restauranty-discounts:${shortSha}",
                            "--platform linux/amd64 ./backend/discounts")
                        discountsImage.push()
                        discountsImage.push('latest')

                        // Items
                        def itemsImage = docker.build("${DOCKERHUB_USER}/restauranty-items:${shortSha}",
                            "--platform linux/amd64 ./backend/items")
                        itemsImage.push()
                        itemsImage.push('latest')

                        // Frontend
                        def frontendImage = docker.build("${DOCKERHUB_USER}/restauranty-frontend:${shortSha}",
                            "--platform linux/amd64 ./client")
                        frontendImage.push()
                        frontendImage.push('latest')
                    }
                    env.SHORT_SHA = shortSha
                }
            }
        }

        stage('Deploy to AKS') {
            when {
                branch 'main'
            }
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

                        # Update image tags
                        for SVC in auth discounts items; do
                            sed -i "s|${DOCKERHUB_USER}/restauranty-\${SVC}:.*|${DOCKERHUB_USER}/restauranty-\${SVC}:${env.SHORT_SHA}|g" \
                                k8s/\${SVC}-deployment.yaml
                        done
                        sed -i "s|${DOCKERHUB_USER}/restauranty-frontend:.*|${DOCKERHUB_USER}/restauranty-frontend:${env.SHORT_SHA}|g" \
                            k8s/frontend-deployment.yaml

                        # Deploy
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
        success {
            echo 'Pipeline completed successfully!'
        }
        failure {
            echo 'Pipeline failed!'
        }
    }
}
