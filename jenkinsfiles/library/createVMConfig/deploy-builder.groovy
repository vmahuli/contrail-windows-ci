def create(vc_usr, vc_psw, vm_template, file_path = 'vm.vars') {
  def vmConfig = """vcenter_hostname: ci-vc.englab.juniper.net
vcenter_user: ${vc_usr}
vcenter_password: ${vc_psw}
validate_certs: no
datacenter_name: CI-DC
cluster_name: WinCI
vmware_folder: "WINCI"

vm_template: ${vm_template}
vm_role: builder

vm_hardware:
    memory_mb: 24576
    num_cpus: 8

vm_networks:
    - name: "VM Network"
      type: dhcp
"""
  writeFile file: file_path, text: vmConfig
}

return this
