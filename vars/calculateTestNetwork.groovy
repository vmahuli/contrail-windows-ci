def call(int buildId, int availableNetworks = 15) {
    def firstNetworkId = 506
    def networkId = firstNetworkId + buildId % availableNetworks
    def networkName = "VLAN_${networkId}_TestEnv"
    return networkName
}
