def call(vm_networks, vm_hardware_memory_mb, vm_hardware_num_cpus) {

  def nets = vm_networks.collect{ network -> mapToString(network) }.join()
                                    
  def baseHardwareConfig = """
vm_hardware:
  memory_mb: ${vm_hardware_memory_mb}
  num_cpus: ${vm_hardware_num_cpus}
vm_networks:
${nets}
"""

  return baseHardwareConfig
}

def mapToString(map) {
  return "  - {${ map.collect().join(', ').replaceAll("=",": ") }}\n"
}
