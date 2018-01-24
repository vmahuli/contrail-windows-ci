def call(inventoryFilePath, testEnvName, testEnvFolder, mgmtNetwork, dataNetwork,
         testbedTemplate, controllerTemplate) {
    dir('ansible') {
        createTestEnvConfig inventoryFilePath, testEnvName, testEnvFolder,
                            mgmtNetwork, dataNetwork,
                            testbedTemplate, controllerTemplate
        createAnsibleConfig env.ANSIBLE_VAULT_KEY_FILE

        sh 'cp inventory.testenv.sample inventory'
    }
}
