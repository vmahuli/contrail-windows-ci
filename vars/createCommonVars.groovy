def call(sharedDriveAddress, jenkinsMasterAddress, filePath = 'common.vars') {
  def vars ="""
dependencies_source: \\\\${sharedDriveAddress}\\SharedFiles
jenkins_agent_master: ${jenkinsMasterAddress}
"""

  writeFile file: filePath, text: vars
}
