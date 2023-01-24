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

$TipGroup = "tongsuo"

function GetSources 
{
    [CmdletBinding()]
    Param()

    $tongsuoSourcesDir = "$SourcesDir/tongsuo"
    Write-TaskTip $TipGroup "Find sources..."
    Invoke-CloneGit "https://github.com/Tongsuo-Project/Tongsuo.git" "$TongsuoVersion" $tongsuoSourcesDir -TipGroup $TipGroup -TipName "tongsuo" | Out-Host
    return $tongsuoSourcesDir
}

function PatchSource {
    [CmdletBinding()]
    param ([string]$TongsuoSourcesDir)
    Write-TaskTip $TipGroup "Patch sources..."
    $patchFile = Join-Path $PatchsDir "tongsuo/0001-SSL_export_keying_material-add-NTLS-support.patch"
    Start-GitProcess -WorkingDirectory $TongsuoSourcesDir -TipGroup $TipGroup `
                -ArgumentList "apply",$patchFile
}

function Build 
{
    [CmdletBinding()]
    Param(
        [string]$TongsuoSourcesDir, 
        [ValidateSet("amd64", "x86", "arm64", "arm")]
        [string]$Arch,
        [switch]$BuildDebug)

    $perlPath = Invoke-DownloadDeps "Perl" $TipGroup
    $nasmPath = Invoke-DownloadDeps "Nasm" $TipGroup
    $vsDevShellPath = Get-VsDevShellPath
    $tongsuoArch = ""
    switch($Arch) {
        "amd64" {
            $tongsuoArch = "VC-WIN64A"
        }
        "x86" {
            $tongsuoArch = "VC-WIN32"
        }
        "arm64" {
            $tongsuoArch = "VC-WIN64-ARM"
        }
        "arm" {
            $tongsuoArch = "VC-WIN32-ARM"
        }
    }
    $hostArch = "x86"
    if (Get-IsAmd64) {
        $hostArch = "amd64"
    }
    $archLower = $Arch.ToLower()
    $tongsuoInstallDir = Join-Path $InstallDir "tongsuo-$TongsuoVersion-$archLower"
    if ($BuildDebug) {
        $tongsuoArch = "debug-$tongsuoArch"
        $tongsuoInstallDir = "$tongsuoInstallDir-debug"
    } else {
        $tongsuoInstallDir = "$tongsuoInstallDir-release"
    }
    New-Dictoray $tongsuoInstallDir -CleanUp | Out-Host
    Write-TaskTip $TipGroup "Configuring & Cleaning & Building..."
    Invoke-ExecuteCommand "
        `$Env:PATH = ""$perlPath/perl/bin;$nasmPath;`$Env:PATH""
        &""$vsDevShellPath"" -Arch $Arch -HostArch $hostArch
        Set-Location ""$TongsuoSourcesDir""
        &""$perlPath/perl/bin/perl"" Configure $tongsuoArch ``
         --strict-warnings --prefix=""$tongsuoInstallDir"" ``
         --openssldir=""$tongsuoInstallDir"" enable-ntls
        nmake clean /NOLOGO 2> `$null
        `$Env:CL = ""/wd4819 /wd4267 /wd4244 /wd4311 /wd4133""
        nmake install_dev /NOLOGO
    " -TipGroup $TipGroup | Out-Host
    return $tongsuoInstallDir
}

function CopyToBuildDir
{
    [CmdletBinding()]
    Param(
        [string]$TongsuoInstallDir, 
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
    Copy-Item -Path "$TongsuoInstallDir/include" -Recurse -Destination $BuildDir -Force

    Write-TaskTip $TipGroup "Copying bin files..."
    New-Dictoray $buildArchDir
    Copy-Item -Path "$TongsuoInstallDir/bin" -Recurse -Destination $buildArchDir -Force

    Write-TaskTip $TipGroup "Copying lib files..."
    Copy-Item -Path "$TongsuoInstallDir/lib" -Recurse -Destination $buildArchDir -Force
}

Write-StepTip $TipGroup "Geting v$TongsuoVersion sources..."
$tongsuoSourcesDir = GetSources
PatchSource $tongsuoSourcesDir
foreach ($arch in $Archs)
{
    Write-StepTip $TipGroup "Building v$TongsuoVersion $arch-debug..."
    $buildDebugArchDir = Build $tongsuoSourcesDir $arch -BuildDebug
    Write-StepTip $TipGroup "Copying v$TongsuoVersion $arch-debug files..."
    $buildReleaseArchDir = Build $tongsuoSourcesDir $arch
    Write-StepTip $TipGroup "Building v$TongsuoVersion $arch-release..."
    CopyToBuildDir $buildDebugArchDir $arch -BuildDebug
    Write-StepTip $TipGroup "Copying v$TongsuoVersion $arch-release files..."
    CopyToBuildDir $buildReleaseArchDir $arch
}