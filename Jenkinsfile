pipeline {
    agent { label 'docker-agent' }

    parameters {
        string(name: 'BRANCH', defaultValue: 'main', description: 'Git branch to build')
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scmGit(
                    branches: [[name: "*/${params.BRANCH}"]],
                    userRemoteConfigs: scm.userRemoteConfigs
                )
                sh '''
                    echo "Branch: ${BRANCH}"
                    echo "Commit: $(git rev-parse --short HEAD)"
                '''
            }
        }

        stage('Build') {
            steps {
                sh 'docker build -t cicd-flask-lab:${BUILD_NUMBER} .'
            }
        }

        stage('Deploy') {
            steps {
                sh '''
                    IMAGE_TAG=${BUILD_NUMBER} \
                    APP_BRANCH=${BRANCH} \
                    BUILD_NUMBER=${BUILD_NUMBER} \
                    docker compose up -d --remove-orphans

                    docker compose ps
                    curl -f http://localhost:5000/health
                '''
            }
        }
    }
}
