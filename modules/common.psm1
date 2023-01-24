function Get-CallerPreference
{
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ $_.GetType().FullName -eq 'System.Management.Automation.PSScriptCmdlet' })]
    $Cmdlet,
    [Parameter(Mandatory = $true)]
    [System.Management.Automation.SessionState]
    $SessionState
  )

  $vars = @{
    'ErrorView' = $null
    'ErrorActionPreference' = 'Continue'
    'VerbosePreference' = 'SilentlyContinue'
    'DebugPreference' = 'SilentlyContinue'
    'InformationPreference' = 'SilentlyContinue'
    'WarningPreference' = 'Continue'
    'WhatIfPreference' = $false
    'ConfirmPreference' = $true
  }

  foreach ($entry in $vars.GetEnumerator())
  {
    if ([string]::IsNullOrEmpty($entry.Value) -or -not $Cmdlet.MyInvocation.BoundParameters.ContainsKey($entry.Value))
    {
      $variable = $Cmdlet.SessionState.PSVariable.Get($entry.Key)
      if ($null -ne $variable)
      {
        if ($SessionState -eq $ExecutionContext.SessionState)
        {
          Set-Variable -Scope 1 -Name $variable.Name -Value $variable.Value -Force -Confirm:$false -WhatIf:$false
        }
        else
        {
          $SessionState.PSVariable.Set($variable.Name, $variable.Value)
        }
      }
    }
  }
}

function Write-EventPreference
{
    [CmdletBinding()]
    param()

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    return @{
        'ErrorView' = $ErrorView
        'ErrorActionPreference' = $ErrorActionPreference
        'VerbosePreference' = $VerbosePreference
        'DebugPreference' = $DebugPreference
        'InformationPreference' = $InformationPreference
        'WarningPreference' = $WarningPreference
        'WhatIfPreference' = $WhatIfPreference
        'ConfirmPreference' = $ConfirmPreference
    }
}

function Get-EventPreference
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable]
        $EventPreference,
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.SessionState]
        $SessionState
    )

    foreach ($entry in $EventPreference.GetEnumerator())
    {
        if ($SessionState -eq $ExecutionContext.SessionState)
        {
          Set-Variable -Scope 1 -Name $entry.Key -Value $entry.Value -Force -Confirm:$false -WhatIf:$false
        }
        else
        {
          $SessionState.PSVariable.Set($entry.Key, $entry.Value)
        }
    }
}

function Get-IsAmd64
{
    [CmdletBinding()]
    Param()
    
    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState | Write-Host

    return $Env:PROCESSOR_ARCHITECTURE -eq "AMD64"
}

function New-Dictoray
{
    [CmdletBinding()]
    Param([string]$Path, [switch]$CleanUp)

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    if(-not (Test-Path $Path -PathType container)) {
        New-Item $Path -Type Directory -Force | Out-Null
    } elseif ($CleanUp)
    {
        Remove-Item -Path "$Path/*" -Recurse -Force
    }
}

function Invoke-CheckHash
{
    [CmdletBinding()]
    Param([string]$Path, [string]$Sha1)

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState | Write-Host

    if (Test-Path $Path -PathType leaf) {
        $fileHash = Get-FileHash $Path -Algorithm SHA1
        return $fileHash -and ($fileHash.Hash -ieq $Sha1)
    }
    return $false
}

function Invoke-DownloadFiles
{
    [CmdletBinding()]
    Param([string]$Url, [string]$Sha1, [string]$OutFile, [string]$TipGroup=$null, [string]$TipMessage=$null)

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    if (-not (Invoke-CheckHash $OutFile $Sha1)) {
        if (($TipGroup -ne $null) -and ($TipMessage -ne $null)) {
            Write-TaskTip $TipGroup $TipMessage
        }
        Invoke-WebRequest -Uri $Url -OutFile $OutFile
        if (-not (Invoke-CheckHash $OutFile $Sha1)) {
            throw "Check file sum error."
        }
    }
}

