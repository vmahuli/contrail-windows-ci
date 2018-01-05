def call(vc_hostname, vc_datacenter, vc_cluster, vc_folder, vc_network,
         vc_username, vc_password, vm_template,
         file_path = 'vm.vars') {
  def vmConfig = """
vcenter_hostname: ${vc_hostname}
vcenter_user: ${vc_username}
vcenter_password: ${vc_password}
validate_certs: no
datacenter_name: ${vc_datacenter}
cluster_name: ${vc_cluster}
vmware_folder: ${vc_folder}

vm_template: ${vm_template}
vm_role: builder

vm_hardware:
  memory_mb: 24576
  num_cpus: 8

vm_networks:
  - name: ${vc_network}
    type: dhcp

vm_hdd:
  - type: thin
    size: 200
"""
  writeFile file: file_path, text: vmConfig
}
