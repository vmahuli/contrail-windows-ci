def call(vaultKeyFile) {

  def ansibleConfig = """
[defaults]
deprecation_warnings = False
vault_password_file = ${vaultKeyFile}
callback_whitelist = timer,profile_tasks
"""

  writeFile file: 'ansible.cfg', text: ansibleConfig
}
