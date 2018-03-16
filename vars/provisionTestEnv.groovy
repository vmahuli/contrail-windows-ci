def call(vmwareConfig, testenvConfPath) {
    def extraVars = vmwareConfig + [ testenv_conf_file: testenvConfPath ]

    dir('ansible') {
        ansiblePlaybook inventory: 'inventory',
                        playbook: 'vmware-deploy-testenv.yml',
                        extraVars: extraVars,
                        extras: '-e @vmware-vm.vars'
    }
}
