[CmdletBinding()]
Param(
    [Parameter(ParameterSetName = "Dependents")]
    [ValidateSet("Perl", "Nasm", "CMake", "Msys2")]
    [string[]]$Dependents
)

$env:BuildScriptPath = (Get-Item (Split-Path $MyInvocation.InvocationName)).FullName
$env:BuildScriptModulesPath = Join-Path $env:BuildScriptPath "modules"
Import-Module "$env:BuildScriptModulesPath/environment" -DisableNameChecking -Verbose:$false
Import-Module "$env:BuildScriptModulesPath/common" -DisableNameChecking -Verbose:$false
Import-Module "$env:BuildScriptModulesPath/dependent" -DisableNameChecking -Verbose:$false

foreach ($dependent in $Dependents)
{
  Invoke-DownloadDeps $dependent
}