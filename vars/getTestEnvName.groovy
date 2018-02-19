def call(networkName) {
    def pattern = /^VLAN_([0-9]+)_TestEnv$/
    def match = networkName =~ pattern
    return match[0][1]
}
