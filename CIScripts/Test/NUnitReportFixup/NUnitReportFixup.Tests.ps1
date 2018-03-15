$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

Describe "NUnitReportFixup" {
    Context "test-suite tag flattening" {
        It "removes all test-suite tags except direct parents of test-case tags" {

        }
    }
    Context "test name cleanup" {
        It "makes names of tests more readable" {

        }
    }
}
