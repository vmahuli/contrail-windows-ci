def create(sharedDriveAddress, jenkinsMasterAddress) {

  def ansibleInventory = readFile "inventory.sample"

  ansibleInventory = ansibleInventory.replaceAll('SHARED_DRIVE_ADDRESS', sharedDriveAddress)
  ansibleInventory = ansibleInventory.replaceAll('JENKINS_MASTER_ADDRESS', jenkinsMasterAddress)

  writeFile file: 'inventory', text: ansibleInventory
}

return this
