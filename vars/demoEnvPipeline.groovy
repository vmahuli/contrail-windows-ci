def call(stageFunc) {
    def vmwareConfig
    def demoEnvName
    def demoEnvFolder
    def mgmtNetwork
    def dataNetwork
    def inventoryFilePath

    pipeline {
        agent { label "ansible" }

        stages {
            stage("Prepare environment") {
                environment {
                    VC = credentials("vcenter")
                }
                steps {
                    script {
                        vmwareConfig = getVMwareConfig()
                        demoEnvName = env.DEMOENV_NAME
                        demoEnvFolder = "WINCI"
                        mgmtNetwork = env.DEMOENV_MGMT_NETWORK
                        dataNetwork = env.DEMOENV_DATA_NETWORK
                        inventoryFilePath = "${env.WORKSPACE}/ansible/vms.${env.BUILD_ID}"
                    }
                    prepareTestEnv(inventoryFilePath, demoEnvName, demoEnvFolder,
                                   mgmtNetwork, dataNetwork,
                                   env.TESTBED_TEMPLATE, env.CONTROLLER_TEMPLATE)
                }
            }
            stage("Run Ansible") {
                steps {
                    script {
                        stageFunc(vmwareConfig)
                    }
                }
            }
        }
    }
}
