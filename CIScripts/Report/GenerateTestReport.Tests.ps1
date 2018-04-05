. $PSScriptRoot\..\Common\Init.ps1
. $PSScriptRoot\GenerateTestReport.ps1

Describe "Generating test report" {
    function NormalizeXmlString {
        Param([Parameter(Mandatory = $true)] [string] $InputData)
        ([Xml] $InputData).OuterXml
    }

    BeforeAll {
        $InputDir = Join-Path $TestDrive "testReportInput"
        $OutputDir = Join-Path $TestDrive "testReportOutput"
        New-Item -Type Directory $InputDir | Out-Null

        '
            <test-results failures="0" inconclusive="0" skipped="0" date="2018-01-01" time="15:00:00">
                <test-suite name="outer_suite" type="TestFixture" result="Success">
                    <results>
                        <test-suite name="inner_suite" type="TestFixture" result="Success">
                            <results>
                                <test-case name="test" result="Success" />
                            </results>
                        </test-suite>
                    </results>
                </test-suite>
            </test-results>
        ' | Set-Content -Path (Join-Path $InputDir "foo.xml")
        
        Convert-TestReportsToHtml -XmlReportsDir $InputDir -OutputDir $OutputDir
    }

    It "creates appropriate subdirectories" {
        Join-Path $OutputDir "raw_NUnit" | Should Exist
        Join-Path $OutputDir "pretty_test_report" | Should Exist
    }

    It "creates appropriate files" {
        Join-Path $OutputDir "raw_NUnit/foo.xml" | Should Exist
        Join-Path $OutputDir "pretty_test_report/Index.html" | Should Exist
        Join-Path $OutputDir "reports-locations.json" | Should Exist
    }

    It "flattens the xml files" {
        $ExpectedXml = NormalizeXmlString '
            <test-results failures="0" inconclusive="0" skipped="0" date="2018-01-01" time="15:00:00">
                <test-suite name="inner_suite" type="TestFixture" result="Success">
                    <results>
                        <test-case name="test" result="Success" />
                    </results>
                </test-suite>
            </test-results>
        '

        $FileContents = Get-Content -Raw (Join-Path $OutputDir "raw_NUnit/foo.xml")
        NormalizeXmlString $FileContents | Should BeExactly $ExpectedXml
    }

    Context "json" {
        BeforeAll {
            [
                Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments",
                "Json",
                Justification="PSAnalyzer doesn't understand relations of Pester's blocks.")
            ]
            $Json = Get-Content -Raw -Path (Join-Path $OutputDir "reports-locations.json") | ConvertFrom-Json
        }

        It "contains valid path to xml report" {
            $Json.'xml_reports'[0] | Should BeExactly './raw_NUnit/foo.xml'
        }

        It "contains valid path to html report" {
            $Json.'html_report' | Should BeExactly './pretty_test_report/Index.html'
        }
    }
}