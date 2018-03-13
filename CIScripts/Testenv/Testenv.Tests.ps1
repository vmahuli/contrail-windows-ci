. $PSScriptRoot\Testenv.ps1

Describe "Testenv" {

    Context "Example config" {
        It "can read controller config from a .yaml file" {
            $Controller = Read-ControllerConfig -Path $YamlPath

            $Controller.OS_credentials.Address | Should Be "1.2.3.1"
            $Controller.OS_credentials.Port | Should Be "5000"
            $Controller.OS_credentials.Username | Should Be "AzureDiamond"
            $Controller.OS_credentials.Password | Should Be "hunter2"

            $Controller.Rest_API.Address | Should Be "1.2.3.1"
            $Controller.Rest_API.Port | Should Be "8082"

            $Controller.Default_Project | Should Be "ci_tests"
        }

        It "can read configuration of testbeds from .yaml file" {
            $Testbeds = Read-TestbedsConfig -Path $YamlPath
            $Testbeds[0].Address | Should Be "1.2.3.2"
            $Testbeds[1].Address | Should Be "1.2.3.3"
            $Testbeds[0].Username | Should Be "TBUsername"
            $Testbeds[1].Username | Should Be "TBUsername"
            $Testbeds[0].Password | Should Be "TBPassword"
            $Testbeds[1].Password | Should Be "TBPassword"
        }

        BeforeEach {
            $Yaml = @"
controller:
  os_credentials:
    username: AzureDiamond
    password: hunter2
    address: 1.2.3.1
    port: 5000

  rest_api:
    address: 1.2.3.1
    port: 8082

  default_project: ci_tests

testbeds:
  - name: Testbed1
    address: 1.2.3.2
    username: TBUsername
    password: TBPassword
  - name: Testbed2
    address: 1.2.3.3
    username: TBUsername
    password: TBPassword
"@
            $YamlPath = "TestDrive:\TestYaml.yaml"
            $Yaml | Out-File $YamlPath
        }
    }

    Context "Single Testbed" {
        BeforeEach {
            $Yaml = @"
testbeds:
  - name: Testbed1
    address: 1.2.3.2
    username: TBUsername
    password: TBPassword
"@
            $YamlPath = "TestDrive:\TestYaml.yaml"
            $Yaml | Out-File $YamlPath
        }

        It "can read a config file with a single testbed" {
            $Testbeds = Read-TestbedsConfig -Path $YamlPath

            $Testbeds[0].Name | Should Be "Testbed1"
        }
    }
}
