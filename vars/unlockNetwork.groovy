def call(String networkName) {
    dir('ansible/files') {
        def cmd = [
            'python', 'unlock_network.py',
            '--host', env.VC_HOSTNAME,
            '--user', env.VC_USR,
            '--password', env.VC_PSW,
            '--datacenter', env.VC_DATACENTER,
            '--folder', env.VC_FOLDER,
            '--network-name', networkName,
        ]

        sh cmd.join(' ')
    }
}
