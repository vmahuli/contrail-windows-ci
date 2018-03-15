function Repair-NUnitReport {
    Param([Parameter(Mandatory = $true)] [string] $InputData)
    [xml] $XML = $InputData

    $XPath = "//test-case"
    $TestCases = $XML | Select-Xml -XPath $Xpath
    $TestCases | ForEach-Object {
        $XML.'test-results'.AppendChild($_.Node.ParentNode.ParentNode)
    } | Out-Null

    $XPath = "//test-suite[not(.//test-case)]"
    $SuitesWithNoCases = $XML | Select-Xml -XPath $Xpath
    $SuitesWithNoCases | ForEach-Object {
        $_.Node.ParentNode.RemoveChild($_.Node)
    } | Out-Null

    Write-Host ($XML.OuterXml | Format-XML)
    return $XML.OuterXml
}
