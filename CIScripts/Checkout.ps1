. $PSScriptRoot\Common\Init.ps1
. $PSScriptRoot\Common\Job.ps1
. $PSScriptRoot\Checkout\Zuul.ps1

$Job = [Job]::new("Checkout")

Get-ZuulRepos -GerritUrl $Env:GERRIT_URL `
              -ZuulProject $Env:ZUUL_PROJECT `
              -ZuulRef $Env:ZUUL_REF `
              -ZuulUrl $Env:ZUUL_URL `
              -ZuulBranch $Env:ZUUL_BRANCH

$Job.Done()
