#!groovy
library "contrailWindows@$BRANCH_NAME"

def mgmtNetwork
def testNetwork
def vmwareConfig
def inventoryFilePath
def testEnvName
def testEnvFolder

def testbeds

pipeline {
    agent none

    options {
        timeout time: 5, unit: 'HOURS'
        timestamps()
    }

    stages {
        stage('Preparation') {
            agent { label 'ansible' }
            steps {
                deleteDir()

                // Use the same repo and branch as was used to checkout Jenkinsfile:
                checkout scm

                script {
                    mgmtNetwork = env.TESTENV_MGMT_NETWORK
                }

                stash name: "CIScripts", includes: "CIScripts/**"
                stash name: "StaticAnalysis", includes: "StaticAnalysis/**"
                stash name: "Ansible", includes: "ansible/**"
                stash name: "Monitoring", includes: "monitoring/**"
            }
        }

        stage ('Checkout projects') {
            agent { label 'builder' }
            environment {
                DRIVER_SRC_PATH = "github.com/Juniper/contrail-windows-docker-driver"
            }
            steps {
                deleteDir()
                unstash "CIScripts"
                powershell script: './CIScripts/Checkout.ps1'
                stash name: "SourceCode", excludes: "CIScripts"
            }
        }

        stage('Static analysis') {
            agent { label 'builder' }
            steps {
                deleteDir()
                unstash "StaticAnalysis"
                unstash "SourceCode"
                unstash "CIScripts"
                powershell script: "./StaticAnalysis/Invoke-StaticAnalysisTools.ps1 -RootDir . -Config ${pwd()}/StaticAnalysis"
            }
        }

        stage('Linux-test') {
            when { expression { env.ghprbPullId } }
            agent { label 'linux' }
            options {
                timeout time: 5, unit: 'MINUTES'
            }
            steps {
                unstash "Monitoring"
                dir("monitoring") {
                    sh "./test_stats.py"
                }
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
                WINCIDEV = credentials('winci-drive')
            }
            steps {
                deleteDir()

                unstash "CIScripts"
                unstash "SourceCode"

                powershell script: './CIScripts/BuildStage.ps1'

                stash name: "Artifacts", includes: "output/**/*"
            }
        }

        stage('Cleanup-Provision-Deploy-Test') {
            agent none
            when { environment name: "DONT_CREATE_TESTBEDS", value: null }

            environment {
                VC = credentials('vcenter')
                TEST_CONFIGURATION_FILE = "GetTestConfigurationJuni.ps1"
                TESTBED = credentials('win-testbed')
                ARTIFACTS_DIR = "output"
                TESTBED_TEMPLATE = "Template-testbed-201802130923"
                CONTROLLER_TEMPLATE = "template-contrail-controller-3.1.1.0-45"
            }

            steps {
                script {
                    lock(label: 'testenv_pool', quantity: 1) {
                        testNetwork = getLockedNetworkName()
                        vmwareConfig = getVMwareConfig()
                        testEnvName = getTestEnvName(testNetwork)
                        testEnvFolder = env.VC_FOLDER

                        // 'Cleanup' stage
                        node(label: 'ansible') {
                            deleteDir()
                            unstash 'Ansible'

                            inventoryFilePath = "${env.WORKSPACE}/ansible/vm.${env.BUILD_ID}"

                            prepareTestEnv(inventoryFilePath, testEnvName, testEnvFolder,
                                           mgmtNetwork, testNetwork,
                                           env.TESTBED_TEMPLATE, env.CONTROLLER_TEMPLATE)

                            destroyTestEnv(vmwareConfig)
                        }

                        // 'Provision' stage
                        node(label: 'ansible') {
                            deleteDir()
                            unstash 'Ansible'

                            inventoryFilePath = "${env.WORKSPACE}/ansible/vm.${env.BUILD_ID}"

                            prepareTestEnv(inventoryFilePath, testEnvName, testEnvFolder,
                                           mgmtNetwork, testNetwork,
                                           env.TESTBED_TEMPLATE, env.CONTROLLER_TEMPLATE)

                            provisionTestEnv(vmwareConfig)
                            testbeds = parseTestbedAddresses(inventoryFilePath)
                        }

                        // 'Deploy' stage
                        node(label: 'tester') {
                            deleteDir()

                            unstash 'CIScripts'
                            unstash 'Artifacts'

                            env.TESTBED_ADDRESSES = testbeds.join(',')

                            powershell script: './CIScripts/Deploy.ps1'
                        }

                        // 'Test' stage
                        node(label: 'tester') {
                            deleteDir()
                            unstash 'CIScripts'
                            powershell script: './CIScripts/Test.ps1'
                        }
                    }
                }
            }
        }
    }

    environment {
        LOG_SERVER = "logs.opencontrail.org"
        LOG_SERVER_USER = "zuul-win"
        LOG_ROOT_DIR = "/var/www/logs/winci"
        BUILD_SPECIFIC_DIR = "${ZUUL_UUID}"
        JOB_SUBPATH = env.JOB_NAME.replaceAll("/", "/job/")
        REMOTE_DST_FILE = "${LOG_ROOT_DIR}/${BUILD_SPECIFIC_DIR}/log.txt.gz"
    }

    post {
        always {
            node('master') {
                script {
                    // Job triggered by Zuul -> upload log file to public server.
                    // Job triggered by Github CI repository (variable "ghprbPullId" exists) -> keep log "private".

                    // TODO JUNIPER_WINDOWSSTUBS variable check is temporary and should be removed once
                    // repository contrail-windows is accessible from Gerrit and it is main source of
                    // windowsstubs code.
                    if (env.ghprbPullId == null && env.JUNIPER_WINDOWSSTUBS == null) {
                        // unstash "buildLogs"
                        // TODO correct flags for rsync
                        sh "ssh ${LOG_SERVER_USER}@${LOG_SERVER} \"mkdir -p ${LOG_ROOT_DIR}/${BUILD_SPECIFIC_DIR}\""
                        def tmpLogFilename = "clean_log.txt.gz"
                        obtainLogFile(env.JOB_NAME, env.BUILD_ID, tmpLogFilename)
                        sh "rsync $tmpLogFilename ${LOG_SERVER_USER}@${LOG_SERVER}:${REMOTE_DST_FILE}"
                        deleteDir()
                    }
                }

                build job: 'WinContrail/gather-build-stats', wait: false,
                      parameters: [string(name: 'BRANCH_NAME', value: env.BRANCH_NAME),
                                   string(name: 'MONITORED_JOB_NAME', value: env.JOB_NAME),
                                   string(name: 'MONITORED_BUILD_URL', value: env.BUILD_URL)]
            }
        }
    }
}
