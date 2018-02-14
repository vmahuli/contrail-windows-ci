def call(firstNetworkId, networksCount) {
    def testNetworkNameFilePath = "${env.WORKSPACE}/ansible/network.${env.BUILD_ID}"

    dir('ansible/files') {
        def cmd = [
            'python', 'select_network_and_lock.py',
            '--host', env.VC_HOSTNAME,
            '--user', env.VC_USR,
            '--password', env.VC_PSW,
            '--datacenter', env.VC_DATACENTER,
            '--folder', env.VC_FOLDER,
            '--network-name-out-file', testNetworkNameFilePath,
            '--first-network-id', firstNetworkId as String,
            '--networks-count', networksCount as String,
        ]

        sh cmd.join(' ')
    }

    return readFile(testNetworkNameFilePath)
}