function Start-CliProcess
{
    [CmdletBinding()]
    Param([string]$FilePath, [string[]]$ArgumentList=@(), [string]$WorkingDirectory=$null, [string]$TipGroup=$null)

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    if ($WorkingDirectory -eq $null) {
        $WorkingDirectory = $env:BuildScriptPath
    }
    $proc = [System.Diagnostics.Process]@{
        StartInfo = @{
            FileName = $FilePath
            Arguments = $ArgumentList
            RedirectStandardOutput = $true
            RedirectStandardError = $true
            UseShellExecute = $false
            WorkingDirectory = $WorkingDirectory
        }
    }
    $stdoutEvent = $null
    $stderrEvent = $null
    $exitedEvent = $null
    $messageData = @{
        EventPreference = Write-EventPreference
        TipGroup = $TipGroup
    }
    try {
        $stdoutEvent = Register-ObjectEvent $proc -EventName "OutputDataReceived" -MessageData $messageData -Action {
            Get-EventPreference -EventPreference $Event.MessageData.EventPreference -SessionState $ExecutionContext.SessionState

            Write-VerboseTip $Event.MessageData.TipGroup $Event.SourceEventArgs.Data
        }

        $stderrEvent = Register-ObjectEvent $proc -EventName "ErrorDataReceived" -MessageData $messageData -Action {
            Get-EventPreference -EventPreference $Event.MessageData.EventPreference -SessionState $ExecutionContext.SessionState

            $message = $Event.SourceEventArgs.Data
            if ((-not ($message -match "^#< ")) -and (-not ($message -match "</Objs>$")) -and (-not ($message -match "^\s*$"))) {
                if ($null -ne $Event.MessageData.TipGroup) {
                    Write-ErrorTip $Event.MessageData.TipGroup $message
                }
            }
        }
        
        $exitedSourceIdentifier = New-Guid
        $exitedEvent = Register-ObjectEvent $proc -EventName "Exited" -SourceIdentifier $exitedSourceIdentifier

        $proc.Start() | Out-Null
        $proc.BeginOutputReadLine() | Out-Null
        $proc.BeginErrorReadLine() | Out-Null
        Wait-Event $exitedSourceIdentifier | Out-Null

    } finally {
        try {
            if ($null -ne $stdoutEvent) { Unregister-Event $stdoutEvent.Id }
        } catch {}
        try {
            if ($null -ne $stderrEvent) { Unregister-Event $stderrEvent.Id }
        } catch {}
        try {
            if ($null -ne $exitedEvent) { Unregister-Event $exitedEvent.Id }
        } catch {}
    }

    $exitCode = -1
    if ($proc.HasExited) {
        $exitCode = $proc.ExitCode
    }
    if ($exitCode -ne 0) {
        throw "Exit with error code: $exitCode"
    }
}

function Start-GitProcess
{
    [CmdletBinding()]
    Param([string[]]$ArgumentList=@(), [string]$WorkingDirectory=$null, [string]$TipGroup=$null)

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    if ($WorkingDirectory -eq $null) {
        $WorkingDirectory = $env:BuildScriptPath
    }
    $proc = [System.Diagnostics.Process]@{
        StartInfo = @{
            FileName = "git"
            Arguments = $ArgumentList
            RedirectStandardError = $true
            UseShellExecute = $false
            WorkingDirectory = $WorkingDirectory
        }
    }
    $stderrEvent = $null
    $exitedEvent = $null
    $messageData = @{
        EventPreference = Write-EventPreference
        TipGroup = $TipGroup
    }
    try {
        $stderrEvent = Register-ObjectEvent $proc -EventName "ErrorDataReceived" -MessageData $messageData -Action {
            Get-EventPreference -EventPreference $Event.MessageData.EventPreference -SessionState $ExecutionContext.SessionState

            $message = $Event.SourceEventArgs.Data
            if ($message -match '^(?<CurrentOperation>[a-zA-Z\s:]+):\s+(?<PercentComplete>[0-9]+)%\s(?<Status>.*)$') {
                $completed = $Matches.Status -match "done.$"
                if (-not $completed) {
                    $ProgressParameters = @{
                        Activity         = "Git: " + $firstMessage
                        Status           = $Matches.PercentComplete + "% " + $Matches.Status
                        PercentComplete  = $Matches.PercentComplete
                        CurrentOperation = $Matches.CurrentOperation
                    }
                }
                Write-Progress @ProgressParameters -Completed:$completed
            } else {
                if ($null -eq $firstMessage) {
                    $firstMessage = $message
                }
                Write-VerboseTip $Event.MessageData.TipGroup $message
            }
        }
        
        $exitedSourceIdentifier = New-Guid
        $exitedEvent = Register-ObjectEvent $proc -EventName "Exited" -SourceIdentifier $exitedSourceIdentifier

        $proc.Start() | Out-Null
        $proc.BeginErrorReadLine() | Out-Null
        Wait-Event $exitedSourceIdentifier | Out-Null
    } finally {
        try {
            if ($stderrEvent) { Unregister-Event $stderrEvent.Id }
        } catch {}
        try {
            if ($exitedEvent) { Unregister-Event $exitedEvent.Id }
        } catch {}
    }

    $exitCode = -1
    if ($proc.HasExited) {
        $exitCode = $proc.ExitCode
    }
    if ($exitCode -ne 0) {
        throw "Git exit with error code: $exitCode"
    }
}

