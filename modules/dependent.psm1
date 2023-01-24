Import-Module "$env:BuildScriptModulesPath/environment" -DisableNameChecking -Verbose:$false
Import-Module "$env:BuildScriptModulesPath/common" -DisableNameChecking -Verbose:$false

$BashScriptPath = Join-Path $env:BuildScriptPath "bash"

$DepsPathTable = @{}

function Invoke-DownloadDeps-Perl
{
    [CmdletBinding()]
    Param([string]$TipGroup = $null)

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState | Out-Host

    $fileName = ""
    $sha1 = ""
    $myTipGroup = "Perl"
    if ($TipGroup -ne $null) {
        $myTipGroup = $TipGroup
    }
    if (Get-IsAmd64) {
        $fileName = "strawberry-perl-$PerlVersion-64bit"
        $sha1 = $PerlSha1Amd64
    } else {
        $fileName = "strawberry-perl-$PerlVersion-32bit"
        $sha1 = $PerlSha1X86
    }
    $destinationPath = Join-Path $DependentsDir $fileName
    if (Test-Path "$destinationPath/perl/bin/perl.exe" -PathType leaf) {
        return $destinationPath
    }

    $DownloadTipParameters = @{
        TipGroup = $myTipGroup
        TipMessage = "Downloading..."
    }
    if ($TipGroup -ne $null) {
        $DownloadTipParameters.TipMessage = "Downloading dependent ""Perl""..."
    }
    New-Dictoray $DownloadsDir | Out-Host
    Invoke-DownloadFiles -Url "https://strawberryperl.com/download/$PerlVersion/$fileName.zip" `
        -Sha1 $sha1 -OutFile "$DownloadsDir/$fileName.zip" @DownloadTipParameters | Out-Host
    New-Dictoray $destinationPath -CleanUp | Out-Host
    if ($TipGroup -eq $null) {
        Write-StepTip $myTipGroup "Expanding archive..."
    } else {
        Write-TaskTip $myTipGroup "Expanding ""Perl"" archive..."
    }
    Expand-Archive-7z "$DownloadsDir/$fileName.zip" -DestinationPath $destinationPath -TipGroup $myTipGroup | Out-Host
    return $destinationPath
}

function Invoke-DownloadDeps-Nasm
{
    [CmdletBinding()]
    Param([string]$TipGroup = $null)

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState | Out-Host

    $fileArch = ""
    $sha1 = ""
    $myTipGroup = "Nasm"
    if ($TipGroup -ne $null) {
        $myTipGroup = $TipGroup
    }
    if (Get-IsAmd64) {
        $fileArch = "win64"
        $sha1 = $NasmSha1Amd64
    } else {
        $fileArch = "win32"
        $sha1 = $NasmSha1X86
    }
    $fileName = "nasm-$NasmVersion-$fileArch"
    $destinationPath = Join-Path $DependentsDir $fileName
    if (Test-Path "$destinationPath/nasm.exe" -PathType leaf) {
        return $destinationPath
    }

    $DownloadTipParameters = @{
        TipGroup = $myTipGroup
        TipMessage = "Downloading..."
    }
    if ($TipGroup -ne $null) {
        $DownloadTipParameters.TipMessage = "Downloading dependent ""Nasm""..."
    }
    New-Dictoray $DownloadsDir | Out-Host
    Invoke-DownloadFiles -Url "https://www.nasm.us/pub/nasm/releasebuilds/$NasmVersion/$FileArch/$fileName.zip" `
        -Sha1 $sha1 -OutFile "$DownloadsDir/$fileName.zip" @DownloadTipParameters | Out-Host
    New-Dictoray $destinationPath -CleanUp | Out-Host
    if ($TipGroup -eq $null) {
        Write-StepTip $myTipGroup "Expanding archive..."
    } else {
        Write-TaskTip $myTipGroup "Expanding ""Nasm"" archive..."
    }
    Expand-Archive-7z "$DownloadsDir/$fileName.zip" -DestinationPath $destinationPath -TipGroup $TipGroup -TipGroup $myTipGroup | Out-Host
    Move-Item "$destinationPath/nasm-$NasmVersion/*" $destinationPath -Force | Out-Host
    Remove-Item -Path "$destinationPath/nasm-$NasmVersion" -Recurse -Force | Out-Host
    return $destinationPath
}

