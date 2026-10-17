// Application pipeline (Jenkins multibranch job).
//  - every branch / PR : build + unit tests + coverage gate
//  - main              : Docker image -> ECR -> Helm deploy on EKS staging -> manual approval -> production
//
// Agent requirements (label 'docker'): docker, aws cli v2, kubectl, helm 3.
// Plugins: Pipeline, Docker Pipeline, Git, JUnit, Coverage, CloudBees AWS Credentials.
// Credentials: 'aws-jenkins' (AWS access key) - drop the withCredentials blocks if the agent has an IAM role.

pipeline {
	agent { label 'docker' }

	options {
		timestamps()
		disableConcurrentBuilds(abortPrevious: true)
		buildDiscarder(logRotator(numToKeepStr: '30'))
		timeout(time: 45, unit: 'MINUTES')
	}

	environment {
		APP_NAME     = 'first-saas'
		AWS_REGION   = 'eu-west-3'
		AWS_ACCOUNT  = '123456789012'                    // TODO: your AWS account id
		ECR_REGISTRY = "${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com"
		EKS_CLUSTER  = 'first-saas'
		IMAGE_TAG    = sh(script: 'git rev-parse --short=8 HEAD', returnStdout: true).trim()
		// Maven wrapper distribution + local repository cached inside the workspace
		MAVEN_USER_HOME = "${WORKSPACE}/.m2"
	}

	stages {
		stage('Build & unit tests') {
			agent {
				docker {
					image 'eclipse-temurin:25-jdk'
					reuseNode true
				}
			}
			steps {
				sh './mvnw -B -ntp -Dmaven.repo.local=$MAVEN_USER_HOME/repository verify'
			}
			post {
				always {
					junit testResults: 'target/surefire-reports/*.xml', allowEmptyResults: false
					recordCoverage tools: [[parser: 'JACOCO', pattern: 'target/site/jacoco/jacoco.xml']]
				}
			}
		}

		stage('Docker image') {
			when { branch 'main' }
			steps {
				sh 'docker build -t $ECR_REGISTRY/$APP_NAME:$IMAGE_TAG .'
			}
		}

		stage('Push to ECR') {
			when { branch 'main' }
			steps {
				withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-jenkins']]) {
					sh '''
						aws ecr get-login-password --region $AWS_REGION \
							| docker login --username AWS --password-stdin $ECR_REGISTRY
						docker push $ECR_REGISTRY/$APP_NAME:$IMAGE_TAG
					'''
				}
			}
		}

		stage('Deploy staging') {
			when { branch 'main' }
			steps {
				deploy('staging', 'deploy/helm/first-saas/values-staging.yaml')
			}
		}

		stage('Approve production') {
			when { branch 'main' }
			steps {
				timeout(time: 1, unit: 'DAYS') {
					input message: "Deploy ${IMAGE_TAG} to production?", ok: 'Deploy'
				}
			}
		}

		stage('Deploy production') {
			when { branch 'main' }
			steps {
				deploy('prod', 'deploy/helm/first-saas/values-prod.yaml')
			}
		}
	}

	post {
		always {
			sh 'docker image rm $ECR_REGISTRY/$APP_NAME:$IMAGE_TAG || true'
		}
	}
}

// --atomic rolls back automatically if the new pods never become ready
def deploy(String envName, String valuesFile) {
	withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-jenkins']]) {
		sh """
			aws eks update-kubeconfig --region \$AWS_REGION --name \$EKS_CLUSTER --kubeconfig \$WORKSPACE/.kubeconfig
			helm upgrade --install \$APP_NAME deploy/helm/first-saas \
				--kubeconfig \$WORKSPACE/.kubeconfig \
				--namespace ${APP_NAME}-${envName} --create-namespace \
				-f ${valuesFile} \
				--set image.repository=\$ECR_REGISTRY/\$APP_NAME \
				--set image.tag=\$IMAGE_TAG \
				--wait --atomic --timeout 5m
		"""
	}
}
