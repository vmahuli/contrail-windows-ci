def call(vmwareConfig) {
    dir('ansible') {
        ansiblePlaybook inventory: 'inventory',
                        playbook: 'vmware-deploy-testenv.yml',
                        extraVars: vmwareConfig,
                        extras: '-e @vmware-vm.vars'
    }
}
