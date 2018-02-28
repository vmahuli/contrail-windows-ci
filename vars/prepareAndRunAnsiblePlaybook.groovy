def call(Map params) {
  def prepareHardwareConfig = params.config
  def playbook = params.playbook
  def vm_role = params.vm_role
  def vmWareConfig
  pipeline {
    agent none

    environment {
      // `VC` has to be defined in outer scope to properly
      // strip credentials from logs in all child scopes (all stages).
      // Please do not move to `Prepare environment` stage.
      VC = credentials('vcenter')
    }

    stages {
      stage('Prepare environment') {
        agent { label 'ansible' }
        steps {
          dir('ansible') {
            createCommonVars env.SHARED_DRIVE_IP, env.JENKINS_MASTER_IP
            createAnsibleConfig env.ANSIBLE_VAULT_KEY_FILE
            sh 'cp inventory.sample inventory'
            script {
              vmWareConfig = getVMwareConfig(vm_role)
              prepareHardwareConfig(params)
            }
          }
        }
      }
      stage('Run ansible') {
        agent { label 'ansible' }
        steps {
          dir('ansible') {
            ansiblePlaybook extras: '-e @vm.vars -e @common.vars', \
                            inventory: 'inventory', \
                            playbook: playbook, \
                            sudoUser: 'ubuntu', \
                            extraVars: vmWareConfig
          }
        }
      }
    }
  }
}
