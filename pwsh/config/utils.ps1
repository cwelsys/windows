# 🔗 Aliases
Set-Alias -Name 'which' -Value Get-CommandInfo
Set-Alias -Name 'rl' -Value reload
Set-Alias -Name 'rst' -Value restart
Set-Alias -Name 'touch' -Value New-File
Set-Alias -Name 'mkcd' -Value 'New-Directory'
Set-Alias -Name 'ff' -Value 'Find-File'
Set-Alias -Name 'grep' -Value 'Find-String'
Remove-Item Alias:rm -Force -ErrorAction SilentlyContinue
Set-Alias -Name 'rm' -Value 'Remove-MyItem'
Set-Alias -Name 'lg' -Value lazygit
Set-Alias -Name 'vim' -Value nvim
Set-Alias -Name 'su' -Value gsudo
Set-Alias -Name 'vi' -Value nvim
Set-Alias -Name 'c' -Value clear
Set-Alias -Name 'df' -Value Get-Volume
Set-Alias -Name 'spongob' -Value Invoke-Spongebob

# 🏖️ Functions
function e { Invoke-Item . }
function dots { Set-Location $env:DOTS }
function dotp { Set-Location $env:PWSH }
function home { Set-Location $env:USERPROFILE }
function docs { Set-Location $env:USERPROFILE\Documents }
function dsktp { Set-Location $env:USERPROFILE\Desktop }
function downs { Set-Location $env:USERPROFILE\Downloads }
function HKLM { Set-Location HKLM: }
function HKCU { Set-Location HKCU: }
function flushdns { ipconfig /flushdns }
function displaydns { ipconfig /displaydns }
function lock { Invoke-Command { rundll32.exe user32.dll, LockWorkStation } }
function hibernate { shutdown.exe /h }
function shutdown { Stop-Computer }
function reboot { Restart-Computer }
function sysinfo { if (Get-Command fastfetch -ErrorAction SilentlyContinue) { fastfetch -c all } else { Get-ComputerInfo } }
function paths { $env:PATH -Split ';' }
function envs { Get-ChildItem Env: }
function export($name, $value) {
  Set-Item -Path "env:$name" -Value $value
}
function profiles { Get-PSProfile { $_.exists -eq "True" } | Format-List }

function Get-PSProfile {
  <#
  .SYNOPSIS
      Get all current in-use powershell profile
  .LINK
      https://powershellmagazine.com/2012/10/03/pstip-find-all-powershell-profiles-from-profile/
  #>
  $PROFILE.PSExtended.PSObject.Properties |
  Select-Object Name, Value, @{Name = 'IsExist'; Expression = { Test-Path -Path $_.Value -PathType Leaf } }
}

function fortune {
  [System.IO.File]::ReadAllText("$Env:PWSH\fortune.txt") -replace "`r`n", "`n" -split "`n%`n" | Get-Random
}

function Get-PubIp {
  (Invoke-WebRequest http://ifconfig.me/ip ).Content
}

function deltmp {
  Write-Host "Deleting temp data..."

  $path1 = "C" + ":\Windows\Temp"
  Get-ChildItem $path1 -Force -Recurse -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue

  $path2 = "C" + ":\Windows\Prefetch"
  Get-ChildItem $path2 -Force -Recurse -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue

  $path3 = "C" + ":\Users\*\AppData\Local\Temp"
  Get-ChildItem $path3 -Force -Recurse -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue

  Write-Host "Temp data deleted successfully." -ForegroundColor Green
}
function Update-Powershell {
  if (-not $Global:canConnectToGithub) {
    Write-Host "Cannot connect to GitHub. Please check your internet connection." -ForegroundColor Yellow
    return
  }

  try {
    Write-Host "Checking for PowerShell updates..." -ForegroundColor Cyan
    $updateNeeded = $false
    $currentVersion = $PSVersionTable.PSVersion.ToString()
    $githubAPIurl = "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
    $latestRelease = Invoke-RestMethod -Uri $githubAPIurl
    $latestVersion = $latestRelease.tag_name.Trim('v')

    if ($currentVersion -lt $latestVersion) {
      $updateNeeded = $true
    }

    if ($updateNeeded) {
      Write-Host "Updating PowerShell..." -ForegroundColor Yellow
      winget upgrade "Microsoft.PowerShell" --accept-source-agreements --accept-package-agreements
      Write-Host "PowerShell has been updated. Please restart your terminal" -ForegroundColor Magenta
    } else {
      Write-Host "PowerShell is up to date." -ForegroundColor Green
    }
  } catch {
    Write-Host "Failed to Update Powershell. Error = $_" -ForegroundColor Red
  }
}
function reload {
  if (Test-Path -Path $PROFILE) { . $PROFILE }
  elseif (Test-Path -Path $PROFILE.CurrentUserAllHosts) { . $PROFILE.CurrentUserAllHosts }
}
function restart { Get-Process -Id $PID | Select-Object -ExpandProperty Path | ForEach-Object { Invoke-Command { & "$_" } -NoNewScope } }
function Get-CommandInfo {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Name
  )
  $commandExists = Get-Command $Name -ErrorAction SilentlyContinue
  if ($commandExists) {
    return $commandExists | Select-Object -ExpandProperty Definition
  } else {
    Write-Warning "Command not found: $Name."
    break
  }
}

