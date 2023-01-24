[CmdletBinding()]
Param(
    [ValidateSet("amd64", "x86", "arm64", "arm")]
    [string[]]$Archs = $Env:PROCESSOR_ARCHITECTURE,
    [ValidateSet("lz4", "lzo", "openssl", "pkcs11-helper")]
    [string[]]$Dependents = @("lz4", "lzo", "openssl", "pkcs11-helper"),
    [switch]$UseTongsuo
)

if ($MyInvocation.InvocationName -eq "&") {
    $env:BuildScriptPath = (Get-Item $MyInvocation.PSScriptRoot).FullName
} else {
    $env:BuildScriptPath = (Get-Item (Split-Path $MyInvocation.InvocationName)).FullName
}
$env:BuildScriptModulesPath = Join-Path $env:BuildScriptPath "modules"
Import-Module "$env:BuildScriptModulesPath/environment" -DisableNameChecking -Verbose:$false
Import-Module "$env:BuildScriptModulesPath/common" -DisableNameChecking -Verbose:$false
Import-Module "$env:BuildScriptModulesPath/dependent" -DisableNameChecking -Verbose:$false

New-Dictoray $BuildDir -CleanUp | Out-Host
foreach($dependent in $Dependents)
{
    if ($UseTongsuo -and ($dependent -eq "openssl")) {
        $dependent = "tongsuo"
    }
    $buildScriptPath = Join-Path $env:BuildScriptPath "build-$dependent.ps1"
    $parameters = @{
        "Archs" = $Archs
    }
    if(Get-HasParameter $buildScriptPath "UseTongsuo") {
        $parameters["UseTongsuo"] = $UseTongsuo
    }
    &$buildScriptPath @parameters
}