function Invoke-DownloadDeps-CMake
{
    [CmdletBinding()]
    Param([string]$TipGroup = $null)

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState | Out-Host

    $fileName = ""
    $sha1 = ""
    $myTipGroup = "CMake"
    if ($TipGroup -ne $null) {
        $myTipGroup = $TipGroup
    }
    if (Get-IsAmd64) {
        $fileName = "cmake-$CMakeVersion-windows-x86_64"
        $sha1 = $CMakeSha1Amd64
    } else {
        $fileName = "cmake-$CMakeVersion-windows-i386"
        $sha1 = $CMakeSha1X86
    }
    $destinationPath = Join-Path $DependentsDir $fileName
    if (Test-Path "$destinationPath/bin/cmake.exe" -PathType leaf) {
        return $destinationPath
    }

    $DownloadTipParameters = @{
        TipGroup = $myTipGroup
        TipMessage = "Downloading..."
    }
    if ($TipGroup -ne $null) {
        $DownloadTipParameters.TipMessage = "Downloading dependent ""CMake""..."
    }
    New-Dictoray $DownloadsDir | Out-Host
    Invoke-DownloadFiles -Url "https://github.com/Kitware/CMake/releases/download/v$CMakeVersion/$fileName.zip" `
        -Sha1 $sha1 -OutFile "$DownloadsDir/$fileName.zip" @DownloadTipParameters | Out-Host
    New-Dictoray $destinationPath -CleanUp | Out-Host
    if ($TipGroup -eq $null) {
        Write-StepTip $myTipGroup "Expanding archive..."
    } else {
        Write-TaskTip $myTipGroup "Expanding ""CMake"" archive..."
    }
    Expand-Archive-7z "$DownloadsDir/$fileName.zip" -DestinationPath $destinationPath -TipGroup $myTipGroup | Out-Host
    Move-Item "$destinationPath/$fileName/*" $destinationPath -Force | Out-Host
    Remove-Item -Path "$destinationPath/$fileName" -Recurse -Force | Out-Host
    return $destinationPath
}

function Invoke-DownloadDeps-Msys2
{
    [CmdletBinding()]
    Param([string]$TipGroup = $null)

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState | Out-Host
    
    $myTipGroup = "Msys2"
    if ($TipGroup -ne $null) {
        $myTipGroup = $TipGroup
    }
    $fileName = "msys2-base-x86_64-" + $Msys2Version.Replace("-", "")
    $destinationPath = Join-Path $DependentsDir $fileName
    $msys2ShellPath = Join-Path $destinationPath "msys2_shell.cmd"
    if (Test-Path $msys2ShellPath -PathType leaf) {
        return $destinationPath
    }

    $DownloadTipParameters = @{
        TipGroup = $myTipGroup
        TipMessage = "Downloading..."
    }
    if ($TipGroup -ne $null) {
        $DownloadTipParameters.TipMessage = "Downloading dependent ""Msys2""..."
    }
    New-Dictoray $DownloadsDir | Out-Host
    Invoke-DownloadFiles -Url "https://github.com/msys2/msys2-installer/releases/download/$Msys2Version/$fileName.tar.xz" `
        -Sha1 $Msys2Sha1 -OutFile "$DownloadsDir/$fileName.tar.xz" @DownloadTipParameters | Out-Host
    New-Dictoray $destinationPath -CleanUp | Out-Host
    if ($TipGroup -eq $null) {
        Write-StepTip $myTipGroup "Expanding archive..."
    } else {
        Write-TaskTip $myTipGroup "Expanding ""Msys2"" archive..."
    }
    Expand-Archive-7z "$DownloadsDir/$fileName.tar.xz" -DestinationPath $destinationPath -TipGroup $myTipGroup | Out-Host
    Expand-Archive-7z "$destinationPath/$fileName.tar" -DestinationPath $destinationPath -TipGroup $myTipGroup | Out-Host
    Remove-Item -Path "$destinationPath/$fileName.tar" -Recurse -Force | Out-Host
    Move-Item "$destinationPath/msys64/*" $destinationPath -Force | Out-Host
    Remove-Item -Path "$destinationPath/msys64" -Recurse -Force | Out-Host
    if ($TipGroup -eq $null) {
        Write-StepTip $myTipGroup "Init..."
    } else {
        Write-TaskTip $myTipGroup "Init dependent ""Msys2""..."
    }
    Invoke-ExecuteCommand "
        `$Env:MSYS2_NOSTART = 1
        &""$msys2ShellPath"" -msys -defterm ""$BashScriptPath/exit.sh""
        &""$msys2ShellPath"" -msys -defterm ""$BashScriptPath/install-deps.sh""
    " -TipGroup $myTipGroup | Out-Host
    return $destinationPath
}

function Invoke-DownloadDeps
{
    [CmdletBinding()]
    Param([string]$Deps, [string]$TipGroup = $null)

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState | Out-Host

    if ($TipGroup -eq $null) {
        Write-StepTip "$Deps" "Find..."
    } else {
        Write-TaskTip "$TipGroup" "Find dependent ""$Deps""..."
    }
    if ($DepsPathTable.Contains($Deps)) {
        return $DepsPathTable[$Deps]
    }
    $depsPath = &"Invoke-DownloadDeps-$Deps" -TipGroup $TipGroup
    $DepsPathTable[$Deps] = $depsPath
    return $depsPath
}

function Get-VsSetupConfigurations 
{
    [CmdletBinding()]
    Param([string]$WhereArgs="")

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState | Out-Host

    $expression = "& `"$VsWherePath`" $WhereArgs -format json"
    Invoke-Expression $expression | ConvertFrom-Json
}

function Get-VsDevShellPath
{
    [CmdletBinding()]
    Param([string]$WhereArgs="")

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState | Out-Host
    
    $configs = Get-VsSetupConfigurations $WhereArgs
    $productPath = Split-Path $configs.productPath
    $vsDevShellPath = Join-Path $productPath "../Tools/Launch-VsDevShell.ps1"
    return (Get-Item $vsDevShellPath).FullName
}