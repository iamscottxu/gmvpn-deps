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

$TipGroup = "lz4"

function GetSources 
{
    [CmdletBinding()]
    Param()

    $lz4SourcesDir = "$SourcesDir/lz4"
    Write-TaskTip $TipGroup "Find sources..."
    Invoke-CloneGit "https://github.com/lz4/lz4.git" "v$Lz4Version" $Lz4SourcesDir -TipGroup $TipGroup -TipName "lz4" | Out-Host
    return $lz4SourcesDir
}

function Build 
{
    [CmdletBinding()]
    Param(
        [string]$Lz4SourcesDir, 
        [ValidateSet("amd64", "x86", "arm64", "arm")]
        [string]$Arch,
        [switch]$BuildDebug)

    $cmakePath = Invoke-DownloadDeps "CMake" $TipGroup
    $cmakeArch = ""
    switch($Arch) {
        "amd64" {
            $cmakeArch = "x64"
        }
        "x86" {
            $cmakeArch = "Win32"
        }
        "arm64" {
            $cmakeArch = "ARM64"
        }
        "arm" {
            $cmakeArch = "arm"
        }
    }
    $archLower = $Arch.ToLower()
    $cmakeConfig = "RelWithDebInfo"
    if ($BuildDebug) {
        $cmakeConfig = "Debug"
    }
    $lz4BuildDir = Join-Path $Lz4SourcesDir "cmake-build/$archLower"
    $lz4CmakeDir = Join-Path $Lz4SourcesDir "build/cmake"
    New-Dictoray $lz4BuildDir | Out-Host
    Write-TaskTip $TipGroup "Configuring..."
    Start-CliProcess "$cmakePath/bin/cmake.exe" -WorkingDirectory $lz4BuildDir `
        -ArgumentList "-DCMAKE_GENERATOR_PLATFORM=""$cmakeArch""", `
        "-DLZ4_BUILD_CLI=OFF", "-DLZ4_BUILD_LEGACY_LZ4C=OFF", `
        "-DBUILD_SHARED_LIBS=OFF", "-DBUILD_STATIC_LIBS=ON", "-S", $lz4CmakeDir -TipGroup $TipGroup | Out-Host
    Write-TaskTip $TipGroup "Building..."
    Start-CliProcess "$cmakePath/bin/cmake.exe" -WorkingDirectory $lz4BuildDir `
        -ArgumentList "--build", ".", "--config", $cmakeConfig, "--target", "lz4_static" -TipGroup $TipGroup | Out-Host
    return (Join-Path $lz4BuildDir $cmakeConfig)
}

function CopyToBuildDir
{
    [CmdletBinding()]
    Param(
        [string]$Lz4SourcesDir, 
        [string]$Lz4BuildDir, 
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
    $buildIncludeDir = "$BuildDir/include"
    New-Dictoray $buildIncludeDir
    Copy-Item -Path "$Lz4SourcesDir/lib/lz4.h" -Recurse -Destination $buildIncludeDir -Force
    Copy-Item -Path "$Lz4SourcesDir/lib/lz4file.h" -Recurse -Destination $buildIncludeDir -Force
    Copy-Item -Path "$Lz4SourcesDir/lib/lz4hc.h" -Recurse -Destination $buildIncludeDir -Force

    Write-TaskTip $TipGroup "Copying lib files..."
    $buildLibDir = "$buildArchDir/lib"
    New-Dictoray $buildLibDir
    Copy-Item -Path "$Lz4BuildDir/*" -Recurse -Destination $buildLibDir -Force
}

Write-StepTip $TipGroup "Geting v$Lz4Version sources..."
$lz4SourcesDir = GetSources
foreach ($arch in $Archs)
{
    Write-StepTip $TipGroup "Building v$Lz4Version $arch-debug..."
    $buildDebugArchDir = Build $lz4SourcesDir $arch -BuildDebug
    Write-StepTip $TipGroup "Building v$Lz4Version $arch-release..."
    $buildReleaseArchDir = Build $lz4SourcesDir $arch
    Write-StepTip $TipGroup "Copying v$Lz4Version $arch-debug files..."
    CopyToBuildDir $lz4SourcesDir $buildDebugArchDir $arch -BuildDebug
    Write-StepTip $TipGroup "Copying v$Lz4Version $arch-release files..."
    CopyToBuildDir $lz4SourcesDir $buildReleaseArchDir $arch
}