def call(params, file_path = 'vm.vars') {

  def vm_networks = params.vm_networks
  def vm_hardware_memory_mb = params.vm_hardware_memory_mb
  def vm_hardware_num_cpus = params.vm_hardware_num_cpus

  def vmHardwareConfig = getBaseHardwareConfig(vm_networks, vm_hardware_memory_mb, vm_hardware_num_cpus)

  if (params.vm_hdd_size) {
    def vm_hdd_size = params.vm_hdd_size

    vmHardwareConfig += """
vm_hdd:
  - type: thin
    size: ${vm_hdd_size}
"""
  }

  writeFile file: file_path, text: vmHardwareConfig
}
