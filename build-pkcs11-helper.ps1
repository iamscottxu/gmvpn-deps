[CmdletBinding()]
Param(
    [ValidateSet("amd64", "x86", "arm64", "arm")]
    [string[]]$Archs = $Env:PROCESSOR_ARCHITECTURE,
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

$TipGroup = "pkcs11-helper"

$SslLibraryName = "openssl"
$SslLibraryVersion = $OpensslVersion
if ($UseTongsuo) {
    $SslLibraryName = "tongsuo"
    $SslLibraryVersion = $TongsuoVersion
}
$SslLibraryBuildScript = Join-Path $env:BuildScriptPath "build-$SslLibraryName.ps1"
#$BashScriptPath = Join-Path $env:BuildScriptPath "bash"

function GetSources 
{
    [CmdletBinding()]
    Param()

    $fileName = "pkcs11-helper-$Pkcs11HelperVersion"
    $destinationPath = "$SourcesDir/$fileName"
    if (Test-Path "$destinationPath/Makefile.am" -PathType leaf) {
        return $destinationPath
    }
    New-Dictoray $DownloadsDir | Out-Host
    Write-TaskTip $TipGroup "Find sources..."
    Invoke-DownloadFiles -Url "https://github.com/OpenSC/pkcs11-helper/releases/download/pkcs11-helper-$Pkcs11HelperVersion/$fileName.tar.bz2" `
    -Sha1 $Pkcs11HelperSourceSha1 -OutFile "$DownloadsDir/$fileName.tar.bz2" `
    -TipGroup $TipGroup -TipMessage "Downloading sources..." | Out-Host
    New-Dictoray $destinationPath -CleanUp | Out-Host
    Write-TaskTip $TipGroup "Expanding sources archive..."
    Expand-Archive-7z "$DownloadsDir/$fileName.tar.bz2" -DestinationPath $destinationPath -TipGroup $TipGroup | Out-Host
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
        [string]$Pkcs11HelperSourcesDir, 
        [ValidateSet("amd64", "x86", "arm64", "arm")]
        [string]$Arch,
        [switch]$BuildDebug)

    $vsDevShellPath = Get-VsDevShellPath
    $hostArch = "x86"
    if (Get-IsAmd64) {
        $hostArch = "amd64"
    }
    $archLower = $Arch.ToLower()
    $pkcs11HelperInstallDir = Join-Path $InstallDir "pkcs11-helper-$Pkcs11HelperVersion-$archLower"
    $sslLibraryInstallDir = Join-Path $InstallDir "$SslLibraryName-$SslLibraryVersion-$archLower"
    $VisualCppClParams = "/nologo /W3 /FD /c /Zi"
    $VisualCppLinkParams = "/nologo /subsystem:windows /dll /incremental:no /debug /manifest"
    if ($BuildDebug) {
        $pkcs11HelperInstallDir = "$pkcs11HelperInstallDir-debug"
        $sslLibraryInstallDir = "$sslLibraryInstallDir-debug"
        $VisualCppClParams = "$VisualCppClParams /Ob0 /Od /MDd /RTC1"
    } else {
        $pkcs11HelperInstallDir = "$pkcs11HelperInstallDir-release"
        $sslLibraryInstallDir = "$sslLibraryInstallDir-release"
        $VisualCppClParams = "$VisualCppClParams /Ob1 /O2 /MD"
    }
    if (-not (Test-Path (Join-Path $sslLibraryInstallDir "lib/libcrypto.lib") -PathType leaf)) {
        &"$SslLibraryBuildScript" -Archs $Arch
    }

    $pkcs11HelperSourcesLibDir = Join-Path $Pkcs11HelperSourcesDir "lib"
    Write-TaskTip $TipGroup "Cleaning..."
    Remove-Item -Path "$pkcs11HelperSourcesLibDir/*.obj" -Force | Out-Host
    Remove-Item -Path "$pkcs11HelperSourcesLibDir/*.res" -Force | Out-Host
    Remove-Item -Path "$pkcs11HelperSourcesLibDir/*.dll" -Force | Out-Host
    Remove-Item -Path "$pkcs11HelperSourcesLibDir/*.lib" -Force | Out-Host
    Remove-Item -Path "$pkcs11HelperSourcesLibDir/*.pdb" -Force | Out-Host
    Remove-Item -Path "$pkcs11HelperSourcesLibDir/*.def" -Force | Out-Host
    Write-TaskTip $TipGroup "Building..."
    Invoke-ExecuteCommand "
        &""$vsDevShellPath"" -Arch $Arch -HostArch $hostArch
        Set-Location ""$pkcs11HelperSourcesLibDir""
        nmake -f Makefile.w32-vc libpkcs11-helper-1.dll OPENSSL=1 ``
         OPENSSL_HOME=""$sslLibraryInstallDir"" CCPARAMS=""$VisualCppClParams"" ``
         LINK32_FLAGS=""$VisualCppLinkParams"" /NOLOGO
    " -TipGroup $TipGroup | Out-Host
    return $pkcs11HelperSourcesLibDir
}