function Start-7zProcess
{
    [CmdletBinding()]
    Param(
        [ValidateSet("a", "b", "d", "e", "h", "i", "l", "rn", "t", "u", "x")]
        [string]$Command,
        [string]$ArchiveName,
        [string[]]$FileNames=@(),
        [string[]]$Switches=@(),
        [string]$WorkingDirectory=$null,
        [string]$TipGroup=$null
    )

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    if ($WorkingDirectory -eq $null) {
        $WorkingDirectory = $env:BuildScriptPath
    }

    [System.Collections.Generic.List[String]]$argumentList = @($Command, "-bb0", "-aoa", "-bt", "-bsp1")
    foreach($switch in $Switches)
    {
        $argumentList.Add("-$switch")
    }
    $argumentList.Add($ArchiveName)
    foreach($fileName in $FileNames)
    {
        $argumentList.Add($fileName)
    }
    $proc = [System.Diagnostics.Process]@{
        StartInfo = @{
            FileName = "7z"
            Arguments = $argumentList
            RedirectStandardOutput = $true
            RedirectStandardError = $true
            UseShellExecute = $false
            WorkingDirectory = $WorkingDirectory
        }
    }
    $stdoutEvent = $null
    $stderrEvent = $null
    $exitedEvent = $null
    $messageData = @{
        EventPreference = Write-EventPreference
        TipGroup = $TipGroup
    }
    try {
        $stdoutEvent = Register-ObjectEvent $proc -EventName "OutputDataReceived" -MessageData $messageData -Action {
            Get-EventPreference -EventPreference $Event.MessageData.EventPreference -SessionState $ExecutionContext.SessionState

            $message = $Event.SourceEventArgs.Data
            if ($message -match '^\s*(?<PercentComplete>[0-9]+)%(\s(?<ExecutionTime>[0-9]+))?(\s(-\s)?(?<Status>.*))?$') {
                if (-not $completed) {
                    $secondsRemaining = -1
                    if ($null -ne $Matches.ExecutionTime -and $Matches.PercentComplete -ge 0) {
                        $secondsRemaining = (100 - $Matches.PercentComplete) * $Matches.ExecutionTime / $Matches.PercentComplete / 100
                    }
                    $ProgressParameters = @{
                        Activity         = "7z: " + $activityMessage
                        Status           = $Matches.PercentComplete + "% " + $Matches.Status
                        PercentComplete  = $Matches.PercentComplete
                        SecondsRemaining = $secondsRemaining
                    }
                }
                Write-Progress @ProgressParameters
            } else {
                if (($message -match '^(?<ActivityMessage>[a-zA-Z\s]+:\s.*)$') -and ($null -eq $activityMessage)) {
                    $activityMessage = $Matches.ActivityMessage
                }
                if ($message -eq "Everything is Ok") {
                    Write-Progress @ProgressParameters -Completed
                }
                if (-not ($message -match "^\s*$")) {
                    Write-VerboseTip $Event.MessageData.TipGroup $message
                }
            }
        }

        $stderrEvent = Register-ObjectEvent $proc -EventName "ErrorDataReceived" -MessageData $messageData -Action {
            Get-EventPreference -EventPreference $Event.MessageData.EventPreference -SessionState $ExecutionContext.SessionState
            
            if ($null -ne $Event.MessageData.TipGroup) {
                Write-ErrorTip $Event.MessageData.TipGroup $Event.SourceEventArgs.Data
            }
        }
        
        $exitedSourceIdentifier = New-Guid
        $exitedEvent = Register-ObjectEvent $proc -EventName "Exited" -SourceIdentifier $exitedSourceIdentifier

        $proc.Start() | Out-Null
        $proc.BeginOutputReadLine() | Out-Null
        $proc.BeginErrorReadLine() | Out-Null
        Wait-Event $exitedSourceIdentifier | Out-Null

    } finally {
        try {
            if ($stdoutEvent) { Unregister-Event $stdoutEvent.Id }
        } catch {}
        try {
            if ($stderrEvent) { Unregister-Event $stderrEvent.Id }
        } catch {}
        try {
            if ($exitedEvent) { Unregister-Event $exitedEvent.Id }
        } catch {}
    }

    $exitCode = -1
    if ($proc.HasExited) {
        $exitCode = $proc.ExitCode
    }
    if ($exitCode -ne 0) {
        throw "7z exit with error code: $exitCode"
    }
}

