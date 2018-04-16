$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

. $PSScriptRoot/../Common/Init.ps1
Describe "Repair-NUnitReport" -Tags CI, Unit {

    function NormalizeXmlString {
        Param([Parameter(Mandatory = $true)] [string] $InputData)
        ([Xml] $InputData).OuterXml
    }

    Context "test-suite tag flattening" {
        It "doesn't change simplest case" {
            $TestData = NormalizeXmlString -InputData @"
<test-results>
<test-suite name="3">
<results>
    <test-case name="tc3a" />
</results>
</test-suite>
</test-results>
"@
            $ActualOutput = Repair-NUnitReport -InputData $TestData
            NormalizeXmlString $ActualOutput | Should BeExactly $TestData
        }

        It "works when there are no test-cases" {
            $TestData = NormalizeXmlString -InputData @"
<test-results>
<test-suite name="3">
<results>
</results>
</test-suite>
</test-results>
"@
            $ExpectedOutput = NormalizeXmlString -InputData @"
<test-results>
</test-results>
"@
            $ActualOutput = Repair-NUnitReport -InputData $TestData
            NormalizeXmlString $ActualOutput | Should BeExactly $ExpectedOutput
        }

        It "works with deep nesting" {
            $TestData = NormalizeXmlString -InputData @"
<test-results>
<test-suite name="2">
<results>
    <test-suite name="3">
    <results>
        <test-suite name="4">
        <results>
            <test-suite name="5">
            <results>
                <test-case name="tc5a" />
                <test-case name="tc5b" />
            </results>
            </test-suite>
        </results>
        </test-suite>
    </results>
    </test-suite>
</results>
</test-suite>
</test-results>
"@
            $ExpectedOutput = NormalizeXmlString -InputData @"
<test-results>
<test-suite name="5">
<results>
    <test-case name="tc5a" />
    <test-case name="tc5b" />
</results>
</test-suite>
</test-results>
"@
            $ActualOutput = Repair-NUnitReport -InputData $TestData
            NormalizeXmlString $ActualOutput | Should BeExactly $ExpectedOutput
        }

        It "flattens ParameterizedTest test-suite nodes" {
            $TestData = NormalizeXmlString -InputData @"
<test-results>
<test-suite name="real context">
<results>
    <test-suite name="parameterized" type="ParameterizedTest">
    <results>
        <test-case name="test-a" />
        <test-case name="test-b" />
    </results>
    </test-suite>
</results>
</test-suite>
</test-results>
"@
            $ExpectedOutput = NormalizeXmlString -InputData @"
<test-results>
<test-suite name="real context">
<results>
    <test-case name="test-a" />
    <test-case name="test-b" />
</results>
</test-suite>
</test-results>
"@
            $ActualOutput = Repair-NUnitReport -InputData $TestData
            NormalizeXmlString $ActualOutput | Should BeExactly $ExpectedOutput
        }

        It "removes case-less test suites when there is one with cases" {
            $TestData = NormalizeXmlString -InputData @"
<test-results>
<test-suite name="2">
<results>
    <test-suite name="3">
    <results>
        <test-case name="tc3a" />
        <test-case name="tc3b" />
    </results>
    </test-suite>
</results>
</test-suite>
</test-results>
"@
            $ExpectedOutput = NormalizeXmlString -InputData @"
<test-results>
<test-suite name="3">
<results>
    <test-case name="tc3a" />
    <test-case name="tc3b" />
</results>
</test-suite>
</test-results>
"@
            $ActualOutput = Repair-NUnitReport -InputData $TestData
            NormalizeXmlString $ActualOutput | Should BeExactly $ExpectedOutput
        }

        It "removes case-less test suites when there are multiple with cases" {
            $TestData = NormalizeXmlString -InputData @"
<test-results>
<test-suite name="2">
<results>
    <test-suite name="3">
    <results>
        <test-case name="tc3a" />
        <test-case name="tc3b" />
    </results>
    </test-suite>
    <test-suite name="4">
    <results>
        <test-case name="tc4a" />
        <test-case name="tc4b" />
    </results>
    </test-suite>
</results>
</test-suite>
</test-results>
"@
            $ExpectedOutput = NormalizeXmlString -InputData @"
<test-results>
<test-suite name="3">
<results>
    <test-case name="tc3a" />
    <test-case name="tc3b" />
</results>
</test-suite>
<test-suite name="4">
<results>
    <test-case name="tc4a" />
    <test-case name="tc4b" />
</results>
</test-suite>
</test-results>
"@
            $ActualOutput = Repair-NUnitReport -InputData $TestData
            NormalizeXmlString $ActualOutput | Should BeExactly $ExpectedOutput
        }

        It "removes all test-suite tags except direct parents of test-case tags" {
            $TestData = NormalizeXmlString -InputData @"
<test-results>
<test-suite name="1">
<results>
    <test-suite name="2">
    <results>
        <test-suite name="3">
        <results>
            <test-case name="tc3a" />
            <test-case name="tc3b" />
            <test-suite name="4">
            <results>
                <test-case name="tc4a" />
                <test-case name="tc4b" />
            </results>
            </test-suite>
            <test-suite name="5">
            <results>
                <test-case name="tc5" />
            </results>
            </test-suite>
        </results>
        </test-suite>
    </results>
    </test-suite>
</results>
</test-suite>
</test-results>
"@
            $ExpectedOutput = NormalizeXmlString -InputData @"
<test-results>
<test-suite name="3">
<results>
    <test-case name="tc3a" />
    <test-case name="tc3b" />
</results>
</test-suite>
<test-suite name="4">
<results>
    <test-case name="tc4a" />
    <test-case name="tc4b" />
</results>
</test-suite>
<test-suite name="5">
<results>
    <test-case name="tc5" />
</results>
</test-suite>
</test-results>
"@
            $ActualOutput = Repair-NUnitReport -InputData $TestData
            NormalizeXmlString $ActualOutput | Should BeExactly $ExpectedOutput
        }

        It "preserves other tags" {
            $TestData = NormalizeXmlString -InputData @"
<?xml version="1.0"?>
<test-results>
    <environment />
    <culture-info />
    <test-suite name="2">
    <results>
        <test-suite name="3">
        <results>
            <test-case name="tc3a" />
            <test-case name="tc3b" />
        </results>
        </test-suite>
    </results>
    </test-suite>
</test-results>
"@

            $ExpectedOutput = NormalizeXmlString -InputData @"
<?xml version="1.0"?>
<test-results>
    <environment />
    <culture-info />
    <test-suite name="3">
    <results>
        <test-case name="tc3a" />
        <test-case name="tc3b" />
    </results>
    </test-suite>
</test-results>
"@

            $ActualOutput = Repair-NUnitReport -InputData $TestData
            NormalizeXmlString $ActualOutput | Should BeExactly $ExpectedOutput
        }

    }

    Context "test name cleanup" {
        It "makes names of test-cases more readable" {
            $TestData = NormalizeXmlString -InputData @"
<?xml version="1.0"?>
<test-results>
    <environment />
    <culture-info />
    <test-suite name="2">
    <results>
        <test-suite name="3">
        <results>
            <test-case description="MyTestCase" name="2.3.MyTestCase" />
        </results>
        </test-suite>
    </results>
    </test-suite>
</test-results>
"@

            $ExpectedOutput = NormalizeXmlString -InputData @"
<?xml version="1.0"?>
<test-results>
    <environment />
    <culture-info />
    <test-suite name="3">
    <results>
        <test-case description="MyTestCase" name="MyTestCase" />
    </results>
    </test-suite>
</test-results>
"@

            $ActualOutput = Repair-NUnitReport -InputData $TestData
            NormalizeXmlString $ActualOutput | Should BeExactly $ExpectedOutput
        }
    }
}
