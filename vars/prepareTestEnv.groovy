def call(testEnvName, testEnvFolder, mgmtNetwork, dataNetwork,
         testbedTemplate, controllerTemplate) {
    dir('ansible') {
        createTestEnvConfig testEnvName, testEnvFolder,
                            mgmtNetwork, dataNetwork,
                            testbedTemplate, controllerTemplate
        createAnsibleConfig env.ANSIBLE_VAULT_KEY_FILE

        sh 'cp inventory.testenv.sample inventory'
    }
}