function Invoke-ExecuteCommand
{
    [CmdletBinding()]
    Param([string]$Command, [string]$WorkingDirectory=$null, [string]$TipGroup=$null)

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    if ($null -eq $WorkingDirectory) {
        $WorkingDirectory = $env:BuildScriptPath
    }
    $PowerShellPath = (Get-Process -PID ${PID}).Path
    $Command = "
        Import-Module ""$env:BuildScriptModulesPath/common"" -DisableNameChecking -Verbose:`$false
        $Command
    "
    Start-CliProcess $PowerShellPath -WorkingDirectory $WorkingDirectory -ArgumentList "-EncodedCommand",
    ([Convert]::ToBase64String(
        [Text.Encoding]::Unicode.GetBytes($Command)
    )) -TipGroup $TipGroup
}

function Invoke-CloneGit
{
    [CmdletBinding()]
    Param([string]$Url, [string]$Tag, [string]$OutFile, [string]$TipGroup=$null, [string]$TipName=$null)

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    if (Test-Path $OutFile -PathType container) {
        if (-not (Test-Path "$OutFile/.git" -PathType container)) {
            Remove-Item -Path $OutFile -Recurse
            if (($TipGroup -ne $null) -and ($TipName -ne $null)) {
                Write-TaskTip $TipGroup "Clone repository $TipName..."
            }
            Start-GitProcess -WorkingDirectory $env:BuildScriptPath -TipGroup $TipGroup `
                -ArgumentList "clone",$Url,$OutFile,"-v","--progress"
            
        } else {
            if (($TipGroup -ne $null) -and ($TipName -ne $null)) {
                Write-TaskTip $TipGroup "Reset repository $TipName..."
            }
            Start-GitProcess -WorkingDirectory $OutFile -TipGroup $TipGroup `
                -ArgumentList "reset","HEAD","*"
            Start-GitProcess -WorkingDirectory $OutFile -TipGroup $TipGroup `
                -ArgumentList "fetch","-f"
        }
    } else {
        if (($TipGroup -ne $null) -and ($TipName -ne $null)) {
             Write-TaskTip $TipGroup "Clone repository $TipName..."
        }
        Start-GitProcess -WorkingDirectory $env:BuildScriptPath -TipGroup $TipGroup `
            -ArgumentList "clone",$Url,$OutFile,"-v","--progress"
    }
    if (($TipGroup -ne $null) -and ($TipName -ne $null)) {
        Write-TaskTip $TipGroup "Switch repository $TipName to tag ""$Tag""..."
    }
    Start-GitProcess -WorkingDirectory $OutFile -TipGroup $TipGroup `
        -ArgumentList "checkout","tags/$Tag","-f","--progress"
}

function Expand-Archive-7z
{
    [CmdletBinding()]
    Param([string]$Path, [string]$DestinationPath=$null, [string[]]$FileNames=@(), [string]$TipGroup=$null)

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    if ($DestinationPath -ne $null) {
        Start-7zProcess x $Path $FileNames "o""$DestinationPath""" -TipGroup $TipGroup
    } else {
        Start-7zProcess x $Path $FileNames -TipGroup $TipGroup
    }
}

function Get-HasParameter
{
    [CmdletBinding()]
    Param([string]$Cmdlet, [string]$Parameter)

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    $parameters = (Get-Command -Name $Cmdlet).Parameters
    return $parameters.ContainsKey($Parameter)
}

function Write-StepTip
{
    [CmdletBinding()]
    Param([string]$Group, [string]$Message)

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    Write-Host "[$Group]*$Message" -ForegroundColor Green
}

function Write-TaskTip
{
    [CmdletBinding()]
    Param([string]$Group, [string]$Message)

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    Write-Host "[$Group]+$Message" -ForegroundColor Blue
}

function Write-ErrorTip
{
    [CmdletBinding()]
    Param([string]$Group, [string]$Message)

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    Write-Host "[$Group]$Message" -ForegroundColor Red
}

function Write-VerboseTip {
    [CmdletBinding()]
    Param([string]$Group, [string]$Message)

    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
    
    Write-Verbose "[$Group]$Message"
}