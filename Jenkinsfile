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
            }
            steps {
                deleteDir()
                unstash "CIScripts"
                // powershell script: './CIScripts/Test.ps1'
            }
        }
    }

    post {
        always {
            node('master') {
                // cleanWs()
                sh 'echo "TODO environment cleanup"'
                // unstash "buildLogs"
                // TODO correct flags for rsync
                sh "echo rsync logs/ logs.opencontrail.org:${JOB_NAME}/${BUILD_ID}"
                // cleanWS{}
            }
        }
    }
}
