library "contrailWindows@$BRANCH_NAME"

def mgmtNetwork
def dataNetwork
def vmwareConfig
def inventoryFilePath
def testEnvName
def testEnvFolder

def testbeds

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

                script {
                    mgmtNetwork = env.TESTENV_MGMT_NETWORK
                    dataNetwork = calculateTestNetwork(env.BUILD_ID as int)
                }

                // If not using `Pipeline script from SCM`, specify the branch manually:
                // git branch: 'development', url: 'https://github.com/codilime/contrail-windows-ci/'

                stash name: "CIScripts", includes: "CIScripts/**"
                stash name: "ansible", includes: "ansible/**"
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

        // NOTE: Currently nesting multiple stages in lock directive is unsupported
        stage('Provision & Deploy & Test') {
            agent none
            environment {
                // Required in 'Provision' stages
                VC = credentials('vcenter')

                // Required in 'Deploy' and 'Test' stages
                // TODO actually create this file
                TEST_CONFIGURATION_FILE = "GetTestConfigurationJuni.ps1"
                // TESTBED_HOSTNAMES = SpawnedTestbedVMNames
                ARTIFACTS_DIR = "output"
            }
            steps {
                lock(dataNetwork) {
                    // 'Provision' stage
                    node(label: 'ansible') {
                        deleteDir()
                        unstash 'ansible'

                        script {
                            vmwareConfig = getVMwareConfig()
                            inventoryFilePath = "${env.WORKSPACE}/ansible/vm.${env.BUILD_ID}"
                            testEnvName = env.ZUUL_UUID.split('-')[0]
                            testEnvFolder = env.VC_FOLDER
                        }

                        prepareTestEnv(inventoryFilePath, testEnvName, testEnvFolder,
                                       mgmtNetwork, dataNetwork,
                                       env.TESTBED_TEMPLATE, env.CONTROLLER_TEMPLATE)
                        provisionTestEnv(vmwareConfig)

                        script {
                            testbeds = parseTestEnvInventory(inventoryFilePath)
                        }
                    }

                    // 'Deploy' stage
                    node(label: 'tester') {
                        deleteDir()
                        unstash "CIScripts"

                        powershell "Write-Host 'testbeds[0] = ${testbeds[0]}'"
                        powershell "Write-Host 'testbeds[1] = ${testbeds[1]}'"
                        powershell "Write-Host 'testbeds[2] = ${testbeds[2]}'"
                        // unstash "WinArt"
                        // powershell script: './CIScripts//Deploy.ps1'
                    }

                    // 'Test' stage
                    node(label: 'tester') {
                        deleteDir()
                        unstash "CIScripts"
                        // powershell script: './CIScripts/Test.ps1'
                    }
                }
            }
            post {
                always {
                    node(label: 'ansible') {
                        destroyTestEnv(vmwareConfig)
                    }
                }
            }
        }
    }

    environment {
        LOG_SERVER = "logs2.opencontrail.org"
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
