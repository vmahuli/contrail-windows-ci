def call(Map params) {
  def playbook = params.playbook
  def prepareConfig = params.config

  pipeline {
    agent none
    stages {
      stage('Prepare environment') {
        agent { label 'ansible' }
        environment {
          VC = credentials('vcenter')
        }
        steps {
          dir('ansible') {
            createCommonVars env.SHARED_DRIVE_IP, env.JENKINS_MASTER_IP
            createAnsibleConfig env.ANSIBLE_VAULT_KEY_FILE
            sh 'cp inventory.sample inventory'
            sh 'ansible-galaxy install -r requirements.yml -f'
            script {
              prepareConfig(env.VC_HOSTNAME, env.VC_DATACENTER, env.VC_CLUSTER, env.VC_FOLDER,
                            env.VC_NETWORK, env.VC_USR, env.VC_PSW, env.VM_TEMPLATE)
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
                            sudoUser: 'ubuntu'
          }
        }
      }
    }
  }
}
