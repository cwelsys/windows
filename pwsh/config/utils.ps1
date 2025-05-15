# 🔗 Aliases  - replaced a lot of the unix style replacements with gow
Set-Alias -Name 'whicc' -Value Get-CommandInfo # intentional typo
Set-Alias -Name 'fstring' -Value 'Find-String' # or grep
Set-Alias -Name 'newfile' -Value New-File # or touch
Remove-Item Alias:rm -Force -ErrorAction SilentlyContinue
# Set-Alias -Name 'rm' -Value 'Remove-MyItem'
Set-Alias -Name 'rl' -Value reload
Set-Alias -Name 'rst' -Value restart
Set-Alias -Name 'mkcd' -Value 'New-Directory'
Set-Alias -Name 'ff' -Value 'Find-File'
Set-Alias -Name 'lg' -Value lazygit
Set-Alias -Name 'vim' -Value nvim
Set-Alias -Name 'su' -Value gsudo
Set-Alias -Name 'vi' -Value nvim
Set-Alias -Name 'c' -Value clear
Set-Alias -Name 'df' -Value Get-Volume
Set-Alias -Name 'komorel' -Value Restart-TheThings
Set-Alias -Name 'spongob' -Value Invoke-Spongebob
Set-Alias -Name 'komozz' -Value Invoke-KomoFzf
Set-Alias -Name '?scoop' -Value Sync-ScoopApps
Set-Alias -Name '?winget' -Value Sync-WingetApps
Set-Alias -Name 'IP?' -Value Get-IPLocation
Set-Alias -Name 'npm-ls' -Value 'Get-NpmGlobalPackages'
Set-Alias -Name 'bun-ls' -Value 'Get-BunGlobalPackages'
Set-Alias -Name 'pnpm-ls' -Value 'Get-PnpmGlobalPackages'

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
function yasbrel { yasbc reload }
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
  Write-ColorText "{Gray}Deleting temp data..."

  $path1 = "C" + ":\Windows\Temp"
  Get-ChildItem $path1 -Force -Recurse -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue

  $path2 = "C" + ":\Windows\Prefetch"
  Get-ChildItem $path2 -Force -Recurse -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue

  $path3 = "C" + ":\Users\*\AppData\Local\Temp"
  Get-ChildItem $path3 -Force -Recurse -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue

  Write-ColorText "{Green}Temp data deleted successfully."
}
function Update-Powershell {
  try {
    Write-ColorText "{Cyan}Checking for PowerShell updates..."

    # Check internet connection to GitHub dynamically
    $githubTest = Test-Connection -ComputerName "github.com" -Count 1 -Quiet
    if (-not $githubTest) {
      Write-ColorText "{Yellow}Cannot connect to GitHub. Please check your internet connection."
      return
    }

    $updateNeeded = $false
    $currentVersion = $PSVersionTable.PSVersion.ToString()
    $githubAPIurl = "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
    $latestRelease = Invoke-RestMethod -Uri $githubAPIurl
    $latestVersion = $latestRelease.tag_name.Trim('v')

    if ($currentVersion -lt $latestVersion) {
      $updateNeeded = $true
    }

    if ($updateNeeded) {
      Write-ColorText "{Yellow}Updating PowerShell..."
      winget upgrade "Microsoft.PowerShell" --accept-source-agreements --accept-package-agreements
      Write-ColorText "{Magenta}PowerShell has been updated. Please restart your terminal"
    } else {
      Write-ColorText "{Green}PowerShell is up to date."
    }
  } catch {
    Write-ColorText "{Red}Failed to Update Powershell. Error = $_"
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

function Write-ColorText {
  param ([string]$Text, [switch]$NoNewLine)

  $hostColor = $Host.UI.RawUI.ForegroundColor

  $Text.Split( [char]"{", [char]"}" ) | ForEach-Object { $i = 0; } {
    if ($i % 2 -eq 0) {	Write-Host $_ -NoNewline }
    else {
      if ($_ -in [enum]::GetNames("ConsoleColor")) {
        $Host.UI.RawUI.ForegroundColor = ($_ -as [System.ConsoleColor])
      }
    }
    $i++
  }

  if (!$NoNewLine) { Write-Host }
  $Host.UI.RawUI.ForegroundColor = $hostColor
}

function Invoke-KomoFzf {
  param(
    [ValidateSet("exe", "title", "class")]
    [string]$Kind = "exe",
    [string]$PythonPath = "python",
    [string]$ScriptPath = (Join-Path "$Env:PWSH\config\KomorebiShellExtension" "KomorebiRuleManager.py")
  )

  $windows = Get-Process |
  Where-Object { $_.MainWindowHandle -ne 0 -and $_.MainWindowTitle -ne "" } |
  Select-Object Name, MainWindowTitle

  if (-not $windows) {
    Write-ColorText "{Gray}No windows open?"
    return
  }

  # Build a list of lines: "ProcessName : WindowTitle"
  $list = $windows | ForEach-Object {
    "{0} : {1}" -f $_.Name, $_.MainWindowTitle
  }

  Write-ColorText "{Gray}Hint: s add manage | d add ignore | Enter/Return for default (ignore)"

  $choice = $list | fzf --height 40% --prompt="Target: " `
    --expect "s,d" `
    --bind "enter:accept"

  if ($choice.Count -lt 2) {
    Write-ColorText "{Gray}Bye bye"
    return
  }

  $pressedKey = $choice[0]
  $selectedLine = $choice[1]
  $exe = ($selectedLine -split ':')[0].Trim()
  if ($Kind -eq "exe" -and -not $exe.ToLower().EndsWith(".exe")) {
    $exe += ".exe"
  }

  switch ($pressedKey) {
    's' {
      Write-ColorText "{Green}Managing $exe..."
      & $PythonPath $ScriptPath $exe $Kind "--manage"
    }
    'd' {
      Write-ColorText "{Gray}Ignoring $exe..."
      & $PythonPath $ScriptPath $exe $Kind "--ignore"
    }
    default {
      Write-ColorText "{Magenta}Ignoring $exe..."
      & $PythonPath $ScriptPath $exe $Kind "--ignore"
    }
  }
}

function Restart-TheThings {
  param(
    [switch]$Bar,
    [switch]$Yasb
  )

  Write-ColorText "{Magenta}Stopping Komorebi & whkd..."
  komorebic stop --whkd | Out-Null

  Write-ColorText "{Blue}Starting Komorebi & whkd..."
  if ($Bar) {
    komorebic start --whkd --bar | Out-Null
  } else {
    komorebic start --whkd | Out-Null
  }
  Write-ColorText "{Gray}Komorebi (with whkd) has been restarted successfully."
  if ($Yasb) {
    Write-ColorText "{Gray}Reloading Yasb..."
    yasbc reload
  }
}

function Sync-WingetApps {
  param(
    [string]$ConfigPath = "$Env:DOTS\config.jsonc",
    [switch]$ShowFiltered = $false
  )

  # Parse the JSON
  $jsonText = Get-Content $ConfigPath | Where-Object { $_ -notmatch '^\s*//' } | Out-String
  $config = $jsonText | ConvertFrom-Json

  # Define what's already in the config - make this case-insensitive
  $wantedWinget = @()
  if ($config.installSource.winget -and $config.installSource.winget.packageList) {
    $wantedWinget = $config.installSource.winget.packageList.packageId | ForEach-Object { $_.ToLower() }
  }

  # Get installed packages from winget
  Write-ColorText "{Gray}Fetching installed winget packages..."
  $wingetOutput = winget list --source winget

  # Find the header row and table content
  $headerIndex = $wingetOutput | Where-Object { $_ -match 'Name\s+Id\s+Version' } | ForEach-Object { $wingetOutput.IndexOf($_) }

  if ($null -eq $headerIndex -or $headerIndex -lt 0) {
    Write-Error "Could not find winget list header row"
    return
  }

  # Skip header row and separator line
  $dataRows = $wingetOutput | Select-Object -Skip ($headerIndex + 2)

  # Parse the columns - extract ID (second column)
  $wingetInstalled = @()
  foreach ($row in $dataRows) {
    if (-not [string]::IsNullOrWhiteSpace($row)) {
      # Split by multiple spaces - the second column should be the ID
      $columns = $row -split '\s{2,}'
      if ($columns.Count -ge 3) {
        $packageId = $columns[1].Trim()
        $wingetInstalled += $packageId
      }
    }
  }

  foreach ($row in $dataRows) {
    if ($row -match "msstore" -or $row -match "Microsoft Store") {
      # Try to extract MS Store package IDs
      if ($row -match '(\S+\.[\w\.]+)') {
        $msStoreId = $matches[1]
        if (-not $wingetInstalled.Contains($msStoreId)) {
          $wingetInstalled += $msStoreId
        }
      }
    }
  }

  # Filter out system packages, Steam games, etc.
  $excludePatterns = @(
    "arp\\machine", # Registry entries (including Steam)
    "Nvidia\.",
    "Microsoft\."
    # "MSIX\."
    # "msstore",
    # "Windows\.",
    # "^unknown$"
  )

  $filteredWinget = $wingetInstalled | Where-Object {
    $pkg = $_.ToLower()  # Case-insensitive matching
    $exclude = $false
    foreach ($pattern in $excludePatterns) {
      if ($pkg -match $pattern.ToLower()) {
        $exclude = $true
        break
      }
    }
    -not $exclude
  }

  # Debug info
  if ($ShowFiltered) {
    $filtered = $wingetInstalled | Where-Object { $filteredWinget -notcontains $_ }
    Write-ColorText "{Gray}Filtered out these packages ($($filtered.Count) of $($wingetInstalled.Count)):"
    $filtered | Select-Object -First 20 | ForEach-Object { Write-ColorText "{Gray}  $_" }
    if ($filtered.Count -gt 20) {
      Write-ColorText "{Gray}  ... and $($filtered.Count - 20) more"
    }
  }

  # Compare with config
  $extraWinget = $filteredWinget | Where-Object { $wantedWinget -notcontains $_.ToLower() }

  if (-not $extraWinget) {
    Write-ColorText "{Gray}No additional Winget packages to add to config."
    return
  }

  Write-ColorText "{Gray}Found $($extraWinget.Count) additional packages not in config."

  # fzf prompt
  $toAdd = $extraWinget | Sort-Object | fzf --multi --prompt "Packages> " --header "Tab or {s} to select, {a} to select all, Enter to finish" --bind "s:toggle+down,a:select-all"


  if (-not $toAdd) {
    Write-ColorText "{Gray}No packages selected. Config unchanged."
    return
  }

  # Read file as string to preserve precious JSON comments
  $fileLines = Get-Content $ConfigPath

  # Find winget section
  $wingetLineNumber = 0
  for ($i = 0; $i -lt $fileLines.Count; $i++) {
    if ($fileLines[$i] -match '"winget"\s*:') {
      $wingetLineNumber = $i
      break
    }
  }

  if ($wingetLineNumber -eq 0) {
    Write-Error "Could not find winget section in config file."
    return
  }

  # Find packageList following winget section
  $packageListLineNumber = 0
  for ($i = $wingetLineNumber; $i -lt $fileLines.Count; $i++) {
    if ($fileLines[$i] -match '"packageList"\s*:') {
      $packageListLineNumber = $i
      break
    }
  }

  if ($packageListLineNumber -eq 0) {
    Write-Error "Could not find packageList in winget section."
    return
  }

  # Find the opening bracket after packageList
  $startLine = 0
  for ($i = $packageListLineNumber; $i -lt $fileLines.Count; $i++) {
    if ($fileLines[$i] -match '\[') {
      $startLine = $i
      break
    }
  }

  if ($startLine -eq 0) {
    Write-Error "Could not find opening bracket for packageList array."
    return
  }

  # Find closing bracket of the array by counting brackets
  $endLine = $startLine
  $bracketCount = 1

  for ($i = $startLine + 1; $i -lt $fileLines.Count; $i++) {
    $openCount = ([regex]::Matches($fileLines[$i], '\[').Count)
    $bracketCount += $openCount

    $closeCount = ([regex]::Matches($fileLines[$i], '\]').Count)
    $bracketCount -= $closeCount

    if ($bracketCount -eq 0) {
      $endLine = $i
      break
    }
  }

  if ($bracketCount -ne 0) {
    Write-Error "Could not locate end of winget packageList array."
    return
  }

  # Determine indentation by looking at existing entries
  $indent = ""
  for ($i = $startLine + 1; $i -lt $endLine; $i++) {
    if ($fileLines[$i] -match '^\s*{') {
      $indent = [regex]::Match($fileLines[$i], '^\s*').Value
      break
    }
  }
  if ($indent -eq "") {
    # Default indent
    $indent = "				"
  }

  # Format new entries
  $lastEntry = $fileLines[$endLine - 1].Trim()

  if (-not $lastEntry.EndsWith(",")) {
    $fileLines[$endLine - 1] = $fileLines[$endLine - 1] + ","
  }

  # Create new entries in the same format as existing ones
  $newEntries = @()
  foreach ($pkg in $toAdd) {
    $newEntries += "$indent{ `"packageId`": `"$pkg`" },"
  }
  # Remove trailing comma from the last new entry
  $newEntries[$newEntries.Count - 1] = $newEntries[$newEntries.Count - 1].TrimEnd(",")

  # Insert new entries before the closing bracket
  $updatedLines = $fileLines[0..($endLine - 1)] +
  $newEntries +
  $fileLines[$endLine..($fileLines.Count - 1)]

  # Write the updated file back
  $updatedLines | Out-File $ConfigPath -Encoding utf8

  Write-ColorText "{Green}Added the following Winget packages to your config:"
  $toAdd | ForEach-Object { Write-ColorText "{Gray} - $_" }
}

function Sync-ScoopApps {
  param(
    [string]$ConfigPath = "$Env:DOTS\config.jsonc"
  )

  # Parse the JSON
  $jsonText = Get-Content $ConfigPath | Where-Object { $_ -notmatch '^\s*//' } | Out-String
  $config = $jsonText | ConvertFrom-Json

  # Define whats already on the JSON
  $wantedScoop = $config.installSource.scoop.packageList.packageName

  # Get installed packages
  $scoopInstalled = (scoop list | Select-Object -Skip 2) |
  Select-Object -ExpandProperty Name

  # Compare them
  $extraScoop = $scoopInstalled | Where-Object { $wantedScoop -notcontains $_ }

  if (-not $extraScoop) {
    Write-ColorText "{Gray}No additional Scoop packages to add to config."
    return
  }

  # fzf prompt
  $toAdd = $extraScoop | fzf --multi --prompt "Packages> " --header "Tab or {s} to select, {a} to select all, Enter to finish" --bind "s:toggle+down,a:select-all"

  if (-not $toAdd) {
    Write-ColorText "{Gray}No packages selected. Config unchanged."
    return
  }

  # Read file as string to preserve precious JSON comments
  $fileLines = Get-Content $ConfigPath

  # Find scoop section, packageList array
  $scoopLineNumber = 0
  for ($i = 0; $i -lt $fileLines.Count; $i++) {
    if ($fileLines[$i] -match '"scoop"\s*:') {
      $scoopLineNumber = $i
      break
    }
  }

  if ($scoopLineNumber -eq 0) {
    Write-Error "Could not find scoop section in config file."
    return
  }

  # Find packageList following scoop section
  $packageListLineNumber = 0
  for ($i = $scoopLineNumber; $i -lt $fileLines.Count; $i++) {
    if ($fileLines[$i] -match '"packageList"\s*:') {
      $packageListLineNumber = $i
      break
    }
  }

  if ($packageListLineNumber -eq 0) {
    Write-Error "Could not find packageList in scoop section."
    return
  }

  # Find the opening bracket after packageList
  $startLine = 0
  for ($i = $packageListLineNumber; $i -lt $fileLines.Count; $i++) {
    if ($fileLines[$i] -match '\[') {
      $startLine = $i
      break
    }
  }

  if ($startLine -eq 0) {
    Write-Error "Could not find opening bracket for packageList array."
    return
  }

  # Find closing bracket of the array by counting brackets
  $endLine = $startLine
  $bracketCount = 1

  for ($i = $startLine + 1; $i -lt $fileLines.Count; $i++) {
    $openCount = ([regex]::Matches($fileLines[$i], '\[').Count)
    $bracketCount += $openCount

    $closeCount = ([regex]::Matches($fileLines[$i], '\]').Count)
    $bracketCount -= $closeCount

    if ($bracketCount -eq 0) {
      $endLine = $i
      break
    }
  }

  if ($bracketCount -ne 0) {
    Write-Error "Could not locate end of scoop packageList array."
    return
  }

  # Determine indentation by looking at existing entries
  $indent = ""
  for ($i = $startLine + 1; $i -lt $endLine; $i++) {
    if ($fileLines[$i] -match '^\s*{') {
      $indent = [regex]::Match($fileLines[$i], '^\s*').Value
      break
    }
  }
  if ($indent -eq "") {
    # Default indent if we couldn't determine it
    $indent = "				"
  }

  # Format new entries
  $lastEntry = $fileLines[$endLine - 1].Trim()

  if (-not $lastEntry.EndsWith(",")) {
    $fileLines[$endLine - 1] = $fileLines[$endLine - 1] + ","
  }

  # Create new entries in the same format as existing ones
  $newEntries = @()
  foreach ($pkg in $toAdd) {
    $newEntries += "$indent{ `"packageName`": `"$pkg`" },"
  }
  # Remove trailing comma from the last new entry
  $newEntries[$newEntries.Count - 1] = $newEntries[$newEntries.Count - 1].TrimEnd(",")

  # Insert new entries before the closing bracket
  $updatedLines = $fileLines[0..($endLine - 1)] +
  $newEntries +
  $fileLines[$endLine..($fileLines.Count - 1)]

  # Write the updated file back
  $updatedLines | Out-File $ConfigPath -Encoding utf8

  Write-ColorText "{Green}Packages have been added the config:"
  $toAdd | ForEach-Object { Write-ColorText "{Gray} - $_" }
}

# List NPM (NodeJS) Global Packages
# To export global packages to a file, for-example: `npm-ls > global_packages.txt`
function Get-NpmGlobalPackages { (npm ls -g | Select-Object -skip 1).Trim().Split() | ForEach-Object { if ($_ -match [regex]::Escape("@")) { Write-Output $_ } } }
function Get-BunGlobalPackages { (bun pm ls -g | Select-Object -Skip 1).Trim().Split() | ForEach-Object { if ($_ -match [regex]::Escape("@")) { Write-Output $_ } } }
function Get-PnpmGlobalPackages { (pnpm ls -g | Select-Object -Skip 5) | ForEach-Object { $name = $_.Split()[0]; $version = $_.Split()[1]; Write-Output "$name@$version" } }
function Get-IPLocation {
  param([string]$IPaddress = "")

  try {
    if ($IPaddress -eq "" ) { $IPaddress = read-host "Enter IP address to locate" }

    $result = Invoke-RestMethod -Method Get -Uri "http://ip-api.com/json/$IPaddress"
    write-output $result
    return $result
  } catch {
    "⚠️ Error in line $($_.InvocationInfo.ScriptLineNumber): $($Error[0])"
    throw
  }
}
