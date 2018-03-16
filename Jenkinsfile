#!groovy
library "contrailWindows@$BRANCH_NAME"

def mgmtNetwork
def testNetwork
def vmwareConfig
def testEnvName
def testEnvFolder

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
                    sh "python3 -m tests.monitoring_tests"
                }
                runHelpersTests()
            }
        }

        stage('Build') {
            agent { label 'builder' }
            environment {
                THIRD_PARTY_CACHE_PATH = "C:/BUILD_DEPENDENCIES/third_party_cache/"
                DRIVER_SRC_PATH = "github.com/Juniper/contrail-windows-docker-driver"
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
                TESTENV_CONF_FILE = "testenv-conf.yaml"
                TESTBED = credentials('win-testbed')
                ARTIFACTS_DIR = "output"
                TESTBED_TEMPLATE = "Template-testbed-201803050718"
                CONTROLLER_TEMPLATE = "Template-CentOS-7.4"
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

                            prepareTestEnv(testEnvName, testEnvFolder,
                                           mgmtNetwork, testNetwork,
                                           env.TESTBED_TEMPLATE, env.CONTROLLER_TEMPLATE)

                            destroyTestEnv(vmwareConfig)
                        }

                        // 'Provision' stage
                        node(label: 'ansible') {
                            deleteDir()
                            unstash 'Ansible'

                            def testenvConfPath = "${env.WORKSPACE}/${env.TESTENV_CONF_FILE}"

                            prepareTestEnv(testEnvName, testEnvFolder,
                                           mgmtNetwork, testNetwork,
                                           env.TESTBED_TEMPLATE, env.CONTROLLER_TEMPLATE)

                            provisionTestEnv(vmwareConfig, testenvConfPath)

                            stash name: "TestenvConf", includes: "testenv-conf.yaml"
                        }

                        // 'Deploy' stage
                        node(label: 'tester && has-yaml') {
                            deleteDir()

                            unstash 'CIScripts'
                            unstash 'Artifacts'
                            unstash 'TestenvConf'

                            powershell script: './CIScripts/Deploy.ps1'
                        }

                        // 'Test' stage
                        node(label: 'tester && has-yaml') {
                            deleteDir()
                            unstash 'CIScripts'
                            unstash 'TestenvConf'

                            try {
                                powershell script: './CIScripts/Test.ps1'
                            } finally {
                                stash name: 'testReport', includes: 'test_results/*.xml', allowEmpty: true
                            }
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
    }

    post {
        always {
            node('tester') {
                deleteDir()
                unstash 'CIScripts'
                script {
                    try {
                        unstash 'testReport'
                        powershell script: './CIScripts/GenerateTestReport.ps1 -XmlsDir testReport'
                    } finally {
                        stash name: 'testReport', includes: 'test_results/*', allowEmpty: true
                    }
                }
            }

            node('master') {
                script {
                    def logServer = [
                        addr: env.LOG_SERVER,
                        user: env.LOG_SERVER_USER,
                        rootDir: env.LOG_ROOT_DIR
                    ]
                    def destDir = decideLogsDestination(logServer, env.ZUUL_UUID)

                    try {
                        unstash 'testReport'
                        findFiles(glob: 'test_results/*.xml').each {
                            publishToLogServer(logServer, "${it}", destDir+"Raw_NUnit", false)
                        }
                        findFiles(glob: 'test_results/*.html').each {
                            publishToLogServer(logServer, "${it}", destDir+"Pretty_test_report", false)
                        }
                    } catch (Exception err) {
                        echo "No test report to publish"
                    }

                    def logFilename = 'log.txt.gz'
                    obtainLogFile(env.JOB_NAME, env.BUILD_ID, logFilename)
                    publishToLogServer(logServer, logFilename, destDir)
                }

                build job: 'WinContrail/gather-build-stats', wait: false,
                      parameters: [string(name: 'BRANCH_NAME', value: env.BRANCH_NAME),
                                   string(name: 'MONITORED_JOB_NAME', value: env.JOB_NAME),
                                   string(name: 'MONITORED_BUILD_URL', value: env.BUILD_URL)]
            }
        }
    }
}
