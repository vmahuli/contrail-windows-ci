def call(playbookToRun) {
    def vmwareConfig
    def testenvConfig
    def ansibleExtraVars

    pipeline {
        agent { label "ansible" }

        environment {
            // `VC` has to be defined in outer scope to properly
            // strip credentials from logs in all child scopes (all stages).
            // Please do not move to `Prepare environment` stage.
            VC = credentials("vcenter")
            DEMOENV_MGMT_NETWORK = "VM-Network"
            VC_FOLDER = "WINCI"
        }

        stages {
            stage("Run Ansible playbook") {
                steps {
                    script {
                        vmwareConfig = getVMwareConfig()
                        testenvConfig = [
                            testenv_name: env.DEMOENV_NAME,
                            testenv_vmware_folder: env.VC_FOLDER,
                            testenv_mgmt_network: env.DEMOENV_MGMT_NETWORK,
                            testenv_data_network: env.DEMOENV_DATA_NETWORK
                        ]

                        ansibleExtraVars = vmwareConfig + testenvConfig
                    }

                    dir('ansible') {
                        ansiblePlaybook inventory: 'inventory.testenv',
                                        extraVars: ansibleExtraVars,
                                        playbook: playbookToRun
                    }
                }
            }
        }
    }
}
