def call(vcHostname, vcDatacenter, vcCluster, vcUsername, vcPassword,
         inventoryFilePath, demoEnvName, demoEnvFolder, demoEnvVlan,
         testbedTemplate = "IGNORED", controllerTemplate = "IGNORED",
         configPath = 'vmware-vm.vars') {
    def configText = """
# Common vCenter infra connection parameters
vcenter_hostname: ${vcHostname}
vcenter_user: ${vcUsername}
vcenter_password: ${vcPassword}
validate_certs: false
datacenter_name: ${vcDatacenter}
cluster_name: ${vcCluster}

# Common testenv vars
vm_inventory_file: ${inventoryFilePath}
testenv_name: ${demoEnvName}
testenv_folder: ${demoEnvFolder}

# Testenv block
wintestbed_template: ${testbedTemplate}
controller_template: ${controllerTemplate}
testenv_block:
    controller:
        template: "{{ controller_template }}"
        nodes:
          - name: "{{ testenv_name }}-controller"
    wintb:
        template: "{{ wintestbed_template }}"
        netmask: 255.255.0.0
        nodes:
          - name: "{{ testenv_name }}-wintb01"
            ip: 172.16.0.2
          - name: "{{ testenv_name }}-wintb02"
            ip: 172.16.0.3

# Common network parameters
vlan_id: ${demoEnvVlan}
portgroup_mgmt: "VM Network"
portgroup_contrail: "{{ vlan_id }}"
netmask_mgmt: 255.255.255.0
netmask_contrail: 255.255.0.0
gateway_mgmt: 10.84.12.254
dns_servers: [ 10.84.5.100, 172.21.200.60 ]
domain: englab.juniper.net
"""

    writeFile file: configPath, text: configText
}
