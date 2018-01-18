def call(params, file_path = 'vm.vars') {

  def vm_networks = params.vm_networks
  def vm_hardware_memory_mb = params.vm_hardware_memory_mb
  def vm_hardware_num_cpus = params.vm_hardware_num_cpus

  def vmHardwareConfig = getBaseHardwareConfig(vm_networks, vm_hardware_memory_mb, vm_hardware_num_cpus)

  writeFile file: file_path, text: vmHardwareConfig
}
