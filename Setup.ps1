#          _.-;;-._
#   '-..-'|   ||   |
#   '-..-'|_.-;;-._|
#   '-..-'|   ||   |
#   '-..-'|_.-''-._|

#Requires -Version 7
#Requires -RunAsAdministrator

<#

.DESCRIPTION
	Sets up Windows apps/package managers and more.

#>
Param()

# Helper functions

function Write-TitleBox {
	param ([string]$Title, [string]$BorderChar = "*", [int]$Padding = 10)

	$Title = $Title.ToUpper()
	$titleLength = $Title.Length
	$boxWidth = $titleLength + ($Padding * 2) + 2

	$borderLine = $BorderChar * $boxWidth
	$paddingLine = $BorderChar + (" " * ($boxWidth - 2)) + $BorderChar
	$titleLine = $BorderChar + (" " * $Padding) + $Title + (" " * $Padding) + $BorderChar

	''
	Write-Host $borderLine -ForegroundColor Cyan
	Write-Host $paddingLine -ForegroundColor Cyan
	Write-Host $titleLine -ForegroundColor Cyan
	Write-Host $paddingLine -ForegroundColor Cyan
	Write-Host $borderLine -ForegroundColor Cyan
	''
}

# Source:
# - https://stackoverflow.com/questions/2688547/multiple-foreground-colors-in-powershell-in-one-command
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

function Add-ScoopBucket {
	param ([string]$BucketName, [string]$BucketRepo)

	$scoopDir = (Get-Command scoop.ps1 -ErrorAction SilentlyContinue).Source | Split-Path | Split-Path
	if (!(Test-Path "$scoopDir\buckets\$BucketName" -PathType Container)) {
		if ($BucketRepo) {
			scoop bucket add $BucketName $BucketRepo
		} else {
			scoop bucket add $BucketName
		}
	} else {
		Write-ColorText "{Blue}[bucket] {Magenta}scoop: {Yellow}(exists) {Gray}$BucketName"
	}
}

function Install-ScoopApp {
	param ([string]$Package, [switch]$Global, [array]$AdditionalArgs)
	if (!(scoop info $Package).Installed) {
		$scoopCmd = "scoop install $Package"
		if ($Global) { $scoopCmd += " -g" }
		if ($AdditionalArgs.Count -ge 1) {
			$AdditionalArgs = $AdditionalArgs -join ' '
			$scoopCmd += " $AdditionalArgs"
		}
		''; Invoke-Expression "$scoopCmd"; ''
	} else {
		Write-ColorText "{Blue}[package] {Magenta}scoop: {Yellow}(exists) {Gray}$Package"
	}
}

function Install-WinGetApp {
	param ([string]$PackageID, [array]$AdditionalArgs, [string]$Source)

	winget list --exact -q $PackageID | Out-Null
	if (!$?) {
		$wingetCmd = "winget install $PackageID"
		if ($AdditionalArgs.Count -ge 1) {
			$AdditionalArgs = $AdditionalArgs -join ' '
			$wingetCmd += " $AdditionalArgs"
		}
		if ($Source -eq "msstore") { $wingetCmd += " --source msstore" }
		else { $wingetCmd += " --source winget" }
		Invoke-Expression "$wingetCmd >`$null 2>&1"
		if ($LASTEXITCODE -eq 0) {
			Write-ColorText "{Blue}[package] {Magenta}winget: {Green}(success) {Gray}$PackageID"
		} else {
			Write-ColorText "{Blue}[package] {Magenta}winget: {Red}(failed) {Gray}$PackageID"
		}
	} else {
		Write-ColorText "{Blue}[package] {Magenta}winget: {Yellow}(exists) {Gray}$PackageID"
	}
}

function Install-ChocoApp {
	param ([string]$Package, [string]$Version, [array]$AdditionalArgs)

	$chocoList = choco list $Package
	if ($chocoList -like "0 packages installed.") {
		$chocoCmd = "choco install $Package"
		if ($Version) {
			$pkgVer = "--version=$Version"
			$chocoCmd += " $pkgVer"
		}
		if ($AdditionalArgs.Count -ge 1) {
			$AdditionalArgs = $AdditionalArgs -join ' '
			$chocoCmd += " $AdditionalArgs"
		}
		Invoke-Expression "$chocoCmd >`$null 2>&1"
		if ($LASTEXITCODE -eq 0) {
			Write-ColorText "{Blue}[package] {Magenta}choco: {Green}(success) {Gray}$Package"
		} else {
			Write-ColorText "{Blue}[package] {Magenta}choco: {Red}(failed) {Gray}$Package"
		}
	} else {
		Write-ColorText "{Blue}[package] {Magenta}choco: {Yellow}(exists) {Gray}$Package"
	}
}

