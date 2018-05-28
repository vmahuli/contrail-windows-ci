#!groovy
library "contrailWindows@$BRANCH_NAME"

pipeline {
    agent none

    options {
        timeout time: 5, unit: 'HOURS'
        timestamps()
        lock label: 'testenv_pool', quantity: 1
    }

    stages {
        stage('Preparation') {
            agent { label 'ansible' }
            steps {
                deleteDir()

                // Use the same repo and branch as was used to checkout Jenkinsfile:
                checkout scm

                stash name: "CIScripts", includes: "CIScripts/**"
                stash name: "CISelfcheck", includes: "Invoke-Selfcheck.ps1"
                stash name: "StaticAnalysis", includes: "StaticAnalysis/**"
                stash name: "Ansible", includes: "ansible/**"
                stash name: "Monitoring", includes: "monitoring/**"
            }
        }

        stage('Checkout projects') {
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

        stage('Build, testenv provisioning and sanity checks') {
            parallel {

                stage('CI selfcheck - Windows') {
                    agent { label 'tester' }
                    steps {
                        deleteDir()
                        unstash "CIScripts"
                        unstash "CISelfcheck"
                        script {
                            try {
                                powershell script: """./Invoke-Selfcheck.ps1 `
                                    -ReportDir ${env.WORKSPACE}/testReportsRaw/CISelfcheck"""
                            } finally {
                                stash name: 'testReportsCISelfcheck', includes: 'testReportsRaw/**', allowEmpty: true
                            }
                        }
                    }
                }

                stage('CI selfcheck - Linux') {
                    when { expression { env.ghprbPullId } }
                    agent { label 'linux' }
                    options {
                        timeout time: 5, unit: 'MINUTES'
                    }
                    steps {
                        deleteDir()
                        unstash "CIScripts"

                        unstash "Monitoring"
                        dir("monitoring") {
                            sh "python3 -m tests.monitoring_tests"
                        }

                        runHelpersTests()
                    }
                }

                stage('Static analysis - Windows') {
                    agent { label 'builder' }
                    steps {
                        deleteDir()
                        unstash "StaticAnalysis"
                        unstash "SourceCode"
                        unstash "CIScripts"
                        powershell script: "./StaticAnalysis/Invoke-StaticAnalysisTools.ps1 -RootDir . -Config ${pwd()}/StaticAnalysis"
                    }
                }

                stage('Static analysis - Linux') {
                    when { expression { env.ghprbPullId } }
                    agent { label 'linux' }
                    options {
                        timeout time: 5, unit: 'MINUTES'
                    }
                    steps {
                        deleteDir()

                        unstash "StaticAnalysis"
                        unstash "Ansible"
                        sh "StaticAnalysis/ansible_linter.py"
                    }
                }

                stage('Build') {
                    agent { label 'builder' }
                    environment {
                        THIRD_PARTY_CACHE_PATH = "C:/BUILD_DEPENDENCIES/third_party_cache/"
                        DRIVER_SRC_PATH = "github.com/Juniper/contrail-windows-docker-driver"
                        BUILD_IN_RELEASE_MODE = "false"
                        AGENT_BUILD_THREADS = "6"
                        SIGNTOOL_PATH = "C:/Program Files (x86)/Windows Kits/10/bin/x64/signtool.exe"
                        CERT_PATH = "C:/BUILD_DEPENDENCIES/third_party_cache/common/certs/codilime.com-selfsigned-cert.pfx"
                        CERT_PASSWORD_FILE_PATH = "C:/BUILD_DEPENDENCIES/third_party_cache/common/certs/certp.txt"
                        COMPONENTS_TO_BUILD = "DockerDriver,Extension,Agent"

                        WINCIDEV = credentials('winci-drive')
                    }
                    steps {
                        deleteDir()

                        unstash "CIScripts"
                        unstash "SourceCode"

                        powershell script: './CIScripts/BuildStage.ps1'

                        stash name: "Artifacts", includes: "output/**/*"
                    }
                    post {
                        always {
                            deleteDir()
                        }
                    }
                }

                stage('Testenv provisioning') {
                    agent { label 'ansible' }
                    when { environment name: "DONT_CREATE_TESTBEDS", value: null }

                    environment {
                        TESTBED = credentials('win-testbed')
                        // TODO: change after creation of proper templates
                        TESTBED_TEMPLATE = "Template-testbed-201805280222"
                        CONTROLLER_TEMPLATE = "Template-CentOS-7.4-Thin-LinkedClones"
                        TESTENV_MGMT_NETWORK = "VLAN_501_Management"
                        TESTENV_FOLDER = "WINCI/testenvs"
                        VCENTER_DATASTORE_CLUSTER = "WinCI-Datastores-SSD"
                    }

                    steps {
                        script {
                            def testNetwork = getLockedNetworkName()
                            def testEnvName = getTestEnvName(testNetwork)
                            def destroyConfig = [
                                testenv_name: testEnvName,
                                testenv_folder: env.TESTENV_FOLDER
                            ]
                            def deployConfig = [
                                testenv_name: testEnvName,
                                testenv_folder: env.TESTENV_FOLDER,
                                testenv_mgmt_network: env.TESTENV_MGMT_NETWORK,
                                testenv_data_network: testNetwork,
                                testenv_testbed_template: env.TESTBED_TEMPLATE,
                                testenv_controller_template: env.CONTROLLER_TEMPLATE,
                                vcenter_datastore_cluster: env.VCENTER_DATASTORE_CLUSTER,
                            ]

                            deleteDir()
                            unstash 'Ansible'

                            dir('ansible') {
                                // Cleanup testenv before making a new one
                                ansiblePlaybook inventory: 'inventory.testenv',
                                                playbook: 'vmware-destroy-testenv.yml',
                                                extraVars: destroyConfig

                                def testEnvConfPath = "${env.WORKSPACE}/testenv-conf.yaml"
                                def provisioningExtraVars = deployConfig + [
                                    testenv_conf_file: testEnvConfPath
                                ]
                                ansiblePlaybook inventory: 'inventory.testenv',
                                                playbook: 'vmware-deploy-testenv.yml',
                                                extraVars: provisioningExtraVars
                            }

                            stash name: "TestenvConf", includes: "testenv-conf.yaml"
                        }
                    }
                }
            }
        }

        stage('Deploy') {
            agent { label 'tester' }
            when { environment name: "DONT_CREATE_TESTBEDS", value: null }
            steps {
                deleteDir()

                unstash 'CIScripts'
                unstash 'Artifacts'
                unstash 'TestenvConf'

                powershell script: """./CIScripts/Deploy.ps1 `
                    -TestenvConfFile testenv-conf.yaml `
                    -ArtifactsDir output"""
            }
        }

        stage('Test') {
            agent { label 'tester' }
            when { environment name: "DONT_CREATE_TESTBEDS", value: null }
            steps {
                deleteDir()
                unstash 'CIScripts'
                unstash 'TestenvConf'
                script {
                    try {
                        powershell script: """./CIScripts/Test.ps1 `
                            -TestenvConfFile testenv-conf.yaml `
                            -TestReportDir ${env.WORKSPACE}/testReportsRaw/WindowsCompute"""
                    } finally {
                        stash name: 'testReportsWindowsCompute', includes: 'testReportsRaw/**', allowEmpty: true
                    }
                }
            }
        }
    }

    environment {
        LOG_SERVER = "logs.opencontrail.org"
        LOG_SERVER_USER = "zuul-win"
        LOG_SERVER_FOLDER = "winci"
        LOG_ROOT_DIR = "/var/www/logs/winci"
    }

    post {
        always {
            node('tester') {
                deleteDir()
                unstash 'CIScripts'
                script {
                    try {
                        unstash 'testReportsWindowsCompute'
                        unstash 'testReportsCISelfcheck'
                    } catch (Exception err) {
                        echo "No test report to parse"
                    } finally {
                        powershell script: '''./CIScripts/GenerateTestReport.ps1 `
                            -XmlsDir testReportsRaw/WindowsCompute `
                            -OutputDir TestReports/WindowsCompute'''

                        powershell script: '''./CIScripts/GenerateTestReport.ps1 `
                            -XmlsDir testReportsRaw/CISelfcheck `
                            -OutputDir TestReports/CISelfcheck'''

                        // Using robocopy to workaround 260 chars path length limitation.
                        // TODO: Similar method may be used when CISelfcheck generates detailed logs.
                        robocopy("${pwd()}/testReportsRaw/WindowsCompute/detailed/", "${pwd()}/TestReports/WindowsCompute/detailedLogs", "*.log")

                        stash name: 'processedTestReports', includes: 'TestReports/**', allowEmpty: true
                    }
                }
            }

            node('master') {
                script {
                    deleteDir()
                    def logServer = [
                        addr: env.LOG_SERVER,
                        user: env.LOG_SERVER_USER,
                        folder: env.LOG_SERVER_FOLDER,
                        rootDir: env.LOG_ROOT_DIR
                    ]
                    def destDir = decideLogsDestination(logServer, env.ZUUL_UUID)

                    dir('to_publish') {
                        unstash 'processedTestReports'
                        def logFilename = 'log.txt.gz'
                        obtainLogFile(env.JOB_NAME, env.BUILD_ID, logFilename)
                        publishToLogServer(logServer, ".", destDir)
                    }

                    def logsURL = getLogsURL(logServer, env.ZUUL_UUID)

                    if (isGithub()) {
                        sendGithubComment("Full logs URL: ${logsURL}")
                    }

                    def reportLocationsFile = "${logsURL}/TestReports/WindowsCompute/reports-locations.json"
                    build job: 'WinContrail/gather-build-stats', wait: false,
                        parameters: [string(name: 'BRANCH_NAME', value: env.BRANCH_NAME),
                                     string(name: 'MONITORED_JOB_NAME', value: env.JOB_NAME),
                                     string(name: 'MONITORED_BUILD_URL', value: env.BUILD_URL),
                                     string(name: 'TEST_REPORTS_JSON_URL', value: reportLocationsFile)]
                }
            }
        }
    }
}
