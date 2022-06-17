pipeline {
    agent { label 'rbhe' }
    stages {
        stage('Build') {
            environment {
                DOCKER_BUILD_ARGS = '--build-arg http_proxy --build-arg https_proxy' // add --no-cache for a clean build
            }
            steps {
                // This really should be pulled out into a script in the source code repo
                // like ./ci-build.sh or something similar
                sh '''
                docker build ${DOCKER_BUILD_ARGS} -t edgebuilder-aws-cli dockerfiles/aws-cli
                docker build ${DOCKER_BUILD_ARGS} -t edgebuilder-wget dockerfiles/wget
                docker build ${DOCKER_BUILD_ARGS} -t edgebuilder-git dockerfiles/git
                docker build ${DOCKER_BUILD_ARGS} -t edgebuilder-dnsmasq dockerfiles/dnsmasq
                docker build ${DOCKER_BUILD_ARGS} -t edgebuilder-squid dockerfiles/squid
                docker build ${DOCKER_BUILD_ARGS} -t edgebuilder-web dockerfiles/nginx
                docker build ${DOCKER_BUILD_ARGS} -t edgebuilder-gitea dockerfiles/gitea
                docker build ${DOCKER_BUILD_ARGS} -t edgebuilder-qemu dockerfiles/qemu
                docker build ${DOCKER_BUILD_ARGS} -t edgebuilder-smb dockerfiles/smb

                # just need to trick the core builder. This image will not run, just needs to be built to be scanned by Snyk
                for dir in conf data dockerfiles/core scripts template; do mkdir -p dockerfiles/core/files/${dir}; done
                cp ./*.sh dockerfiles/core/files/
                cp ./dockerfiles/core/init.sh dockerfiles/core/files/dockerfiles/core/init.sh
                docker build ${DOCKER_BUILD_ARGS} -t edgebuilder-core dockerfiles/core
                rm -rf dockerfiles/core/files

                # just need to trick the certbot builder. This image will not run, just needs to be built to be scanned by Snyk
                mkdir -p dockerfiles/certbot/scripts
                docker build ${DOCKER_BUILD_ARGS} -t edgebuilder-certbot dockerfiles/certbot
                rm -rf dockerfiles/certbot/scripts

                docker images | grep "edgebuilder"
                '''
            }
        }

        stage('Static Code Scan') {
            when {
                expression { env.GIT_BRANCH == 'master' }
            }
            stages {
                stage('Prep Snyk Env') {
                    steps {
                        script {
                            def _files = [
                                'edgebuilder-aws-cli': 'dockerfiles/aws-cli/Dockerfile',
                                'edgebuilder-wget': 'dockerfiles/wget/Dockerfile',
                                'edgebuilder-git': 'dockerfiles/git/Dockerfile',
                                'edgebuilder-dnsmasq': 'dockerfiles/dnsmasq/Dockerfile',
                                'edgebuilder-squid': 'dockerfiles/squid/Dockerfile',
                                'edgebuilder-web': 'dockerfiles/nginx/Dockerfile',
                                'edgebuilder-gitea': 'dockerfiles/gitea/Dockerfile',
                                'edgebuilder-qemu': 'dockerfiles/qemu/Dockerfile',
                                'edgebuilder-smb': 'dockerfiles/smb/Dockerfile',
                                'edgebuilder-core': 'dockerfiles/core/Dockerfile',
                                'edgebuilder-certbot': 'dockerfiles/certbot/Dockerfile',
                            ]

                            env.SNYK_MANIFEST_FILE = _files.collect { k,v -> v }.join(',')
                            env.SNYK_PROJECT_NAME  = _files.collect { k,v -> "${k}-docker" }.join(',')
                            env.SNYK_DOCKER_IMAGE  = _files.collect { k,v -> k }.join(',')

                            env.SNYK_ALLOW_LONG_PROJECT_NAME = 'true'
                            env.SNYK_SEVERITY_THRESHOLD_CVE  = 'high'
                        }
                    }
                }

                stage('Scan') {
                    environment {
                        SCANNERS = 'protex,snyk'
                        PROJECT_NAME = 'NEX – Container First Architecture'
                    }
                    steps {
                        rbheStaticCodeScan()
                    }
                }

                stage('Virus Scan') {
                    steps {
                        script {
                            virusScan {
                                dir = '.'
                            }
                        }
                    }
                }
            }
        }
    }
}