<#
function BuildMsys2
{
    [CmdletBinding()]
    Param(
        [string]$Pkcs11HelperSourcesDir, 
        [ValidateSet("amd64", "x86", "arm64", "arm")]
        [string]$Arch,
        [switch]$BuildDebug)

    $msys2Path = Invoke-DownloadDeps "Msys2"
    
    $vsDevShellPath = Get-VsDevShellPath
    $hostArch = "x86"
    if (Get-IsAmd64) {
        $hostArch = "amd64"
    }
    $archLower = $Arch.ToLower()
    $pkcs11HelperInstallDir = Join-Path $InstallDir "pkcs11-helper-$Pkcs11HelperVersion-$archLower"
    $opensslInstallDir = Join-Path $InstallDir "openssl-$OpensslVersion-$archLower"
    if ($BuildDebug) {
        $pkcs11HelperInstallDir = "$pkcs11HelperInstallDir-debug"
        $opensslInstallDir = "$opensslInstallDir-debug"
    } else {
        $pkcs11HelperInstallDir = "$pkcs11HelperInstallDir-release"
        $opensslInstallDir = "$opensslInstallDir-release"
    }
    if (-not (Test-Path (Join-Path $opensslInstallDir "lib/libcrypto.lib") -PathType leaf)) {
        &"$OpensslBuildScript" -Archs $Arch
    }

    $opensslInstallDirMsys = "/" + $opensslInstallDir.Replace(":", "").Replace("\", "/")
    $pkcs11HelperInstallDirMsys = "/" + $pkcs11HelperInstallDir.Replace(":", "").Replace("\", "/")
    New-Dictoray $pkcs11HelperInstallDir -CleanUp | Out-Host
    Invoke-ExecuteCommand "
        &""$vsDevShellPath"" -Arch $Arch -HostArch $hostArch
        Set-Location ""$Pkcs11HelperSourcesDir""
        `$Env:OpensslInstallDir = ""$opensslInstallDirMsys""
        `$Env:Pkcs11HelperInstallDir = ""$pkcs11HelperInstallDirMsys""
        `$Env:MSYS2_NOSTART = 1
        &""$msys2Path/msys2_shell.cmd"" -use-full-path -msys -defterm -here ""$BashScriptPath/build-pkcs11-helper.sh""
    " -TipGroup $TipGroup | Out-Host
    return $pkcs11HelperInstallDir
}
#>

function CopyToBuildDir
{
    [CmdletBinding()]
    Param(
        [string]$Pkcs11HelperSourcesDir, 
        [string]$Pkcs11HelperBuildDir, 
        [ValidateSet("amd64", "x86", "arm64", "arm")]
        [string]$Arch,
        [switch]$BuildDebug
    )
    $dirSuffix = "release"
    if ($BuildDebug) {
        $dirSuffix = "debug"
    }
    $buildArchDir = $BuildArchDirs[$Arch] + "-$dirSuffix"
    $pkcs11HelperBuildIncludeDir = "$BuildDir/include/pkcs11-helper-1.0"

    Write-TaskTip $TipGroup "Copying include files..."
    New-Dictoray $pkcs11HelperBuildIncludeDir
    Copy-Item -Filter "*.h" -Path "$Pkcs11HelperSourcesDir/include/pkcs11-helper-1.0/*" -Recurse -Destination $pkcs11HelperBuildIncludeDir -Force

    Write-TaskTip $TipGroup "Copying bin files..."
    $buildBinDir = "$buildArchDir/bin"
    New-Dictoray $buildBinDir
    Copy-Item -Filter "*.dll" -Path "$Pkcs11HelperBuildDir/*" -Recurse -Destination $buildBinDir -Force
    Copy-Item -Filter "*.pdb" -Exclude "vc140.pdb" -Path "$Pkcs11HelperBuildDir/*" -Recurse -Destination $buildBinDir -Force

    Write-TaskTip $TipGroup "Copying lib files..."
    $buildLibDir = "$buildArchDir/lib"
    New-Dictoray $buildLibDir
    Copy-Item -Filter "*.lib" -Path "$Pkcs11HelperBuildDir/*" -Recurse -Destination $buildLibDir -Force
}

Write-StepTip $TipGroup "Geting v$Pkcs11HelperVersion sources..."
$pkcs11HelperSourcesDir = GetSources
foreach ($arch in $Archs)
{
    Write-StepTip $TipGroup "Building v$Pkcs11HelperVersion $arch-debug..."
    $buildArchDir = Build $pkcs11HelperSourcesDir $arch -BuildDebug
    Write-StepTip $TipGroup "Copying v$Pkcs11HelperVersion $arch-debug files..."
    CopyToBuildDir $pkcs11HelperSourcesDir $buildArchDir $arch -BuildDebug
    Write-StepTip $TipGroup "Building v$Pkcs11HelperVersion $arch-release..."
    $buildArchDir = Build $pkcs11HelperSourcesDir $arch
    Write-StepTip $TipGroup "Copying v$Pkcs11HelperVersion $arch-release files..."
    CopyToBuildDir $pkcs11HelperSourcesDir $buildArchDir $arch
}