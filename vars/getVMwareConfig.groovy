def call(vm_role) {

  def baseVMParams = [vcenter_hostname: env.VC_HOSTNAME,
                      vcenter_user: env.VC_USR,
                      vcenter_password: env.VC_PSW,
                      validate_certs: 'no',
                      datacenter_name: env.VC_DATACENTER,
                      cluster_name: env.VC_CLUSTER,
                      vmware_folder: env.VC_FOLDER.replaceAll("\"", ""),
                      vm_template: env.VM_TEMPLATE,
                      vm_role: vm_role]

  return baseVMParams
}