function Install-PowerShellModule {
	param ([string]$Module, [string]$Version, [array]$AdditionalArgs)

	if (!(Get-InstalledModule -Name $Module -ErrorAction SilentlyContinue)) {
		Write-ColorText "{Blue}[module] {Magenta}pwsh: {Gray}Installing $Module..."
		$params = @{
			Name = $Module
		}
		if ($null -ne $Version -and $Version -ne '') {
			$params['RequiredVersion'] = $Version
		}

		# Process additional arguments
		if ($AdditionalArgs -and $AdditionalArgs.Count -gt 0) {
			$i = 0
			while ($i -lt $AdditionalArgs.Count) {
				$arg = $AdditionalArgs[$i]

				# Check if this is a parameter (starts with '-')
				if ($arg.StartsWith('-')) {
					$paramName = $arg.TrimStart('-')

					# If there's a value following this parameter
					if ($i + 1 -lt $AdditionalArgs.Count -and !$AdditionalArgs[$i + 1].StartsWith('-')) {
						$params[$paramName] = $AdditionalArgs[$i + 1]
						$i += 2  # Skip both parameter and its value
					} else {
						# It's a switch parameter
						$params[$paramName] = $true
						$i += 1  # Skip just the parameter
					}
				} else {
					# Skip non-parameter arguments
					$i += 1
				}
			}
		}

		# Make sure NuGet provider is available
		if (!(Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
			Write-Verbose "Installing NuGet package provider..."
			Install-PackageProvider -Name NuGet -Force -Scope CurrentUser | Out-Null
		}
		try {
			# Install module using splatting to avoid duplicate parameters
			Install-Module @params

			# Verify the installation succeeded
			if (Get-InstalledModule -Name $Module -ErrorAction SilentlyContinue) {
				Write-ColorText "{Blue}[module] {Magenta}pwsh: {Green}(success) {Gray}$Module"
			} else {
				Write-ColorText "{Blue}[module] {Magenta}pwsh: {Red}(failed) {Gray}$Module - module not found after installation attempt"
			}
		} catch {
			Write-ColorText "{Blue}[module] {Magenta}pwsh: {Red}(failed) {Gray}$Module - $($_.Exception.Message)"
		}
	} else {
		Write-ColorText "{Blue}[module] {Magenta}pwsh: {Yellow}(exists) {Gray}$Module"
	}
}

function Install-AppFromGitHub {
	param ([string]$RepoName, [string]$FileName)

	$release = "https://api.github.com/repos/$RepoName/releases"
	$tag = (Invoke-WebRequest $release | ConvertFrom-Json)[0].tag_name
	$downloadUrl = "https://github.com/$RepoName/releases/download/$tag/$FileName"
	$downloadPath = (New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path
	$downloadFile = "$downloadPath\$FileName"
	(New-Object System.Net.WebClient).DownloadFile($downloadUrl, $downloadFile)

	switch ($FileName.Split('.') | Select-Object -Last 1) {
		"exe" {
			Start-Process -FilePath "$downloadFile" -Wait
		}
		"msi" {
			Start-Process -FilePath "$downloadFile" -Wait
		}
		"zip" {
			$dest = "$downloadPath\$($FileName.Split('.'))"
			Expand-Archive -Path "$downloadFile" -DestinationPath "$dest"
		}
		"7z" {
			7z x -o"$downloadPath" -y "$downloadFile" | Out-Null
		}
		Default { break }
	}
	Remove-Item "$downloadFile" -Force -Recurse -ErrorAction SilentlyContinue
}

function Install-OnlineFile {
	param ([string]$OutputDir, [string]$Url)
	Invoke-WebRequest -Uri $Url -OutFile $OutputDir
}

function Refresh ([int]$Time) {
	if (Get-Command choco -ErrorAction SilentlyContinue) {

		switch -regex ($Time.ToString()) {
			'1(1|2|3)$' { $suffix = 'th'; break }
			'.?1$' { $suffix = 'st'; break }
			'.?2$' { $suffix = 'nd'; break }
			'.?3$' { $suffix = 'rd'; break }
			default { $suffix = 'th'; break }
		}

		if (!(Get-Module -ListAvailable -Name "chocoProfile" -ErrorAction SilentlyContinue)) {
			$chocoModule = "C:\ProgramData\chocolatey\helpers\chocolateyProfile.psm1"
			if (Test-Path $chocoModule -PathType Leaf) {
				Import-Module $chocoModule
			}
		}
		Write-Verbose -Message "Refreshing environment variables from registry ($Time$suffix attempt)"
		refreshenv | Out-Null
	}
}

function Write-LockFile {
	param (
		[ValidateSet('winget', 'choco', 'scoop', 'modules')]
		[Alias('s', 'p')][string]$PackageSource,
		[Alias('f')][string]$FileName,
		[Alias('o')][string]$OutputPath = "$PSScriptRoot\.out"
	)

	$dest = "$OutputPath\$FileName"

	switch ($PackageSource) {
		"winget" {
			if (!(Get-Command winget -ErrorAction SilentlyContinue)) { return }
			winget export -o $dest | Out-Null
			if ($LASTEXITCODE -eq 0) {
				Write-ColorText "`n✔️  Packages installed by {Green}$PackageSource {Gray}are exported at {Red}$((Resolve-Path $dest).Path)"
			}
			Start-Sleep -Seconds 1
		}
		"choco" {
			if (!(Get-Command choco -ErrorAction SilentlyContinue)) { return }
			choco export $dest | Out-Null
			if ($LASTEXITCODE -eq 0) {
				Write-ColorText "`n✔️  Packages installed by {Green}$PackageSource {Gray}are exported at {Red}$((Resolve-Path $dest).Path)"
			}
			Start-Sleep -Seconds 1
		}
		"scoop" {
			if (!(Get-Command scoop -ErrorAction SilentlyContinue)) { return }
			scoop export -c > $dest
			if ($LASTEXITCODE -eq 0) {
				Write-ColorText "`n✔️  Packages installed by {Green}$PackageSource {Gray}are exported at {Red}$((Resolve-Path $dest).Path)"
			}
			Start-Sleep -Seconds 1
		}
		"modules" {
			Get-InstalledModule | Select-Object -Property Name, Version | ConvertTo-Json -Depth 100 | Out-File $dest
			if ($LASTEXITCODE -eq 0) {
				Write-ColorText "`n✔️  {Green}PowerShell Modules {Gray}installed are exported at {Red}$((Resolve-Path $dest).Path)"
			}
			Start-Sleep -Seconds 1
		}
	}
}

# Main Script
# Check internet connection
$internetConnection = Test-NetConnection google.com -CommonTCPPort HTTP -InformationLevel Detailed -WarningAction SilentlyContinue
$internetAvailable = $internetConnection.TcpTestSucceeded
if ($internetAvailable -eq $False) {
	Write-Warning "NO INTERNET CONNECTION AVAILABLE!"
	Write-Host "Please check your internet connection and re-run this script.`n"
	for ($countdown = 3; $countdown -ge 0; $countdown--) {
		Write-ColorText "`r{DarkGray}Automatically exit this script in {Blue}$countdown second(s){DarkGray}..." -NoNewLine
		Start-Sleep -Seconds 1
	}
	exit
}

Write-Progress -Completed; Clear-Host

Write-ColorText "`n✅ {Green}Internet Connection available.`n`n{DarkGray}Start running setup process..."
Start-Sleep -Seconds 3

# set current working directory location
$currentLocation = "$($(Get-Location).Path)"

Set-Location $PSScriptRoot
[System.Environment]::CurrentDirectory = $PSScriptRoot

$i = 1

# Install fonts

# Write-TitleBox -Title "Nerd Fonts Installation"
# Set-Clipboard "16, 29, 10, 28, 46, 44, 52"
# Write-ColorText "{Green}Copied some fonts to the clipboard:`n{DarkGray}(Please skip this step if you already installed Nerd Fonts)`n`n  {Gray}● Caskaydiacove`n  ● FantasqueSansM`n  ● IosvekaTerm`n  ● JetBrainsMono`n"

# for ($count = 5; $count -ge 0; $count--) {
# 	Write-ColorText "`r{Magenta}Install Nerd Fonts now? [y/N]: {DarkGray}(Exit in {Blue}$count {DarkGray}seconds) {Gray}" -NoNewLine

# 	if ([System.Console]::KeyAvailable) {
# 		$key = [System.Console]::ReadKey($false)
# 		if ($key.Key -ne 'Y') {
# 			Write-ColorText "`r{DarkGray}Skipped installing Nerd Fonts...                                                                 "
# 			break
# 		} else {
# 			& ([scriptblock]::Create((Invoke-WebRequest 'https://to.loredo.me/Install-NerdFont.ps1'))) -Scope AllUsers -Confirm:$False
# 			break
# 		}
# 	}
# 	Start-Sleep -Seconds 1
# }
# Refresh ($i++)

# Clear-Host

# Parse the json
$json = Get-Content "$PSScriptRoot\config.jsonc" -Raw | ConvertFrom-Json

# ~ Winget ~
$wingetItem = $json.installSource.winget
$wingetPkgs = $wingetItem.packageList
$wingetArgs = $wingetItem.additionalArgs
$wingetInstall = $wingetItem.autoInstall

if ($wingetInstall -eq $True) {
	Write-TitleBox -Title "🗑️ WinGet Packages"
	if (!(Get-Command winget -ErrorAction SilentlyContinue)) {
		# Use external script to install WinGet and all of its requirements
		# Source: - https://github.com/asheroto/winget-install
		Write-Verbose -Message "Installing winget-cli"
		&([ScriptBlock]::Create((Invoke-RestMethod asheroto.com/winget))) -Force
	}

	$settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\settings.json"
	$settingsJson = @'
{
		"$schema": "https://aka.ms/winget-settings.schema.json",

		// For documentation on these settings, see: https://aka.ms/winget-settings
		// "source": {
		//    "autoUpdateIntervalInMinutes": 5
		// },
		"visual": {
				"enableSixels": true,
				"progressBar": "rainbow"
		},
		"telemetry": {
				"disable": true
		},
		"experimentalFeatures": {
				"configuration03": true,
				"configureExport": true,
				"configureSelfElevate": true,
				"experimentalCMD": true
		},
		"network": {
				"downloader": "wininet"
		}
}
'@
	$settingsJson | Out-File $settingsPath -Encoding utf8

	# Download packages from WinGet
	foreach ($pkg in $wingetPkgs) {
		$pkgId = $pkg.packageId
		$pkgSource = $pkg.packageSource
		if ($null -ne $pkgSource) {
			Install-WinGetApp -PackageID $pkgId -AdditionalArgs $wingetArgs -Source $pkgSource
		} else {
			Install-WinGetApp -PackageID $pkgId -AdditionalArgs $wingetArgs
		}
	}
	Write-LockFile -PackageSource winget -FileName wingetfile.json
	Refresh ($i++)
}

# ~ Choco ~
# Write-TitleBox -Title "🍫 Chocolatey Packages"
$chocoItem = $json.installSource.choco
$chocoPkgs = $chocoItem.packageList
$chocoArgs = $chocoItem.additionalArgs
$chocoInstall = $chocoItem.autoInstall

if ($chocoInstall -eq $True) {
	if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
		# Install chocolatey
		# Source: - https://chocolatey.org/install
		Write-Verbose -Message "Installing chocolatey"
		if ((Get-ExecutionPolicy) -eq "Restricted") { Set-ExecutionPolicy AllSigned }
		Set-ExecutionPolicy Bypass -Scope Process -Force
		[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
		Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
	}

	foreach ($pkg in $chocoPkgs) {
		$chocoPkg = $pkg.packageName
		$chocoVer = $pkg.packageVersion
		if ($null -ne $chocoVer) {
			Install-ChocoApp -Package $chocoPkg -Version $chocoVer -AdditionalArgs $chocoArgs
		} else {
			Install-ChocoApp -Package $chocoPkg -AdditionalArgs $chocoArgs
		}
	}
	Write-LockFile -PackageSource choco -FileName chocolatey.config -OutputPath "$PSScriptRoot\.out"
	Refresh ($i++)
}

# ~ Scoop ~
$scoopItem = $json.installSource.scoop
$scoopBuckets = $scoopItem.bucketList
$scoopPkgs = $scoopItem.packageList
$scoopArgs = $scoopItem.additionalArgs
$scoopInstall = $scoopItem.autoInstall

if ($scoopInstall -eq $True) {
	Write-TitleBox -Title "🥣 Scoop Packages"
	if (!(Get-Command scoop -ErrorAction SilentlyContinue)) {
		# `scoop` is recommended to be installed from a non-administrative
		# PowerShell terminal. However, since we are in administrative shell,
		# it is required to invoke the installer with the `-RunAsAdmin` parameter.

		# Source: - https://github.com/ScoopInstaller/Install#for-admin
		Write-Verbose -Message "Installing scoop"
		Invoke-Expression "& {$(Invoke-RestMethod get.scoop.sh)} -RunAsAdmin"
	}

	# Configure aria2
	if (!(Get-Command aria2c -ErrorAction SilentlyContinue)) { scoop install aria2 }
	if (!($(scoop config aria2-enabled) -eq $True)) { scoop config aria2-enabled true }
	if (!($(scoop config aria2-warning-enabled) -eq $False)) { scoop config aria2-warning-enabled false }

	# Create a scheduled task for aria2 so that it will always be active when we logon the machine
	# Idea is from: - https://gist.github.com/mikepruett3/7ca6518051383ee14f9cf8ae63ba18a7
	if (!(Get-ScheduledTaskInfo -TaskName "Aria2RPC" -ErrorAction Ignore)) {
		try {
			$scoopDir = (Get-Command scoop.ps1 -ErrorAction SilentlyContinue).Source | Split-Path | Split-Path
			$Action = New-ScheduledTaskAction -Execute "$scoopDir\apps\aria2\current\aria2c.exe" -Argument "--enable-rpc --rpc-listen-all" -WorkingDirectory "$Env:USERPROFILE\Downloads"
			$Trigger = New-ScheduledTaskTrigger -AtStartup
			$Principal = New-ScheduledTaskPrincipal -UserID "$Env:USERDOMAIN\$Env:USERNAME" -LogonType S4U
			$Settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit 0 -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
			Register-ScheduledTask -TaskName "Aria2RPC" -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings | Out-Null
		} catch {
			Write-Error "An error occurred: $_"
		}
	}

	# Add scoop buckets
	foreach ($bucket in $scoopBuckets) {
		$bucketName = $bucket.bucketName
		$bucketRepo = $bucket.bucketRepo
		if ($null -ne $bucketRepo) {
			Add-ScoopBucket -BucketName $bucketName -BucketRepo $bucketRepo
		} else {
			Add-ScoopBucket -BucketName $bucketName
		}
	}

	''

	# Install applications from scoop
	foreach ($pkg in $scoopPkgs) {
		$pkgName = $pkg.packageName
		$pkgScope = $pkg.packageScope
		if (($null -ne $pkgScope) -and ($pkgScope -eq "global")) { $Global = $True } else { $Global = $False }
		if ($null -ne $scoopArgs) {
			Install-ScoopApp -Package $pkgName -Global:$Global -AdditionalArgs $scoopArgs
		} else {
			Install-ScoopApp -Package $pkgName -Global:$Global
		}
	}
	Write-LockFile -PackageSource scoop -FileName scoopfile.json
	Refresh ($i++)
}

# ~ Powershell ~
$moduleItem = $json.powershell.psmodule
$moduleList = $moduleItem.moduleList
$moduleArgs = $moduleItem.additionalArgs
$moduleInstall = $moduleItem.install

if ($moduleInstall -eq $True) {
	Write-TitleBox -Title "🐚 PowerShell"
	foreach ($module in $moduleList) {
		$mName = $module.moduleName
		$mVersion = $module.moduleVersion  # Add version support if it exists in your JSON
		Install-PowerShellModule -Module $mName -Version $mVersion -AdditionalArgs $moduleArgs
	}
	Write-LockFile -PackageSource modules -FileName modules.json
	Refresh ($i++)
}

# Enable powershell experimental features
$feature = $json.powershell.psexperimentalfeature
$featureEnable = $feature.enable
$featureList = $feature.featureList

if ($featureEnable -eq $True) {
	if (!(Get-Command Get-ExperimentalFeature -ErrorAction SilentlyContinue)) { return }

	''
	foreach ($f in $featureList) {
		$featureExists = Get-ExperimentalFeature -Name $f -ErrorAction SilentlyContinue
		if ($featureExists -and ($featureExists.Enabled -eq $False)) {
			Enable-ExperimentalFeature -Name $f -Scope CurrentUser -ErrorAction SilentlyContinue
			if ($LASTEXITCODE -eq 0) {
				Write-ColorText "{Blue}[experimental feature] {Magenta}pwsh: {Green}(success) {Gray}$f"
			} else {
				Write-ColorText "{Blue}[experimental feature] {Magenta}pwsh: {Red}(failed) {Gray}$f"
			}
		} else {
			Write-ColorText "{Blue}[experimental feature] {Magenta}pwsh: {Yellow}(enabled) {Gray}$f"
		}
	}

	Refresh ($i++)
}

# Git config
Write-TitleBox -Title "📝 Git config"
if (Get-Command git -ErrorAction SilentlyContinue) {
	$gitUserName = (git config user.name)
	$gitUserMail = (git config user.email)

	if ($null -eq $gitUserName) {
		$gitUserName = $(Write-Host "Input your git name: " -NoNewline -ForegroundColor Magenta; Read-Host)
	} else {
		Write-ColorText "{Blue}[user.name]  {Magenta}git: {Yellow}(already set) {Gray}$gitUserName"
	}
	if ($null -eq $gitUserMail) {
		$gitUserMail = $(Write-Host "Input your git email: " -NoNewline -ForegroundColor Magenta; Read-Host)
	} else {
		Write-ColorText "{Blue}[user.email] {Magenta}git: {Yellow}(already set) {Gray}$gitUserMail"
	}

	git submodule update --init --recursive
}

if (Get-Command gh -ErrorAction SilentlyContinue) {
	if (!(gh auth status)) { gh auth login }
}

# ~symlinks~
Write-TitleBox -Title "🔗 Symbolic Links"
$symlinks = @{
	$PROFILE.CurrentUserAllHosts                                                                  = ".\Profile.ps1"
	"$HOME\.czrc"                                                                                 = ".\home\.czrc"
	"$HOME\.gitconfig"                                                                            = ".\home\.gitconfig"
	"$HOME\.wslconfig"                                                                            = ".\home\.wslconfig"
	"$HOME\.inputrc"                                                                              = ".\home\.inputrc"
	"$HOME\.bashrc"                                                                               = ".\home\.bashrc"
	"$HOME\.bash_profile"                                                                         = ".\home\.bash_profile"
	"$HOME\.config\bash"                                                                          = ".\config\bash"
	"$Env:LOCALAPPDATA\nvim"                                                                      = ".\config\nvim"
	"$Env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json" = ".\config\terminal\settings.json"
	"$HOME\.config\wezterm"                                                                       = ".\config\wezterm"
	"$HOME\.config\bat"                                                                           = ".\config\bat"
	"$HOME\.config\startship.toml"                                                                = ".\config\starship.toml"
	"$Env:LOCALAPPDATA\fastfetch"                                                                 = ".\config\fastfetch"
	"$Env:LOCALAPPDATA\lazygit"                                                                   = ".\config\lazygit"
	"$HOME\.config\delta"                                                                         = ".\config\delta"
	"$HOME\.config\eza"                                                                           = ".\config\eza"
	"$Env:LOCALAPPDATA\glow"                                                                      = ".\config\glow"
	"$Env:APPDATA\topgrade.toml"                                                                  = ".\config\topgrade.toml"
	"$HOME\.config\gh-dash"                                                                       = ".\config\gh-dash"
	"$HOME\.config\komorebi"                                                                      = ".\config\komorebi"
	"$HOME\.config\whkdrc"                                                                        = ".\config\whkdrc"
	"$HOME\.config\yasb"                                                                          = ".\config\yasb"
	"$HOME\.config\yazi"                                                                          = ".\config\yazi"
	"$HOME\.config\dust"                                                                          = ".\config\dust"
	"$HOME\.config\mise"                                                                          = ".\config\mise"
	"$HOME\.config\jj"                                                                            = ".\config\jj"
	"$HOME\Documents\Script"                                                                      = "D:\rice\utils\script"
	"$HOME\Documents\Game"                                                                        = "D:\game"
}

foreach ($symlink in $symlinks.GetEnumerator()) {
	Write-Verbose -Message "Creating symlink for $(Resolve-Path $symlink.Value) --> $($symlink.Key)"
	Get-Item -Path $symlink.Key -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
	New-Item -ItemType SymbolicLink -Path $symlink.Key -Target (Resolve-Path $symlink.Value) -Force | Out-Null
	Write-ColorText "{Blue}[symlink] {Green}$(Resolve-Path $symlink.Value) {Yellow}--> {Gray}$($symlink.Key)"
}
Refresh ($i++)

# Set the right git name and email for the user after symlinking
if (Get-Command git -ErrorAction SilentlyContinue) {
	git config --global user.name $gitUserName
	git config --global user.email $gitUserMail
}

# ~ Environment variables ~s
Write-TitleBox -Title "🌏 Environment Variables"
$envVars = $json.environmentVariable
foreach ($env in $envVars) {
	$envCommand = $env.commandName
	$envKey = $env.environmentKey
	$envValue = $env.environmentValue
	if (Get-Command $envCommand -ErrorAction SilentlyContinue) {
		# Process environment value - expand relative paths if needed
		$isRelativePath = $envValue.StartsWith('.') -or
            ($envValue -match '^[^:]+[\\/]' -and -not $envValue.Contains(':'))

		if ($isRelativePath) {
			# Make sure we're using consistent path format (.config vs config)
			if ($envValue -match '^\.?config\\') {
				$envValue = $envValue -replace '^config\\', '.config\'
				$envValue = $envValue -replace '^\.config\\', '.config\'
			}

			# This is a relative path - expand relative to $HOME
			$expandedValue = Join-Path -Path $HOME -ChildPath $envValue
			$envValue = $expandedValue
		}

		# Check if the environment variable already exists and has the correct value
		$existingValue = [System.Environment]::GetEnvironmentVariable($envKey, "User")
		$shouldUpdate = $true

		# Compare values (case-insensitive for paths on Windows)
		if (![string]::IsNullOrEmpty($existingValue)) {
			if ($isRelativePath) {
				# For paths, compare normalized paths
				$normalizedExisting = [System.IO.Path]::GetFullPath($existingValue)
				$normalizedNew = [System.IO.Path]::GetFullPath($envValue)
				if ($normalizedExisting -eq $normalizedNew) {
					$shouldUpdate = $false
				}
			} elseif ($existingValue -eq $envValue) {
				# For non-paths, exact match is required
				$shouldUpdate = $false
			}
		}

		if ($shouldUpdate) {
			Write-Verbose "Set environment variable of $envCommand`: $envKey - > $envValue"
			try {
				[System.Environment]::SetEnvironmentVariable($envKey, $envValue, "User")
				Write-ColorText "{Blue}[environment] {Green}(updated) {Magenta}$envKey {Yellow}--> {Gray}$envValue"
			} catch {
				Write-Error "An error occurred: $_"
			}
		} else {
			Write-ColorText "{Blue}[environment] {Yellow}(exists) {Magenta}$envKey {Yellow}--> {Gray}$existingValue"
		}
	} else {
		Write-ColorText "{Blue}[environment] {Red}(skipped) {Magenta}$envKey {Yellow}--> {Gray}Command '$envCommand' not found"
	}
}

# Handle gh-dash special case
if (Get-Command gh -ErrorAction SilentlyContinue) {
	$ghDashAvailable = (& gh.exe extension list | Select-String -Pattern "dlvhdr / gh-dash" -SimpleMatch -CaseSensitive)
	if ($ghDashAvailable) {
		$ghDashConfigPath = Join-Path -Path $HOME -ChildPath ".config\gh-dash\config.yml"
		if (![System.Environment]::GetEnvironmentVariable("GH_DASH_CONFIG")) {
			try {
				[System.Environment]::SetEnvironmentVariable("GH_DASH_CONFIG", $ghDashConfigPath, "User")
				Write-ColorText "{Blue}[environment] {Green}(added) {Magenta}GH_DASH_CONFIG {Yellow}--> {Gray}$ghDashConfigPath"
			} catch {
				Write-Error -ErrorAction Stop "An error occurred: $_"
			}
		} else {
			$value = [System.Environment]::GetEnvironmentVariable("GH_DASH_CONFIG")
			Write-ColorText "{Blue}[environment] {Yellow}(exists) {Magenta}GH_DASH_CONFIG {Yellow}--> {Gray}$value"
		}
	}
}
Refresh ($i++)

# plugins / extensions / addons
$myAddons = $json.packageAddon
foreach ($a in $myAddons) {
	$aCommandName = $a.commandName
	$aCommandCheck = $a.commandCheck
	$aCommandInvoke = $a.commandInvoke
	$aList = [array]$a.addonList
	$aInstall = $a.install

	if ($aInstall -eq $True) {
		if (Get-Command $aCommandName -ErrorAction SilentlyContinue) {
			Write-TitleBox -Title "$aCommandName's Addons Installation"
			foreach ($p in $aList) {
				if (Invoke-Expression "$aCommandCheck" | Out-String | Where-Object { $_ -notmatch "$p*" }) {
					Write-Verbose "Executing: $aCommandInvoke $p"
					Invoke-Expression "$aCommandInvoke $p >`$null 2>&1"
					if ($LASTEXITCODE -eq 0) {	Write-ColorText "➕ {Blue}[addon] {Magenta}$aCommandName`: {Green}(success) {Gray}$p" }
					else {	Write-ColorText "➕ {Blue}[addon] {Magenta}$aCommandName`: {Red}(failed) {Gray}$p" }
				} else { Write-ColorText "➕ {Blue}[addon] {Magenta}$aCommandName`: {Yellow}(exists) {Gray}$p" }
			}
		}
	}
}
Refresh ($i++)

# Themes

Write-TitleBox -Title "😎 Per Application Theme Installation"
$catppuccinThemes = @('Mocha')

# FLowlauncher
$flowLauncherDir = "$env:APPDATA\FlowLauncher"
if (Test-Path "$flowLauncherDir" -PathType Container) {
	$flowLauncherThemeDir = Join-Path "$flowLauncherDir" -ChildPath "Themes"
	$catppuccinThemes | ForEach-Object {
		$themeFile = Join-Path "$flowLauncherThemeDir" -ChildPath "Catppuccin ${_}.xaml"
		if (!(Test-Path "$themeFile" -PathType Leaf)) {
			Write-Verbose "Adding file: $themeFile to $flowLauncherThemeDir."
			Install-OnlineFile -OutputDir "$flowLauncherThemeDir" -Url "https://raw.githubusercontent.com/catppuccin/flow-launcher/refs/heads/main/themes/Catppuccin%20${_}.xaml"
			if ($LASTEXITCODE -eq 0) {
				Write-ColorText "{Blue}[theme] {Magenta}flowlauncher: {Green}(success) {Gray}$themeFile"
			} else {
				Write-ColorText "{Blue}[theme] {Magenta}flowlauncher: {Red}(failed) {Gray}$themeFile"
			}
		} else { Write-ColorText "{Blue}[theme] {Magenta}flowlauncher: {Yellow}(exists) {Gray}$themeFile" }
	}
}

$catppuccinThemes = $catppuccinThemes.ToLower()

# add btop theme
# since we install btop by scoop, then the application folder would be in scoop directory
$btopExists = Get-Command btop -ErrorAction SilentlyContinue
if ($btopExists) {
	if ($btopExists.Source | Select-String -SimpleMatch -CaseSensitive "scoop") {
		$btopThemeDir = Join-Path (scoop prefix btop) -ChildPath "themes"
	} else {
		$btopThemeDir = Join-Path ($btopExists.Source | Split-Path) -ChildPath "themes"
	}
	$catppuccinThemes | ForEach-Object {
		$themeFile = Join-Path "$btopThemeDir" -ChildPath "catppuccin_${_}.theme"
		if (!(Test-Path "$themeFile" -PathType Leaf)) {
			Write-Verbose "Adding file: $themeFile to $btopThemeDir."
			Install-OnlineFile -OutputDir "$btopThemeDir" -Url "https://raw.githubusercontent.com/catppuccin/btop/refs/heads/main/themes/catppuccin_${_}.theme"
			if ($LASTEXITCODE -eq 0) {
				Write-ColorText "{Blue}[theme] {Magenta}btop: {Green}(success) {Gray}$themeFile"
			} else {
				Write-ColorText "{Blue}[theme] {Magenta}btop: {Red}(failed) {Gray}$themeFile"
			}
		} else { Write-ColorText "{Blue}[theme] {Magenta}btop: {Yellow}(exists) {Gray}$themeFile" }
	}
}

# yazi plugins
Write-TitleBox "🦀 Miscellaneous"
if (Get-Command ya -ErrorAction SilentlyContinue) {
	Write-Verbose "Installing yazi plugins / themes"
	ya pack -i >$null 2>&1
	ya pack -u >$null 2>&1
}

# UV
# powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"

# https://rustup.rs/
# Install cargo-update & cache
# if (Get-Command cargo -ErrorAction SilentlyContinue) {
# 	Write-Verbose "Configuring Cargo"
# 	cargo install cargo-update
# 	cargo install cargo-cache
# }

# bat build theme
if (Get-Command bat -ErrorAction SilentlyContinue) {
	Write-Verbose "Building bat theme"
	bat cache --clear
	bat cache --build
}

Write-TitleBox "👾 Komorebi & Yasb Engines"

# yasb
if (Get-Command yasbc -ErrorAction SilentlyContinue) {
	if (!(Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -match "yasb*" } )) {
		try { & yasbc.exe enable-autostart --task } catch { Write-Error "$_" }
	} else {
		$yasbTaskName = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -match "yasb*" } | Select-Object -ExpandProperty TaskName
		Write-Host "✅ Task: $yasbTaskName already created."
	}
	if (!(Get-Process -Name yasb -ErrorAction SilentlyContinue)) {
		try { & yasbc.exe start } catch { Write-Error "$_" }
	} else {
		Write-Host "✅ YASB Status Bar is already running."
	}
} else {
	Write-Warning "Command not found: yasbc."
}