function New-File {
  <#
  .SYNOPSIS
      Creates a new file with the specified name and extension. Alias: touch
  #>
  [CmdletBinding()]
  param ([Parameter(Mandatory = $true, Position = 0)][string]$Name)
  New-Item -ItemType File -Name $Name -Path $PWD | Out-Null
}

function New-Directory {
  <#
  .SYNOPSIS
      Creates a new directory and cd into it. Alias: mkcd
  #>
  [CmdletBinding()]
  param ([Parameter(Mandatory = $True)]$Path)
  if (!(Test-Path $Path -PathType Container)) { New-Item -Path $Path -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null }
  Set-Location -Path $Path
}

function Find-File {
  <#
  .SYNOPSIS
      Finds a file in the current directory and all subdirectories. Alias: ff
  #>
  [CmdletBinding()]
  param ([Parameter(ValueFromPipeline, Mandatory = $true, Position = 0)][string]$SearchTerm)
  $result = Get-ChildItem -Recurse -Filter "*$SearchTerm*" -File -ErrorAction SilentlyContinue
  $result.FullName
}

function Find-String {
  <#
  .SYNOPSIS
      Searches for a string in a file or directory. Alias: grep
  #>
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$SearchTerm,
    [Parameter(ValueFromPipeline, Mandatory = $false, Position = 1)]
    [Alias('d')][string]$Directory,
    [Parameter(Mandatory = $false)]
    [Alias('f')][switch]$Recurse
  )

  if ($Directory) {
    if ($Recurse) { Get-ChildItem -Recurse $Directory | Select-String $SearchTerm; return }
    Get-ChildItem $Directory | Select-String $SearchTerm
    return
  }

  if ($Recurse) { Get-ChildItem -Recurse | Select-String $SearchTerm; return }
  Get-ChildItem | Select-String $SearchTerm
}

function Remove-MyItem {
  <#
  .SYNOPSIS
      Removes an item and (optionally) all its children. Alias: rm
  #>
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $false)]
    [switch]$rf,
    [Parameter(Mandatory = $true, Position = 0, ValueFromRemainingArguments = $true)]
    [string[]]$Path
  )
  Remove-Item $Path -Recurse:$rf -Force:$rf
}

function Invoke-Spongebob {
  [cmdletbinding()]
  param(
    [Parameter(HelpMessage = "provide string" , Mandatory = $true)]
    [string]$Message
  )
  $charArray = $Message.ToCharArray()

  foreach ($char in $charArray) {
    $Var = $(Get-Random) % 2
    if ($var -eq 0) {
      $string = $char.ToString()
      $Upper = $string.ToUpper()
      $output = $output + $Upper
    } else {
      $lower = $char.ToString()
      $output = $output + $lower
    }
  }
  $output
  $output = $null
}

function Select-Apps {
  param (
    [string[]]$apps
  )

  $header = "`n  CTRL+A-Select All   CTRL+D-Deselect All   CTRL+T-Toggle All`n" +
  "`nName" + "`n" + ("─" * 15)

  $apps = $apps | fzf --prompt="Select Apps  " --height=80% --layout=reverse --cycle `
    --margin="1,15" --multi --header=$header --padding=1 `
    --bind="ctrl-a:select-all,ctrl-d:deselect-all,ctrl-t:toggle-all" `

  return $apps
}

function List-ScoopApps {
  $apps = $(scoop list | Select-Object -ExpandProperty "Name").Split("\n")

  return $apps
}

function Update-ScoopApps {
  $appsSet = New-Object System.Collections.Generic.HashSet[[String]]
  $installedApps = List-ScoopApps

  Write-Host -NoNewline "`e[1A`e[0K"
  foreach ($app in Select-Apps $installedApps) {
    if ($app) {
      $app = $app.Split(" ")[0]
      $appsSet.Add($app) > $null
    }
  }

  if ($appsSet.Length) {
    $apps_string = ($appsSet -split ",")
    Write-Host "Selected apps: [$apps_string]"
  } else {
    Write-Host "No app was selected to update"
    return
  }

  $confirm = $(Read-Host "Do you want to update the selected apps? [Y/n] (Default is `"Y`") ").ToUpper()

  if ($confirm -eq "Y" -or $confirm -eq "") {
    scoop update $apps_string
  } else {
    Write-Host "Update was cancelled"
    return
  }
}

function Uninstall-ScoopApps {
  $appsSet = New-Object System.Collections.Generic.HashSet[[String]]
  $installedApps = List-ScoopApps

  Write-Host -NoNewline "`e[1A`e[0K"
  foreach ($app in Select-Apps $installedApps) {
    if ($app) {
      $app = $app.Split(" ")[0]
      $appsSet.Add($app) > $null
    }
  }

  if ($appsSet.Length) {
    $apps_string = ($appsSet -split ",")
    Write-Host "Selected apps: [$apps_string]"
  } else {
    Write-Host "No app was selected to uninstall"
    return
  }

  $confirm = $(Read-Host "Do you want to uninstall the selected apps? [Y/n] (Default is `"Y`") ").ToUpper()

  if ($confirm -eq "Y" -or $confirm -eq "") {
    scoop uninstall $apps_string
  } else {
    Write-Host "Uninstall was cancelled"
    return
  }
}
