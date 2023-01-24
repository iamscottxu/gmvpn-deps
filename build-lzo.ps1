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

$TipGroup = "lzo"

function GetSources 
{
    [CmdletBinding()]
    Param()

    $fileName = "lzo-$LzoVersion"
    $destinationPath = "$SourcesDir/$fileName"
    if (Test-Path "$destinationPath/CMakeLists.txt" -PathType leaf) {
        return $destinationPath
    }
    New-Dictoray $DownloadsDir | Out-Host
    Write-TaskTip $TipGroup "Find sources..."
    Invoke-DownloadFiles -Url "http://www.oberhumer.com/opensource/lzo/download/$fileName.tar.gz" `
        -Sha1 $LzoSourceSha1 -OutFile "$DownloadsDir/$fileName.tar.gz" `
        -TipGroup $TipGroup -TipMessage "Downloading sources..." | Out-Host
    New-Dictoray $destinationPath -CleanUp | Out-Host
    Write-TaskTip $TipGroup "Expanding sources archive..."
    Expand-Archive-7z "$DownloadsDir/$fileName.tar.gz" -DestinationPath $destinationPath -TipGroup $TipGroup | Out-Host
    Expand-Archive-7z "$destinationPath/$fileName.tar" -DestinationPath $destinationPath -TipGroup $TipGroup | Out-Host
    Remove-Item -Path "$destinationPath/$fileName.tar" -Force | Out-Host
    Move-Item "$destinationPath/$fileName/*" $destinationPath -Force | Out-Host
    Remove-Item -Path "$destinationPath/$fileName" -Recurse -Force | Out-Host
    return $destinationPath
}

function Build 
{
    [CmdletBinding()]
    Param(
        [string]$LzoSourcesDir, 
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
    $lzoBuildDir = Join-Path $LzoSourcesDir "cmake-build/$archLower"
    New-Dictoray $lzoBuildDir | Out-Host
    Write-TaskTip $TipGroup "Configuring..."
    Start-CliProcess "$cmakePath/bin/cmake.exe" -WorkingDirectory $lzoBuildDir `
        -ArgumentList "-DCMAKE_GENERATOR_PLATFORM=""$cmakeArch""", "-S", $LzoSourcesDir -TipGroup $TipGroup | Out-Host
    Write-TaskTip $TipGroup "Building..."
    Start-CliProcess "$cmakePath/bin/cmake.exe" -WorkingDirectory $lzoBuildDir `
        -ArgumentList "--build", ".", "--config", $cmakeConfig, "--target", "lzo_static_lib" -TipGroup $TipGroup | Out-Host
    return (Join-Path $lzoBuildDir $cmakeConfig)
}

function CopyToBuildDir
{
    [CmdletBinding()]
    Param(
        [string]$LzoSourcesDir, 
        [string]$LzoBuildDir, 
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
    Copy-Item -Path "$LzoSourcesDir/include" -Recurse -Destination $BuildDir -Force

    Write-TaskTip $TipGroup "Copying lib files..."
    $buildLibDir = "$buildArchDir/lib"
    New-Dictoray $buildLibDir
    Copy-Item -Path "$LzoBuildDir/*" -Recurse -Destination $buildLibDir -Force
}

Write-StepTip $TipGroup "Geting v$LzoVersion sources..."
$lzoSourcesDir = GetSources
foreach ($arch in $Archs)
{
    Write-StepTip $TipGroup "Building v$LzoVersion $arch-debug..."
    $buildDebugArchDir = Build $lzoSourcesDir $arch -BuildDebug
    Write-StepTip $TipGroup "Building v$LzoVersion $arch-release..."
    $buildReleaseArchDir = Build $lzoSourcesDir $arch
    Write-StepTip $TipGroup "Copying v$LzoVersion $arch-debug files..."
    CopyToBuildDir $lzoSourcesDir $buildDebugArchDir $arch -BuildDebug
    Write-StepTip $TipGroup "Copying v$LzoVersion $arch-release files..."
    CopyToBuildDir $lzoSourcesDir $buildReleaseArchDir $arch
}