# komorebi
if (Get-Command komorebic -ErrorAction SilentlyContinue) {
	komorebic fetch-asc
	# Registry: Long path support for komorebi
	# - https://lgug2z.github.io/komorebi/installation.html#installation

	# $longPathPath = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"
	# $longPathName = "LongPathsEnabled"
	# $longPathValue = 1
	# if ($null -eq $((Get-ItemProperty -Path $longPathPath -ErrorAction SilentlyContinue).LongPathsEnabled) -or ($(Get-ItemPropertyValue -Path $longPathPath -Name $longPathName -ErrorAction SilentlyContinue) -ne 1)) {
	# 	Set-ItemProperty -Path $longPathPath -Name $longPathName -Value $longPathValue
	# }

	if (!(Get-Process -Name komorebi -ErrorAction SilentlyContinue)) {
		$whkdExists = Get-Command whkd -ErrorAction SilentlyContinue
		$whkdProcess = Get-Process -Name whkd -ErrorAction SilentlyContinue
		if ($whkdExists -and (!(Test-Path "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\komorebi.lnk"))) {
			try { Start-Process "powershell.exe" -ArgumentList "komorebic.exe", "enable-autostart", "--whkd" -WindowStyle Hidden -Wait }
			catch { Write-Error "$_" }
		} else {
			Write-Host "✅ Shortcut: komorebi.lnk created in shell:Startup."
		}
		Write-Host "Starting Komorebi in the background..."
		if ($whkdExists -and (!$whkdProcess)) {
			try { Start-Process "powershell.exe" -ArgumentList "komorebic.exe", "start", "--whkd" -WindowStyle Hidden }
			catch { Write-Error "$_" }
		}
	} else {
		Write-Host "✅ Komorebi Tiling Window Management is already running."
	}
} else {
	Write-Warning "Command not found: komorebic."
}

