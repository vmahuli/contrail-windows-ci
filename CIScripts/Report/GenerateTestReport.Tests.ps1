. $PSScriptRoot\..\Common\Init.ps1
. $PSScriptRoot\GenerateTestReport.ps1

Describe "Generating test report" {
    function NormalizeXmlString {
        Param([Parameter(Mandatory = $true)] [string] $InputData)
        ([Xml] $InputData).OuterXml
    }

    function New-DummyFile {
        Param([Parameter(Mandatory = $true)] [string] $Path)
        '<test-results failures="0" inconclusive="0" skipped="0" date="2018-01-01" time="15:00:00">
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
        ' | Set-Content -Path $Path
    }

    function New-TemporaryDirs {
        $InputDir = Join-Path $TestDrive "testReportInput"
        $OutputDir = Join-Path $TestDrive "testReportOutput"
        New-Item -Type Directory $InputDir | Out-Null
        return $InputDir, $OutputDir
    }

    function Clear-TemporaryDirs {
        Param([Parameter(Mandatory = $true)] [string[]] $Dirs)
        $Dirs | ForEach-Object {
            Remove-Item -Recurse -Force $_
        }
    }

    function Invoke-FakeReportunit {
        Param([Parameter(Mandatory = $true)] [string] $NUnitDir)
        $Files = Get-ChildItem -Path $NUnitDir -File
        if ($Files.length -eq 0) {
            throw "Empty directory"
        }
        if ($Files.length -gt 1) {
            New-Item -Type File -Path (Join-Path $NUnitDir "Index.html")
        }
        $Files | ForEach-Object {
            New-Item -Type File -Path (Join-Path $NUnitDir ($_.BaseName + ".html"))
        }
    }

    function Test-JsonFileForMonitoring {
        Param([Parameter(Mandatory = $true)] [String[]] $Xmls)

        $TestCases = $Xmls | Foreach-Object { @{ Filename = $_ } }

        It "json file for monitoring contains valid path to <Filename> report" -TestCases $TestCases {
            Param($Filename)
            $Json = Get-Content -Raw -Path (Join-Path $OutputDir "reports-locations.json") | ConvertFrom-Json
            "./raw_NUnit/$Filename" | Should BeIn $Json.'xml_reports'
            $Json.'xml_reports'[0].GetType().Name | Should Be 'string'
        }

        It "json file for monitoring contains valid path to html report" {
            $Json = Get-Content -Raw -Path (Join-Path $OutputDir "reports-locations.json") | ConvertFrom-Json
            $Json.'html_report' | Should BeExactly './pretty_test_report/Index.html'
        }
    }

    Context "single xml file" {
        BeforeAll {
            $InputDir, $OutputDir = New-TemporaryDirs
            New-DummyFile -Path (Join-Path $InputDir "foo.xml")
            # TODO split this tests to unit & integration test, and use
            # -GeneratorFunc (Get-Item function:Invoke-FakeReportunit)
            Convert-TestReportsToHtml -XmlReportsDir $InputDir -OutputDir $OutputDir
        }
        
        AfterAll {
            Clear-TemporaryDirs -Dirs @($InputDir, $OutputDir)
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
            </test-results>'
            $FileContents = Get-Content -Raw (Join-Path $OutputDir "raw_NUnit/foo.xml")
            NormalizeXmlString $FileContents | Should BeExactly $ExpectedXml
        }

        Test-JsonFileForMonitoring "foo.xml"
    }

    Context "multiple xml files" {
        BeforeAll {
            $InputDir, $OutputDir = New-TemporaryDirs
            New-DummyFile -Path (Join-Path $InputDir "foo.xml")
            New-DummyFile -Path (Join-Path $InputDir "bar.xml")
            New-DummyFile -Path (Join-Path $InputDir "baz.xml")
            # TODO split this tests to unit & integration test, and use
            # -GeneratorFunc (Get-Item function:Invoke-FakeReportunit)
            Convert-TestReportsToHtml -XmlReportsDir $InputDir -OutputDir $OutputDir
        }

        AfterAll {
            Clear-TemporaryDirs -Dirs @($InputDir, $OutputDir)
        }

        It "creates appropriate files" {
            Join-Path $OutputDir "raw_NUnit/foo.xml" | Should Exist
            Join-Path $OutputDir "raw_NUnit/bar.xml" | Should Exist
            Join-Path $OutputDir "raw_NUnit/baz.xml" | Should Exist
            Join-Path $OutputDir "pretty_test_report/Index.html" | Should Exist
            Join-Path $OutputDir "pretty_test_report/foo.html" | Should Exist
            Join-Path $OutputDir "pretty_test_report/bar.html" | Should Exist
            Join-Path $OutputDir "pretty_test_report/baz.html" | Should Exist
            Join-Path $OutputDir "reports-locations.json" | Should Exist
        }

        # TODO(sodar) enable the test after fixing it:
        # Test-JsonFileForMonitoring "foo.xml", "bar.xml", "baz.xml"
    }
}
