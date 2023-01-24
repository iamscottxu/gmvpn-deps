[CmdletBinding()]
Param(
    [ValidateSet("amd64", "x86", "arm64", "arm")]
    [string[]]$Archs = $Env:PROCESSOR_ARCHITECTURE
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

$TipGroup = "openssl"

function GetSources 
{
    [CmdletBinding()]
    Param()

    $opensslSourcesDir = "$SourcesDir/openssl"
    Write-TaskTip $TipGroup "Find sources..."
    Invoke-CloneGit "https://github.com/openssl/openssl.git" "openssl-$OpensslVersion" $opensslSourcesDir -TipGroup $TipGroup -TipName "openssl" | Out-Host
    return $opensslSourcesDir
}

function Build 
{
    [CmdletBinding()]
    Param(
        [string]$OpensslSourcesDir, 
        [ValidateSet("amd64", "x86", "arm64", "arm")]
        [string]$Arch,
        [switch]$BuildDebug)

    $perlPath = Invoke-DownloadDeps "Perl" $TipGroup
    $nasmPath = Invoke-DownloadDeps "Nasm" $TipGroup
    $vsDevShellPath = Get-VsDevShellPath
    $opensslArch = ""
    switch($Arch) {
        "amd64" {
            $opensslArch = "VC-WIN64A"
        }
        "x86" {
            $opensslArch = "VC-WIN32"
        }
        "arm64" {
            $opensslArch = "VC-WIN64-ARM"
        }
        "arm" {
            $opensslArch = "VC-WIN32-ARM"
        }
    }
    $hostArch = "x86"
    if (Get-IsAmd64) {
        $hostArch = "amd64"
    }
    $archLower = $Arch.ToLower()
    $opensslInstallDir = Join-Path $InstallDir "openssl-$OpensslVersion-$archLower"
    if ($BuildDebug) {
        $opensslArch = "debug-$opensslArch"
        $opensslInstallDir = "$opensslInstallDir-debug"
    } else {
        $opensslInstallDir = "$opensslInstallDir-release"
    }
    New-Dictoray $opensslInstallDir -CleanUp | Out-Host
    Write-TaskTip $TipGroup "Configuring & Cleaning & Building..."
    Invoke-ExecuteCommand "
        `$Env:PATH = ""$perlPath/perl/bin;$nasmPath;`$Env:PATH""
        &""$vsDevShellPath"" -Arch $Arch -HostArch $hostArch
        Set-Location ""$OpensslSourcesDir""
        &""$perlPath/perl/bin/perl"" Configure $opensslArch ``
        --strict-warnings --prefix=""$opensslInstallDir"" ``
        --openssldir=""$opensslInstallDir""
        nmake clean /NOLOGO 2> `$null
        nmake install_dev /NOLOGO
    " -TipGroup $TipGroup | Out-Host
    return $opensslInstallDir
}

function CopyToBuildDir
{
    [CmdletBinding()]
    Param(
        [string]$OpensslInstallDir, 
        [ValidateSet("amd64", "x86", "arm64", "arm")]
        [string]$Arch,
        [switch]$BuildDebug
    )
    $dirSuffix = "release"
    if ($BuildDebug) {
        $dirSuffix = "debug"
    }
    $buildArchDir = $BuildArchDirs[$Arch] + "-$dirSuffix"
    Write-TaskTip $TipGroup "Copying include files..."
    New-Dictoray $BuildDir
    Copy-Item -Path "$OpensslInstallDir/include" -Recurse -Destination $BuildDir -Force

    Write-TaskTip $TipGroup "Copying bin files..."
    New-Dictoray $buildArchDir
    Copy-Item -Path "$OpensslInstallDir/bin" -Recurse -Destination $buildArchDir -Force

    Write-TaskTip $TipGroup "Copying lib files..."
    Copy-Item -Path "$OpensslInstallDir/lib" -Recurse -Destination $buildArchDir -Force
}

Write-StepTip $TipGroup "Geting v$OpensslVersion sources..."
$opensslSourcesDir = GetSources
foreach ($arch in $Archs)
{
    Write-StepTip $TipGroup "Building v$OpensslVersion $arch-debug..."
    $buildDebugArchDir = Build $opensslSourcesDir $arch -BuildDebug
    Write-StepTip $TipGroup "Building v$OpensslVersion $arch-release..."
    $buildReleaseArchDir = Build $opensslSourcesDir $arch
    Write-StepTip $TipGroup "Copying v$OpensslVersion $arch-debug files..."
    CopyToBuildDir $buildDebugArchDir $arch -BuildDebug
    Write-StepTip $TipGroup "Copying v$OpensslVersion $arch-release files..."
    CopyToBuildDir $buildReleaseArchDir $arch
}