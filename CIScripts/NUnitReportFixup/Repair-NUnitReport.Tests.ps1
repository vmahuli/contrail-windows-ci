$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

Describe "Repair-NUnitReport" {

    function NormalizeString {
        Param([Parameter(Mandatory = $true)] [string] $InputData)
        return $InputData -Replace "`r`n", "" -Replace "    ",""
    }

    Context "test-suite tag flattening" {
        It "doesn't change simplest case" {
            $TestData = NormalizeString -InputData @"
<test-results>
<test-suite name="3">
<results>
    <test-case name="tc3a" />
</results>
</test-suite>
</test-results>
"@
            $ActualOutput = Repair-NUnitReport -InputData $TestData
            $ActualOutput | Should BeExactly $TestData
        }

        It "works when there are no test-cases" {
            $TestData = NormalizeString -InputData @"
<test-results>
<test-suite name="3">
<results>
</results>
</test-suite>
</test-results>
"@
            $ExpectedOutput = NormalizeString -InputData @"
<test-results>
</test-results>
"@
            $ActualOutput = Repair-NUnitReport -InputData $TestData
            $ActualOutput | Should BeExactly $ExpectedOutput
        }

        It "works with deep nesting" {
            $TestData = NormalizeString -InputData @"
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
            $ExpectedOutput = NormalizeString -InputData @"
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
            $ActualOutput | Should BeExactly $ExpectedOutput
        }


        It "removes case-less test suites when there is one with cases" {
            $TestData = NormalizeString -InputData @"
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
            $ExpectedOutput = NormalizeString -InputData @"
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
            $ActualOutput | Should BeExactly $ExpectedOutput
        }

        It "removes case-less test suites when there are multiple with cases" {
            $TestData = NormalizeString -InputData @"
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
            $ExpectedOutput = NormalizeString -InputData @"
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
            $ActualOutput | Should BeExactly $ExpectedOutput
        }

        It "removes all test-suite tags except direct parents of test-case tags" {
            $TestData = NormalizeString -InputData @"
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
            $ExpectedOutput = NormalizeString -InputData @"
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
            $ActualOutput | Should BeExactly $ExpectedOutput
        }

        It "preserves other tags" {
            $TestData = NormalizeString -InputData @"
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

$ExpectedOutput = NormalizeString -InputData @"
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
            $ActualOutput | Should BeExactly $ExpectedOutput
        }

    }

    Context "test name cleanup" {
        It "makes names of tests more readable" {

        }
    }
}
