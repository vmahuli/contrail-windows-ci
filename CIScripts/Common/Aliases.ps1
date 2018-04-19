# Create PSSessionT alias
$AccelPSSessionT = [PowerShell].Assembly.GetType("System.Management.Automation.TypeAccelerators")
$AccelPSSessionT::add("PSSessionT", "System.Management.Automation.Runspaces.PSSession")