# steam
# iwr -useb "https://steambrew.app/install.ps1" | iex

# WSL
if (!(Get-Command wsl -CommandType Application -ErrorAction Ignore)) {
	Write-Verbose -Message "Installing Windows SubSystems for Linux..."
	Start-Process -FilePath "PowerShell" -ArgumentList "wsl", "--install" -Verb RunAs -Wait -WindowStyle Hidden
}

# End
Set-Location $currentLocation
Start-Sleep -Seconds 5

Write-Host "`n----------------------------------------------------------------------------------`n" -ForegroundColor DarkGray
Write-Host "┌────────────────────────────────────────────────────────────────────────────────┐" -ForegroundColor "Green"
Write-Host "│                                                                                │" -ForegroundColor "Green"
Write-Host "│        █████╗ ██╗     ██╗         ██████╗  ██████╗ ███╗   ██╗███████╗ ██╗      │" -ForegroundColor "Green"
Write-Host "│       ██╔══██╗██║     ██║         ██╔══██╗██╔═══██╗████╗  ██║██╔════╝ ██║      │" -ForegroundColor "Green"
Write-Host "│       ███████║██║     ██║         ██║  ██║██║   ██║██╔██╗ ██║█████╗   ██║      │" -ForegroundColor "Green"
Write-Host "│       ██╔══██║██║     ██║         ██║  ██║██║   ██║██║╚██╗██║██╔══╝   ╚═╝      │" -ForegroundColor "Green"
Write-Host "│       ██║  ██║███████╗███████╗    ██████╔╝╚██████╔╝██║ ╚████║███████╗ ██╗      │" -ForegroundColor "Green"
Write-Host "│       ╚═╝  ╚═╝╚══════╝╚══════╝    ╚═════╝  ╚═════╝ ╚═╝  ╚═══╝╚══════╝ ╚═╝      │" -ForegroundColor "Green"
Write-Host "│                                                                                │" -ForegroundColor "Green"
Write-Host "└────────────────────────────────────────────────────────────────────────────────┘" -ForegroundColor "Green"

Write-ColorText "`n`n{Grey}For more information, please visit: {Blue}https://github.com/cwelsys/windows`n"
Write-ColorText "😤 {Gray}Submit an issue via: {Blue}https://github.com/cwelsys/windows/issues/new"
Write-ColorText "📨 {Gray}Contact me via email: {Cyan}cwel@cwel.sh"
