# Run all available linters

To run all available linters, execute the following command in this directory:

```
.\Invoke-StaticAnalysisTools.ps1 -RootDir .. -ConfigDir $pwd
```

## Powershell Script Analyzer (PSSCriptAnalyzer)

To run using our settings:

```
Invoke-ScriptAnalyzer .. -Recurse -Settings C:\Full\Path\To\contrail-windows-ci\StaticAnalysis\PSScriptAnalyzerSettings.psd1
```
