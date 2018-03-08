$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

Describe "Testenv" {
    It "can read controller config from a .yaml file" {
        $Controller = Read-ControllerConfig -Path "TestYaml.yaml"
        $Controller["Address"] | Should -Be "1.2.3.1"
        $Controller["Port"] | Should -Be "8082"
        $Controller["Username"] | Should -Be "AzureDiamond"
        $Controller["Password"] | Should -Be "hunter2"
    }

    It "can read configuration of testbeds from .yaml file" {
        $Testbeds = Read-TestbedsConfig -Path "TestYaml.yaml"
        $Testbeds[0]["Address"] | Should -Be "1.2.3.2"
        $Testbeds[1]["Address"] | Should -Be "1.2.3.3"
        $Testbeds[0]["Username"] | Should -Be "TBUsername"
        $Testbeds[1]["Username"] | Should -Be "TBUsername"
        $Testbeds[0]["Password"] | Should -Be "TBPassword"
        $Testbeds[1]["Password"] | Should -Be "TBPassword"
    }

    BeforeEach {
        $Yaml = @"
Controller:
  Address: 1.2.3.1
  Port: 8082
  Username: AzureDiamond
  Password: hunter2
Testbeds:
  - Testbed1:
    Address: 1.2.3.2
    Username: TBUsername
    Password: TBPassword
  - Testbed2:
    Address: 1.2.3.3
    Username: TBUsername
    Password: TBPassword
"@
        $Yaml | Out-File "TestYaml.yaml"
    }

    AfterEach {
        Remove-Item "TestYaml.yaml"
    }
}
