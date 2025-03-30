<#PSScriptInfo

.VERSION 1.0.9

.GUID 7953dd1e-d2a8-4714-8e13-38ddf45fe9f1

.AUTHOR cwel@cwel.sh

.COMPANYNAME

.COPYRIGHT 2025 Connor Welsh. All rights reserved.

.TAGS windows dotfiles powershell

.LICENSEURI https://github.com/cwelsys/windows/blob/main/LICENSE

.PROJECTURI https://github.com/cwelsys/windows

.ICONURI

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES

.PRIVATEDATA

#>

#Requires -Version 7
#Requires -RunAsAdministrator

<#

.DESCRIPTION
	Sets up Windows apps/package managers and more.

#>
Param()

$VerbosePreference = "SilentlyContinue"

##########################################################################
###												  	HELPER FUNCTIONS												 ###
##########################################################################

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

	$Text.Split([char]'{', [char]'}') | ForEach-Object -Begin { $i = 0 } -Process {
		if ($i % 2 -eq 0) { Write-Host $_ -NoNewline }
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

function New-SymbolicLinks {
	param (
		[string]$Source,
		[string]$Destination,
		[switch]$Recurse,
		[array]$Overrides = @()
	)

	# Create destination directory if it doesn't exist
	if (!(Test-Path $Destination)) {
		New-Item -Path $Destination -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
	}

	# Get all items in the source directory
	$items = Get-ChildItem $Source -Force -Recurse:$Recurse

	# Normalize all override paths (convert to lowercase and use consistent path separators)
	# Ensure we only process non-null values
	$normalizedOverrides = @()
	if ($Overrides -and $Overrides.Count -gt 0) {
		$normalizedOverrides = $Overrides | Where-Object { $_ } | ForEach-Object {
			$_.ToLower().Replace('\', '/')
		}
		Write-Verbose "Processing with $($normalizedOverrides.Count) normalized overrides"

		# Log the overrides for better visibility
		Write-Verbose "Override paths:"
		$normalizedOverrides | ForEach-Object { Write-Verbose "  - $_" }
	}

	foreach ($item in $items) {
		# Skip if it's the AppData directory itself
		if ($item.Name -eq "AppData") {
			continue
		}

		# For files in the home directory, link directly to the destination
		if ($Source -like "*\home") {
			$destinationPath = Join-Path $Destination $item.Name
		} else {
			# For other directories, maintain the relative path structure
			$relativePath = $item.FullName.Substring($Source.Length + 1)
			$destinationPath = Join-Path $Destination $relativePath
		}

		# Create parent directory if it doesn't exist
		$parentDir = Split-Path $destinationPath -Parent
		if (!(Test-Path $parentDir)) {
			New-Item -Path $parentDir -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
		}

		# Check if this file is in the override list
		$isOverride = $false
		if ($normalizedOverrides.Count -gt 0) {
			$normalizedItemPath = $item.FullName.ToLower().Replace('\', '/')

			foreach ($override in $normalizedOverrides) {
				# Check for exact match or wildcard match
				if ($normalizedItemPath -eq $override -or
					$normalizedItemPath -like $override -or
					$normalizedItemPath -like "$override*" -or
					$normalizedItemPath -match [regex]::Escape($override)) {
					$isOverride = $true
					Write-Verbose "Found override match for: $($item.FullName)"
					Write-Verbose "  Matched pattern: $override"
					break
				}
			}
		}

		# For overrides, delete the target if it exists
		if ($isOverride -and (Test-Path $destinationPath)) {
			$fileAttributes = (Get-Item $destinationPath -Force).Attributes
			# Check if target is already a symbolic link
			$isSymlink = ($fileAttributes -band [System.IO.FileAttributes]::ReparsePoint) -eq [System.IO.FileAttributes]::ReparsePoint

			if (!$isSymlink) {
				Remove-Item -Path $destinationPath -Force -ErrorAction SilentlyContinue
				Write-ColorText "{Blue}[symlink] {Yellow}(override) {Red}Removed existing file: {Gray}$destinationPath"
			}
		}

		# Create the symlink
		if (!(Test-Path $destinationPath) -or $isOverride) {
			try {
				New-Item -ItemType SymbolicLink -Path $destinationPath -Target $item.FullName -Force -ErrorAction Stop | Out-Null
				Write-ColorText "{Blue}[symlink] {Green}$($item.FullName) {Yellow}--> {Gray}$destinationPath"
			} catch {
				Write-ColorText "{Blue}[symlink] {Red}Failed to create symlink: {Gray}$($_.Exception.Message)"
			}
		}
	}
}

function Get-SymlinkOverrides {
	param (
		[string]$ConfigPath = "$PSScriptRoot\config.yaml"
	)

	$overrides = @()

	if (!(Test-Path $ConfigPath)) {
		Write-ColorText "{Blue}[symlink] {Yellow}No config file found at {Gray}$ConfigPath"
		return $overrides
	}

	try {
		$module = "powershell-yaml"
		if (!(Get-Module -ListAvailable -Name $module -ErrorAction SilentlyContinue)) {
			Write-ColorText "{Yellow}PowerShell-Yaml module not found. Installing..."
			Install-Module $module -Scope CurrentUser -Force -ErrorAction Stop
		}

		Import-Module $module -ErrorAction Stop
		$content = Get-Content -Path $ConfigPath -Raw
		$config = ConvertFrom-Yaml -Yaml $content
		if ($config.symlinks -and $config.symlinks.overrides) {
			$overrides = $config.symlinks.overrides
		}
	} catch {
		Write-ColorText "{Blue}[symlink] {Red}Error parsing YAML file: {Gray}$($_.Exception.Message)"
	}

	# Log each override path for debugging
	if ($overrides.Count -gt 0) {
		Write-ColorText "{Blue}[symlink] {Green}Loaded {Yellow}$($overrides.Count) {Green}overrides from config"
		$overrides | ForEach-Object {
			Write-Verbose "  Override: $_"
		}
	} else {
		Write-ColorText "{Blue}[symlink] {Yellow}No override paths found in {Gray}$ConfigPath"
	}

	return $overrides
}

function Get-YamlConfig {
	param (
		[string]$ConfigPath = "$PSScriptRoot\config.yaml"
	)

	if (!(Test-Path $ConfigPath)) {
		Write-ColorText "{Red}Config file not found at {Gray}$ConfigPath"
		exit 1
	}

	try {
		$module = "powershell-yaml"
		if (!(Get-Module -ListAvailable -Name $module -ErrorAction SilentlyContinue)) {
			Write-ColorText "{Yellow}PowerShell-Yaml module not found. Installing..."
			Install-Module $module -Scope CurrentUser -Force -ErrorAction Stop
		}

		Import-Module $module -ErrorAction Stop
		try {
			$content = Get-Content -Path $ConfigPath -Raw
			$config = ConvertFrom-Yaml -Yaml $content -ErrorAction Stop
			return $config
		} catch {
			Write-ColorText "{Red}Error parsing YAML file: {Gray}$($_.Exception.Message)"
			exit 1
		}
	} catch {
		Write-ColorText "{Red}Failed to load PowerShell-Yaml module: {Gray}$($_.Exception.Message)"
		exit 1
	}
}

########################################################################
###														MAIN SCRIPT 		  					 			 		 ###
########################################################################
# check network connectivity
$internetConnection = Test-NetConnection google.com -CommonTCPPort HTTP -InformationLevel Detailed -WarningAction SilentlyContinue
$internetAvailable = $internetConnection.TcpTestSucceeded
if ($internetAvailable -eq $False) {
	Write-Warning "NO INTERNET CONNECTION AVAILABLE!"
	Write-Host "Please check your internet connection and re-run this script.`n"
	for ($countdown = 3; $countdown -ge 0; $countdown--) {
		Write-ColorText "`r{DarkGray}Automatically exiting in {Blue}$countdown second(s){DarkGray}..." -NoNewLine
		Start-Sleep -Seconds 1
	}
	exit
}

Write-Progress -Completed; Clear-Host
Write-ColorText "`n✅ {Green}Connected.`n`n{DarkGray}Starting setup..."
Start-Sleep -Seconds 3

# Save the current location to return to later
$scriptStartLocation = $PWD.Path

# set current working directory
Set-Location $PSScriptRoot
[System.Environment]::CurrentDirectory = $PSScriptRoot

$i = 1

########################################################################
###													PACKAGES 			 									 				 ###
########################################################################
# Parse the YAML configuration
$config = Get-YamlConfig

# Extract feature flags
$packagesEnabled = $config.features.packages -eq $true
$wingetEnabled = $config.features.winget -eq $true
$scoopEnabled = $config.features.scoop -eq $true
$chocolateyEnabled = $config.features.chocolatey -eq $true

if ($packagesEnabled) {
	Write-TitleBox "📦 PACKAGES"

	# WinGet packages
	if ($wingetEnabled) {
		Write-ColorText "{Green}Installing WinGet packages..."
		foreach ($package in $config.packages.winget.packages) {
			$id = $package.id
			$packageArgs = $package.args
			if ($null -eq $packageArgs) {
				$packageArgs = $config.packages.winget.additional_args
			} else {
				$packageArgs = $config.packages.winget.additional_args + $packageArgs
			}
			Install-WinGetApp -PackageID $id -AdditionalArgs $packageArgs
		}
		Write-ColorText "{Green}WinGet packages installed successfully!"
	}

	# Scoop packages
	if ($scoopEnabled) {
		Write-ColorText "{Green}Setting up Scoop..."

		# Add buckets
		foreach ($bucket in $config.packages.scoop.buckets) {
			$name = $bucket.name
			$repo = $bucket.repo
			Add-ScoopBucket -BucketName $name -BucketRepo $repo
		}

		# Install packages
		foreach ($package in $config.packages.scoop.packages) {
			$name = $package.name
			$scope = $package.scope
			Install-ScoopApp -Package $name -Global:($scope -eq "global")
		}
		Write-ColorText "{Green}Scoop packages installed successfully!"
	}

	# Chocolatey packages
	if ($chocolateyEnabled) {
		Write-ColorText "{Green}Installing Chocolatey packages..."
		foreach ($package in $config.packages.chocolatey.packages) {
			$name = $package.name
			$packageArgs = $package.args
			if ($null -eq $packageArgs) {
				$packageArgs = $config.packages.chocolatey.additional_args
			} else {
				$packageArgs = $config.packages.chocolatey.additional_args + $packageArgs
			}
			Install-ChocoApp -Package $name -AdditionalArgs $packageArgs
		}
		Write-ColorText "{Green}Chocolatey packages installed successfully!"
	}
} else {
	Write-ColorText "{Yellow}Package installation is disabled in config."
}

########################################################################
###                          POWERSHELL                              ###
########################################################################
$powershellEnabled = $config.features.powershell -eq $true

if ($powershellEnabled) {
	Write-TitleBox "🔧 POWERSHELL"

	# Install PowerShell modules
	Write-ColorText "{Green}Installing PowerShell modules..."
	foreach ($module in $config.powershell.modules) {
		$name = $module.name
		$version = $module.min_version
		Install-PowerShellModule -Module $name -Version $version -AdditionalArgs $config.powershell.additional_args
	}

	# Configure experimental features if enabled
	if ($config.powershell.experimental_features.enable) {
		Write-ColorText "{Green}Enabling PowerShell experimental features..."
		foreach ($feature in $config.powershell.experimental_features.features) {
			$featureExists = Get-ExperimentalFeature -Name $feature -ErrorAction SilentlyContinue
			if ($featureExists -and ($featureExists.Enabled -eq $False)) {
				Enable-ExperimentalFeature -Name $feature -Scope CurrentUser -ErrorAction SilentlyContinue
				if ($LASTEXITCODE -eq 0) {
					Write-ColorText "{Blue}[experimental feature] {Magenta}pwsh: {Green}(success) {Gray}$feature"
				} else {
					Write-ColorText "{Blue}[experimental feature] {Magenta}pwsh: {Red}(failed) {Gray}$feature"
				}
			} else {
				Write-ColorText "{Blue}[experimental feature] {Magenta}pwsh: {Yellow}(enabled) {Gray}$feature"
			}
		}
	}

	Write-ColorText "{Green}PowerShell configuration complete!"
} else {
	Write-ColorText "{Yellow}PowerShell configuration is disabled in config."
}

####################################################################
###															SYMLINKS 												 ###
####################################################################
$symlinksEnabled = $config.features.symlinks -eq $true

if ($symlinksEnabled) {
	Write-TitleBox "🔗 SYMLINKS"

	# Create symlinks for each directory
	Write-ColorText "{Green}Creating symlinks..."

	# Get directory mappings from config
	$symlinkDirs = $config.symlinks.directories
	foreach ($dir in $symlinkDirs) {
		$source = $dir.source
		# Replace environment variables in paths
		$destination = $dir.destination -replace "%USERPROFILE%", $env:USERPROFILE

		# Create symlinks
		New-SymbolicLinks -Source "$PSScriptRoot\$source" -Destination $destination -Recurse -Overrides $config.symlinks.overrides
	}
	Write-ColorText "{Green}Symlinks created successfully!"
} else {
	Write-ColorText "{Yellow}Symlinks configuration is disabled in config."
}

##########################################################################
###													ENVIRONMENT VARIABLES											 ###
##########################################################################
$environmentEnabled = $config.features.environment -eq $true

if ($environmentEnabled) {
	Write-TitleBox -Title "🌏 Environment Variables"
	if ($config.environment) {
		foreach ($env in $config.environment) {
			$envCommand = $env.command
			$envKey = $env.key
			$envValue = $env.value
			if (Get-Command $envCommand -ErrorAction SilentlyContinue) {
				$isRelativePath = $envValue.StartsWith('.') -or
					($envValue -match '^[^:]+[\\/]' -and -not $envValue.Contains(':'))
				if ($isRelativePath) {
					if ($envValue -match '^\.?config\\') {
						$envValue = $envValue -replace '^config\\', '.config\'
						$envValue = $envValue -replace '^\.config\\', '.config\'
					}
					$expandedValue = Join-Path -Path $HOME -ChildPath $envValue
					$envValue = $expandedValue
				}
				$existingValue = [System.Environment]::GetEnvironmentVariable($envKey, "User")
				$shouldUpdate = $true
				if (![string]::IsNullOrEmpty($existingValue)) {
					if ($isRelativePath) {
						$normalizedExisting = [System.IO.Path]::GetFullPath($existingValue)
						$normalizedNew = [System.IO.Path]::GetFullPath($envValue)
						if ($normalizedExisting -eq $normalizedNew) {
							$shouldUpdate = $false
						}
					} elseif ($existingValue -eq $envValue) {
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
	}
	$iterationCounter = $i++  # Use a different variable to avoid the unused variable warning
	Refresh $iterationCounter
} else {
	Write-ColorText "{Yellow}Environment variable configuration is disabled in config."
}

#######################################################################
###														ADDONS / PLUGINS											 ###
########################################################################
$addonsEnabled = $config.features.addons -eq $true

if ($addonsEnabled) {
	Write-TitleBox "🧩 ADDONS"
	if ($config.addons) {
		foreach ($a in $config.addons) {
			$aCommandName = $a.command
			$aCommandCheck = $a.command_check
			$aCommandInvoke = $a.command_invoke
			$aList = [array]$a.packages
			$aInstall = $a.install

			if ($aInstall -eq $true) {
				if (Get-Command $aCommandName -ErrorAction SilentlyContinue) {
					Write-TitleBox -Title "$aCommandName's Addons Installation"
					foreach ($p in $aList) {
						if (Invoke-Expression "$aCommandCheck" | Out-String | Where-Object { $_ -notmatch "$p*" }) {
							Write-Verbose "Executing: $aCommandInvoke $p"
							Invoke-Expression "$aCommandInvoke $p >`$null 2>&1"
							if ($LASTEXITCODE -eq 0) {
								Write-ColorText "➕ {Blue}[addon] {Magenta}$aCommandName`: {Green}(success) {Gray}$p"
							} else {
								Write-ColorText "➕ {Blue}[addon] {Magenta}$aCommandName`: {Red}(failed) {Gray}$p"
							}
						} else {
							Write-ColorText "➕ {Blue}[addon] {Magenta}$aCommandName`: {Yellow}(exists) {Gray}$p"
						}
					}
				} else {
					Write-Warning "Command not found: $aCommandName."
				}
			}
		}
		Refresh ($i++)
	}
} else {
	Write-ColorText "{Yellow}Addons configuration is disabled in config."
}

##########################################################################
###													THEMES 								 				 						###
##########################################################################
$themesEnabled = $config.features.themes -eq $true

if ($themesEnabled) {
	Write-TitleBox -Title "😎 Themes"

	$catppuccinThemes = $config.themes.catppuccin_flavors
	if (-not $catppuccinThemes) {
		$catppuccinThemes = @('Mocha')
	}

	# flowlauncher
	if ($config.themes.flowlauncher -and $config.themes.flowlauncher.enable) {
		$flowLauncherDir = $config.themes.flowlauncher.theme_dir -replace "%APPDATA%", $env:APPDATA
		if (Test-Path "$flowLauncherDir" -PathType Container) {
			$catppuccinThemes | ForEach-Object {
				$themeFile = Join-Path "$flowLauncherDir" -ChildPath "Catppuccin ${_}.xaml"
				if (!(Test-Path "$themeFile" -PathType Leaf)) {
					Write-Verbose "Adding file: $themeFile to $flowLauncherDir."
					Install-OnlineFile -OutputDir "$themeFile" -Url "https://raw.githubusercontent.com/catppuccin/flow-launcher/refs/heads/main/themes/Catppuccin%20${_}.xaml"
					if ($LASTEXITCODE -eq 0) {
						Write-ColorText "{Blue}[theme] {Magenta}flowlauncher: {Green}(success) {Gray}$themeFile"
					} else {
						Write-ColorText "{Blue}[theme] {Magenta}flowlauncher: {Red}(failed) {Gray}$themeFile"
					}
				} else {
					Write-ColorText "{Blue}[theme] {Magenta}flowlauncher: {Yellow}(exists) {Gray}$themeFile"
				}
			}
		}
	}

	$lowercaseCatppuccinThemes = $catppuccinThemes | ForEach-Object { $_.ToLower() }

	# btop
	if ($config.themes.btop -and $config.themes.btop.enable) {
		$btopExists = Get-Command btop -ErrorAction SilentlyContinue
		if ($btopExists) {
			if ($btopExists.Source | Select-String -SimpleMatch -CaseSensitive "scoop") {
				$btopThemeDir = Join-Path (scoop prefix btop) -ChildPath "themes"
			} else {
				$btopThemeDir = Join-Path ($btopExists.Source | Split-Path) -ChildPath "themes"
			}
			$lowercaseCatppuccinThemes | ForEach-Object {
				$themeFile = Join-Path "$btopThemeDir" -ChildPath "catppuccin_${_}.theme"
				if (!(Test-Path "$themeFile" -PathType Leaf)) {
					Write-Verbose "Adding file: $themeFile to $btopThemeDir."
					Install-OnlineFile -OutputDir "$themeFile" -Url "https://raw.githubusercontent.com/catppuccin/btop/refs/heads/main/themes/catppuccin_${_}.theme"
					if ($LASTEXITCODE -eq 0) {
						Write-ColorText "{Blue}[theme] {Magenta}btop: {Green}(success) {Gray}$themeFile"
					} else {
						Write-ColorText "{Blue}[theme] {Magenta}btop: {Red}(failed) {Gray}$themeFile"
					}
				} else {
					Write-ColorText "{Blue}[theme] {Magenta}btop: {Yellow}(exists) {Gray}$themeFile"
				}
			}
		}
	}
} else {
	Write-ColorText "{Yellow}Theme configuration is disabled in config."
}

######################################################################
###														MISCELLANEOUS		 										 ###
######################################################################
$miscEnabled = $config.features.misc -eq $true

if ($miscEnabled) {
	Write-TitleBox "🦀 Miscellaneous"

	# yazi
	if (Get-Command ya -ErrorAction SilentlyContinue) {
		Write-Verbose "Installing yazi plugins / themes"
		ya pack -i >$null 2>&1
		ya pack -u >$null 2>&1
	}

	# bat
	if (Get-Command bat -ErrorAction SilentlyContinue) {
		Write-Verbose "Building bat theme"
		bat cache --clear
		bat cache --build
	}

	# Komorebi and YASB
	if ($config.misc) {
		Write-TitleBox "👾 Komorebi & Yasb"

		# yasb
		if ($config.misc.yasb -and $config.misc.yasb.enable) {
			if (Get-Command yasbc -ErrorAction SilentlyContinue) {
				if ($config.misc.yasb.enable_autostart) {
					if (!(Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -match "yasb*" })) {
						try {
							& yasbc.exe enable-autostart --task
						} catch {
							Write-Error "$_"
						}
					}
				}
				if (!(Get-Process -Name yasb -ErrorAction SilentlyContinue)) {
					try {
						& yasbc.exe start
					} catch {
						Write-Error "$_"
					}
				} else {
					Write-Host "✅ YASB is already running."
				}
			} else {
				Write-Warning "Command not found: yasbc."
			}
		}

		# komorebi
		if ($config.misc.komorebi -and $config.misc.komorebi.enable) {
			if (Get-Command komorebic -ErrorAction SilentlyContinue) {
				if (!(Get-Process -Name komorebi -ErrorAction SilentlyContinue)) {
					$whkdExists = Get-Command whkd -ErrorAction SilentlyContinue
					$whkdProcess = Get-Process -Name whkd -ErrorAction SilentlyContinue

					if ($config.misc.komorebi.enable_autostart) {
						if ($whkdExists -and (!(Test-Path "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\komorebi.lnk"))) {
							try {
								Start-Process "powershell.exe" -ArgumentList "komorebic.exe", "enable-autostart", "--whkd" -WindowStyle Hidden -Wait
							} catch {
								Write-Error "$_"
							}
						}
					}

					Write-Host "Starting Komorebi..."
					if ($whkdExists -and (!$whkdProcess)) {
						try {
							Start-Process "powershell.exe" -ArgumentList "komorebic.exe", "start", "--whkd" -WindowStyle Hidden
						} catch {
							Write-Error "$_"
						}
					}
				} else {
					Write-Host "✅ Komorebi is already running."
				}
			} else {
				Write-Warning "Command not found: komorebic."
			}
		}

		# WSL
		if ($config.misc.wsl_install) {
			if (!(Get-Command wsl -CommandType Application -ErrorAction Ignore)) {
				Write-Verbose -Message "Installing Windows SubSystems for Linux..."
				Start-Process -FilePath "PowerShell" -ArgumentList "wsl", "--install" -Verb RunAs -Wait -WindowStyle Hidden
			}
		}
	}
} else {
	Write-ColorText "{Yellow}Miscellaneous configuration is disabled in config."
}

# Return to the starting location
Set-Location $scriptStartLocation
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
