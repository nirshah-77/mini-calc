pipeline {
    agent any

    environment {
        DOCKER_IMAGE_NAME = 'nirshah77/calculator:latest'
        GITHUB_REPO_URL = 'https://github.com/nirshah-77/mini-calc.git'
    }

    stages {

        stage('Checkout') {
            steps {
                git branch: 'main', url: "${GITHUB_REPO_URL}"
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    docker.build("${DOCKER_IMAGE_NAME}")
                }
            }
        }

        stage('Push Docker Images') {
            steps {
                script {
                    docker.withRegistry('', 'DockerHubCred') {
                        docker.image("${DOCKER_IMAGE_NAME}").push()
                    }
                }
            }
        }

        stage('Run Ansible Playbook') {
            steps {
                ansiblePlaybook(
                    playbook: 'deploy.yml',
                    inventory: 'inventory'
                )
            }
        }
    }
}
