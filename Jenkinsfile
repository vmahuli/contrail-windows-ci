pipeline {
    agent none

    options {
        timeout time: 5, unit: 'HOURS'
    }

    stages {
        stage('Preparation') {
            agent { label 'builder' }
            steps {
                deleteDir()

                // Use the same repo and branch as was used to checkout Jenkinsfile:
                checkout scm

                // If not using `Pipeline script from SCM`, specify the branch manually:
                // git branch: 'development', url: 'https://github.com/codilime/contrail-windows-ci/'

                stash name: "CIScripts", includes: "CIScripts/**"
            }
        }

        stage('Build') {
            agent { label 'builder' }
            environment {
                THIRD_PARTY_CACHE_PATH = "C:/BUILD_DEPENDENCIES/third_party_cache/"
                DRIVER_SRC_PATH = "github.com/Juniper/contrail-windows-docker-driver"
                BUILD_ONLY = "1"
                BUILD_IN_RELEASE_MODE = "false"
                SIGNTOOL_PATH = "C:/Program Files (x86)/Windows Kits/10/bin/x64/signtool.exe"
                CERT_PATH = "C:/BUILD_DEPENDENCIES/third_party_cache/common/certs/codilime.com-selfsigned-cert.pfx"
                CERT_PASSWORD_FILE_PATH = "C:/BUILD_DEPENDENCIES/third_party_cache/common/certs/certp.txt"

                MSBUILD = "C:/Program Files (x86)/MSBuild/14.0/Bin/MSBuild.exe"
            }
            steps {
                deleteDir()

                unstash "CIScripts"

                powershell script: './CIScripts/Build.ps1'
                //stash name: "WinArt", includes: "output/**/*"
                //stash name: "buildLogs", includes: "logs/**"
            }
        }

        // Variables are not supported in declarative pipeline.
        // Possible workaround: store SpawnedTestbedVMNames in stashed file.
        // def SpawnedTestbedVMNames = ''

        stage('Provision') {
            agent { label 'ansible' }
            steps {
                sh 'echo "TODO use ansible for provisioning"'
                // set $SpawnedTestbedVMNames here
            }
        }

        stage('Deploy') {
            agent { label 'tester' }
            environment {
                // TESTBED_HOSTNAMES = SpawnedTestbedVMNames
                ARTIFACTS_DIR = "output"
            }
            steps {
                deleteDir()
                unstash "CIScripts"
                // unstash "WinArt"
                // powershell script: './CIScripts//Deploy.ps1'
            }
        }

        stage('Test') {
            agent { label 'tester' }
            environment {
                // TESTBED_HOSTNAMES = SpawnedTestbedVMNames
                ARTIFACTS_DIR = "output"
                // TODO actually create this file
                TEST_CONFIGURATION_FILE = "GetTestConfigurationJuni.ps1"
            }
            steps {
                deleteDir()
                unstash "CIScripts"
                // powershell script: './CIScripts/Test.ps1'
            }
        }
    }

    environment {
        LOG_SERVER = "logs.opencontrail.org"
        LOG_SERVER_USER = "zuul-win"
        LOG_ROOT_DIR = "/var/www/logs/winci"
        BUILD_SPECIFIC_DIR = "${ZUUL_UUID}"
        JOB_SUBDIR = env.JOB_NAME.replaceAll("/", "/jobs/")
        LOCAL_SRC_FILE = "${JENKINS_HOME}/jobs/${JOB_SUBDIR}/builds/${BUILD_ID}/log"
        REMOTE_DST_FILE = "${LOG_ROOT_DIR}/${BUILD_SPECIFIC_DIR}/log.txt"
    }

    post {
        always {
            node('master') {
                script {
                    // Job triggered by Zuul -> upload log file to public server.
                    // Job triggered by Github CI repository (variable "ghprbPullId" exists) -> keep log "private".
                    if (env.ghprbPullId == null) {
                        // cleanWs()
                        echo "TODO environment cleanup"
                        // unstash "buildLogs"
                        // TODO correct flags for rsync
                        sh "ssh ${LOG_SERVER_USER}@${LOG_SERVER} \"mkdir -p ${LOG_ROOT_DIR}/${BUILD_SPECIFIC_DIR}\""
                        sh "rsync ${LOCAL_SRC_FILE} ${LOG_SERVER_USER}@${LOG_SERVER}:${REMOTE_DST_FILE}"
                        // cleanWS{}
                    }
                }
            }
        }
    }
}
