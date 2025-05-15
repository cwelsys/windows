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
		Write-Color -Text "[bucket] ", "scoop: ", "(exists) ", $BucketName -Color Blue, Magenta, Yellow, Gray
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
		Write-Color -Text "[package] ", "scoop: ", "(exists) ", $Package -Color Blue, Magenta, Yellow, Gray
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
			Write-Color -Text "[package] ", "winget: ", "(success) ", $PackageID -Color Blue, Magenta, Green, Gray
		} else {
			Write-Color -Text "[package] ", "winget: ", "(failed) ", $PackageID -Color Blue, Magenta, Red, Gray
		}
	} else {
		Write-Color -Text "[package] ", "winget: ", "(exists) ", $PackageID -Color Blue, Magenta, Yellow, Gray
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
			Write-Color -Text "[package] ", "choco: ", "(success) ", $Package -Color Blue, Magenta, Green, Gray
		} else {
			Write-Color -Text "[package] ", "choco: ", "(failed) ", $Package -Color Blue, Magenta, Red, Gray
		}
	} else {
		Write-Color -Text "[package] ", "choco: ", "(exists) ", $Package -Color Blue, Magenta, Yellow, Gray
	}
}

function Install-PowerShellModule {
	param ([string]$Module, [string]$Version, [array]$AdditionalArgs)

	if (!(Get-InstalledModule -Name $Module -ErrorAction SilentlyContinue)) {
		Write-Color -Text "[module] ", "pwsh: ", "Installing $Module..." -Color Blue, Magenta, Gray
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
				Write-Color -Text "[module] ", "pwsh: ", "(success) ", $Module -Color Blue, Magenta, Green, Gray
			} else {
				Write-Color -Text "[module] ", "pwsh: ", "(failed) ", "$Module - module not found after installation attempt" -Color Blue, Magenta, Red, Gray
			}
		} catch {
			Write-Color -Text "[module] ", "pwsh: ", "(failed) ", "$Module - $($_.Exception.Message)" -Color Blue, Magenta, Red, Gray
		}
	} else {
		Write-Color -Text "[module] ", "pwsh: ", "(exists) ", $Module -Color Blue, Magenta, Yellow, Gray
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
				Write-Color -Text "`n✔️  Packages installed by ", $PackageSource, " are exported at ", $((Resolve-Path $dest).Path) -Color White, Green, Gray, Red
			}
			Start-Sleep -Seconds 1
		}
		"choco" {
			if (!(Get-Command choco -ErrorAction SilentlyContinue)) { return }
			choco export $dest | Out-Null
			if ($LASTEXITCODE -eq 0) {
				Write-Color -Text "`n✔️  Packages installed by ", $PackageSource, " are exported at ", $((Resolve-Path $dest).Path) -Color White, Green, Gray, Red
			}
			Start-Sleep -Seconds 1
		}
		"scoop" {
			if (!(Get-Command scoop -ErrorAction SilentlyContinue)) { return }
			scoop export -c > $dest
			if ($LASTEXITCODE -eq 0) {
				Write-Color -Text "`n✔️  Packages installed by ", $PackageSource, " are exported at ", $((Resolve-Path $dest).Path) -Color White, Green, Gray, Red
			}
			Start-Sleep -Seconds 1
		}
		"modules" {
			Get-InstalledModule | Select-Object -Property Name, Version | ConvertTo-Json -Depth 100 | Out-File $dest
			if ($LASTEXITCODE -eq 0) {
				Write-Color -Text "`n✔️  ", "PowerShell Modules ", "installed are exported at ", $((Resolve-Path $dest).Path) -Color White, Green, Gray, Red
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
			# Check if the path is relative (doesn't start with a drive letter or UNC path)
			if (-not [System.IO.Path]::IsPathRooted($_)) {
				# Convert relative path to absolute path using the script's location
				$_ = Join-Path $PSScriptRoot $_
			}
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
				Write-Color -Text "[symlink] ", "(override) ", "Removed existing file: ", $destinationPath -Color Blue, Yellow, Red, Gray
			}
		}

		# Create the symlink
		if (!(Test-Path $destinationPath) -or $isOverride) {
			try {
				New-Item -ItemType SymbolicLink -Path $destinationPath -Target $item.FullName -Force -ErrorAction Stop | Out-Null
				Write-Color -Text "[symlink] ", $($item.FullName), " --> ", $destinationPath -Color Blue, Green, Yellow, Gray
			} catch {
				Write-Color -Text "[symlink] ", "Failed to create symlink: ", $($_.Exception.Message) -Color Blue, Red, Gray
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
		Write-Color -Text "[symlink] ", "No config file found at ", $ConfigPath -Color Blue, Yellow, Gray
		return $overrides
	}

	try {
		$module = "powershell-yaml"
		if (!(Get-Module -ListAvailable -Name $module -ErrorAction SilentlyContinue)) {
			Write-Color -Text "PowerShell-Yaml module not found. Installing..." -Color Yellow
			Install-Module $module -Scope CurrentUser -Force -ErrorAction Stop
		}

		Import-Module $module -ErrorAction Stop
		$content = Get-Content -Path $ConfigPath -Raw
		$config = ConvertFrom-Yaml -Yaml $content
		if ($config.symlinks -and $config.symlinks.overrides) {
			$overrides = $config.symlinks.overrides
		}
	} catch {
		Write-Color -Text "[symlink] ", "Error parsing YAML file: ", $($_.Exception.Message) -Color Blue, Red, Gray
	}

	# Log each override path for debugging
	if ($overrides.Count -gt 0) {
		Write-Color -Text "[symlink] ", "Loaded ", $overrides.Count, " overrides from config" -Color Blue, Green, Yellow, Green
		$overrides | ForEach-Object {
			Write-Verbose "  Override: $_"
		}
	} else {
		Write-Color -Text "[symlink] ", "No override paths found in ", $ConfigPath -Color Blue, Yellow, Gray
	}

	return $overrides
}

function Get-YamlConfig {
	param (
		[string]$ConfigPath = "$PSScriptRoot\config.yaml"
	)

	if (!(Test-Path $ConfigPath)) {
		Write-Color -Text "Config file not found at ", $ConfigPath -Color Red, Gray
		exit 1
	}

	try {
		$module = "powershell-yaml"
		if (!(Get-Module -ListAvailable -Name $module -ErrorAction SilentlyContinue)) {
			Write-Color -Text "PowerShell-Yaml module not found. Installing..." -Color Yellow
			Install-Module $module -Scope CurrentUser -Force -ErrorAction Stop
		}

		Import-Module $module -ErrorAction Stop
		try {
			$content = Get-Content -Path $ConfigPath -Raw
			$config = ConvertFrom-Yaml -Yaml $content -ErrorAction Stop
			return $config
		} catch {
			Write-Color -Text "Error parsing YAML file: ", $($_.Exception.Message) -Color Red, Gray
			exit 1
		}
	} catch {
		Write-Color -Text "Failed to load PowerShell-Yaml module: ", $($_.Exception.Message) -Color Red, Gray
		exit 1
	}
}

########################################################################
###														MAIN SCRIPT 		  					 			 		 ###
########################################################################
# Ensure PSWriteColor is installed and imported
if (-not (Get-Module -ListAvailable -Name PSWriteColor)) {
	Write-Host "Installing PSWriteColor module..."
	Install-Module -Name PSWriteColor -Force -Scope CurrentUser
}
Import-Module PSWriteColor

# check network connectivity
$internetConnection = Test-NetConnection google.com -CommonTCPPort HTTP -InformationLevel Detailed -WarningAction SilentlyContinue
$internetAvailable = $internetConnection.TcpTestSucceeded
if ($internetAvailable -eq $False) {
	Write-Warning "NO INTERNET CONNECTION AVAILABLE!"
	Write-Host "Please check your internet connection and re-run this script.`n"
	for ($countdown = 3; $countdown -ge 0; $countdown--) {
		Write-Color -Text "`r", "Automatically exiting in ", $countdown, " second(s)..." -Color DarkGray, Blue, DarkGray
		Start-Sleep -Seconds 1
	}
	exit
}

Write-Progress -Completed; Clear-Host
Write-Color -Text "`n✅ ", "Connected.", "`n`n", "Starting setup..." -Color White, Green, White, DarkGray
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
		Write-Color -Text "Installing WinGet packages..." -Color Green
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
		Write-Color -Text "WinGet packages installed successfully!" -Color Green
	}

	# Scoop packages
	if ($scoopEnabled) {
		Write-Color -Text "Setting up Scoop..." -Color Green
		if (!(Get-Command scoop -ErrorAction SilentlyContinue)) {
			Write-Verbose -Message "Installing scoop"
			Invoke-Expression "& {$(Invoke-RestMethod get.scoop.sh)} -RunAsAdmin"
		}

		# Configure aria2
		if (!(Get-Command aria2c -ErrorAction SilentlyContinue)) { scoop install aria2 }
		if (!($(scoop config aria2-enabled) -eq $True)) { scoop config aria2-enabled true }
		if (!($(scoop config aria2-warning-enabled) -eq $False)) { scoop config aria2-warning-enabled false }

		# Create a scheduled task for aria2 on startup
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
		Write-Color -Text "Scoop packages installed successfully!" -Color Green
	}

	# Chocolatey packages
	if ($chocolateyEnabled) {
		Write-Color -Text "Installing Chocolatey packages..." -Color Green
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
		Write-Color -Text "Chocolatey packages installed successfully!" -Color Green
	}
} else {
	Write-Color -Text "Package installation is disabled in config." -Color Yellow
}

########################################################################
###                          POWERSHELL                              ###
########################################################################
$powershellEnabled = $config.features.powershell -eq $true

if ($powershellEnabled) {
	Write-TitleBox "💻 POWERSHELL"

	# Modules
	$skipModules = ($config.powershell.modules -and $config.powershell.modules.enable -eq $false)
	if (-not $skipModules) {
		foreach ($module in $config.powershell.modules) {
			Install-PowerShellModule -Module $module.name -Version $module.min_version -AdditionalArgs $config.powershell.additional_args
		}
	}

	# Experimental features
	$skipFeatures = ($config.powershell.experimental_features -and $config.powershell.experimental_features.enable -eq $false)
	if (-not $skipFeatures) {
		foreach ($feature in $config.powershell.experimental_features.features) {
			Enable-ExperimentalFeature -Name $feature -Scope CurrentUser
		}
	}
} else {
	Write-Color -Text "PowerShell configuration is disabled in config." -Color Yellow
}

####################################################################
###															SYMLINKS 												 ###
####################################################################
$symlinksEnabled = $config.features.symlinks -eq $true

if ($symlinksEnabled) {
	Write-TitleBox "🔗 SYMLINKS"

	# Create symlinks for each directory
	Write-Color -Text "Creating symlinks..." -Color Green

	# Get directory mappings from config
	$symlinkDirs = $config.symlinks.directories
	foreach ($dir in $symlinkDirs) {
		$source = $dir.source
		# Replace environment variables in paths
		$destination = $dir.destination -replace "%USERPROFILE%", $env:USERPROFILE

		# Create symlinks
		New-SymbolicLinks -Source "$PSScriptRoot\$source" -Destination $destination -Recurse -Overrides $config.symlinks.overrides
	}
	Write-Color -Text "Symlinks created successfully!" -Color Green
} else {
	Write-Color -Text "Symlinks configuration is disabled in config." -Color Yellow
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
						Write-Color -Text "[environment] ", "(updated) ", $envKey, " --> ", $envValue -Color Blue, Green, Magenta, Yellow, Gray
					} catch {
						Write-Error "An error occurred: $_"
					}
				} else {
					Write-Color -Text "[environment] ", "(exists) ", $envKey, " --> ", $existingValue -Color Blue, Yellow, Magenta, Yellow, Gray
				}
			} else {
				Write-Color -Text "[environment] ", "(skipped) ", $envKey, " --> ", "Command '$envCommand' not found" -Color Blue, Red, Magenta, Yellow, Gray
			}
		}
	}
	$iterationCounter = $i++  # Use a different variable to avoid the unused variable warning
	Refresh $iterationCounter
} else {
	Write-Color -Text "Environment variable configuration is disabled in config." -Color Yellow
}

#######################################################################
###														ADDONS / PLUGINS											 ###
########################################################################
$addonsEnabled = $config.features.addons -eq $true

if ($addonsEnabled) {
	Write-TitleBox "🧩 ADDONS"
	foreach ($addon in $config.addons) {
		$skipAddon = ($addon.install -eq $false)
		if (-not $skipAddon) {
			$commandName = $addon.command
			$commandCheck = $addon.command_check
			$commandInvoke = $addon.command_invoke
			if (Get-Command $commandName -ErrorAction SilentlyContinue) {
				foreach ($package in $addon.packages) {
					if (Invoke-Expression "$commandCheck" | Out-String | Where-Object { $_ -notmatch "$package*" }) {
						Invoke-Expression "$commandInvoke $package"
					}
				}
			}
		}
	}
	Refresh ($i++)
} else {
	Write-Color -Text "Addons configuration is disabled in config." -Color Yellow
}

##########################################################################
###                             THEMES                                 ###
##########################################################################
$themesEnabled = $config.features.themes -eq $true

if ($themesEnabled) {
	Write-TitleBox -Title "😎 THEMES"

	# Hard-coded defaults that will be used if not specified in config
	$defaultCatppuccinFlavors = @('Mocha', 'Macchiato', 'Frappe', 'Latte')

	# Get theme flavors to install
	$catppuccinFlavors = $defaultCatppuccinFlavors
	if ($config.themes -and $config.themes.catppuccin_flavors) {
		$catppuccinFlavors = $config.themes.catppuccin_flavors
	}

	# FlowLauncher themes
	$flowLauncherEnabled = $true  # Default to enabled
	if ($config.themes -and $config.themes.flowlauncher -and $config.themes.flowlauncher.enable -eq $false) {
		$flowLauncherEnabled = $false
	}

	# Check for custom Flow Launcher directory or use default
	$flowLauncherDir = "$env:APPDATA\FlowLauncher\Themes"
	if ($config.themes -and $config.themes.flowlauncher -and $config.themes.flowlauncher.theme_dir) {
		$flowLauncherDir = $config.themes.flowlauncher.theme_dir -replace "%APPDATA%", $env:APPDATA
	}

	# Process Flow Launcher themes if enabled
	if ($flowLauncherEnabled) {
		# Use the correct Flow Launcher path
		$flowLauncherDir = "$env:APPDATA\FlowLauncher\Themes"

		# Create themes directory if it doesn't exist
		if (!(Test-Path $flowLauncherDir -PathType Container)) {
			Write-Color -Text "Creating Flow Launcher themes directory: ", $flowLauncherDir -Color Yellow, Gray
			New-Item -ItemType Directory -Path $flowLauncherDir -Force | Out-Null
		}

		Write-Color -Text "Installing Flow Launcher themes..." -Color Green

		# Download and install each flavor - place directly in themes directory
		foreach ($flavor in $catppuccinFlavors) {
			# Use the correct URL format with master branch
			$themeUrl = "https://raw.githubusercontent.com/catppuccin/flow-launcher/refs/heads/main/themes/Catppuccin%20$flavor.xaml"
			$themePath = Join-Path $flowLauncherDir "catppuccin_$($flavor.ToLower()).xaml"

			try {
				Invoke-WebRequest -Uri $themeUrl -OutFile $themePath -ErrorAction Stop
				Write-Color -Text "[theme] ", "flowlauncher: ", "(installed) ", "Catppuccin $flavor" -Color Blue, Magenta, Green, Gray
			} catch {
				Write-Color -Text "[theme] ", "flowlauncher: ", "(failed) ", "Catppuccin $flavor - $($_.Exception.Message)" -Color Blue, Magenta, Red, Gray
			}
		}
	}

	# btop theme setup
	$btopEnabled = $true  # Default to enabled
	if ($config.themes -and $config.themes.btop -and $config.themes.btop.enable -eq $false) {
		$btopEnabled = $false
	}

	if ($btopEnabled) {
		Write-Color -Text "Installing btop themes..." -Color Green

		# Find btop's actual themes directory
		$btopConfigDir = "$env:USERPROFILE\.config\btop"

		# Also check if btop is installed via scoop for better path detection
		$btopCommand = Get-Command btop -ErrorAction SilentlyContinue
		if ($btopCommand) {
			if ($btopCommand.Source -match "scoop") {
				$btopConfigDir = Join-Path (scoop prefix btop) -ChildPath "themes"
			}
		}

		# # Create btop themes directory if needed
		if (!(Test-Path "$btopConfigDir")) {
			New-Item -ItemType Directory -Path "$btopConfigDir" -Force | Out-Null
		}

		# Download and install each flavor
		foreach ($flavor in $catppuccinFlavors) {
			$themeUrl = "https://raw.githubusercontent.com/catppuccin/btop/main/themes/catppuccin_$($flavor.ToLower()).theme"
			$themePath = "$btopConfigDir\catppuccin_$($flavor.ToLower()).theme"

			try {
				Invoke-WebRequest -Uri $themeUrl -OutFile $themePath -ErrorAction Stop
				Write-Color -Text "[theme] ", "btop: ", "(installed) ", "Catppuccin $flavor" -Color Blue, Magenta, Green, Gray
			} catch {
				Write-Color -Text "[theme] ", "btop: ", "(failed) ", "Catppuccin $flavor - $($_.Exception.Message)" -Color Blue, Magenta, Red, Gray
			}
		}
	}
}

# qBittorrent theme setup
$qBittorrentEnabled = $true  # Default to enabled
if ($config.themes -and $config.themes.qbittorrent -and $config.themes.qbittorrent.enable -eq $false) {
	$qBittorrentEnabled = $false
}

if ($qBittorrentEnabled) {
	Write-Color -Text "Installing qBittorrent themes..." -Color Green

	# Find qBittorrent's actual themes directory
	$qBittorrentThemeDir = "$env:USERPROFILE\.config\qBit\themes"

	# Check if qBittorrent is installed via scoop for better path detection
	$qBittorrentCommand = Get-Command qbittorrent -ErrorAction SilentlyContinue
	if ($qBittorrentCommand) {
		if ($qBittorrentCommand.Source -match "scoop") {
			$scoopQbtPath = Join-Path (scoop prefix qbittorrent) -ChildPath "themes"
			if (Test-Path $scoopQbtPath) {
				$qBittorrentThemeDir = $scoopQbtPath
			}
		}
	}

	# Create qBittorrent themes directory if needed
	if (!(Test-Path "$qBittorrentThemeDir")) {
		New-Item -ItemType Directory -Path "$qBittorrentThemeDir" -Force | Out-Null
		Write-Color -Text "Created directory: ", $qBittorrentThemeDir -Color Yellow, Gray
	}

	# Get the latest release tag dynamically using GitHub API
	$repoName = "catppuccin/qbittorrent"
	try {
		$release = "https://api.github.com/repos/$repoName/releases/latest"
		$releaseInfo = Invoke-RestMethod -Uri $release -ErrorAction Stop
		$latestTag = $releaseInfo.tag_name

		Write-Color -Text "Found latest qBittorrent theme release: ", $latestTag -Color Yellow, Gray

		# Download and install each flavor
		foreach ($flavor in $catppuccinFlavors) {
			$fileName = "catppuccin-$($flavor.ToLower()).qbtheme"
			$themeUrl = "https://github.com/$repoName/releases/download/$latestTag/$fileName"
			$themePath = "$qBittorrentThemeDir\$fileName"

			try {
				Invoke-WebRequest -Uri $themeUrl -OutFile $themePath -ErrorAction Stop
				Write-Color -Text "[theme] ", "qbittorrent: ", "(installed) ", "Catppuccin $flavor ($latestTag)" -Color Blue, Magenta, Green, Gray
			} catch {
				Write-Color -Text "[theme] ", "qbittorrent: ", "(failed) ", "Catppuccin $flavor - $($_.Exception.Message)" -Color Blue, Magenta, Red, Gray
			}
		}
	} catch {
		Write-Color -Text "[theme] ", "qbittorrent: ", "(error) ", "Failed to get latest release information: $($_.Exception.Message)" -Color Blue, Magenta, Red, Gray

		# Fallback to a known version if API call fails
		Write-Color -Text "Falling back to version v2.0.1..." -Color Yellow

		foreach ($flavor in $catppuccinFlavors) {
			$themeUrl = "https://github.com/catppuccin/qbittorrent/releases/download/v2.0.1/catppuccin-$($flavor.ToLower()).qbtheme"
			$themePath = "$qBittorrentThemeDir\catppuccin-$($flavor.ToLower()).qbtheme"

			try {
				Invoke-WebRequest -Uri $themeUrl -OutFile $themePath -ErrorAction Stop
				Write-Color -Text "[theme] ", "qbittorrent: ", "(installed) ", "Catppuccin $flavor (fallback)" -Color Blue, Magenta, Green, Gray
			} catch {
				Write-Color -Text "[theme] ", "qbittorrent: ", "(failed) ", "Catppuccin $flavor - $($_.Exception.Message)" -Color Blue, Magenta, Red, Gray
			}
		}
	}
}

######################################################################
###														MISCELLANEOUS		 										 ###
######################################################################
$miscEnabled = $config.features.misc -eq $true

if ($miscEnabled) {
	Write-TitleBox "🦀 MISCELLANEOUS"

	# WSL Installation
	$skipWsl = ($config.misc.wsl_install -eq $false)
	if (-not $skipWsl) {
		if (!(Get-Command wsl -CommandType Application -ErrorAction Ignore)) {
			Start-Process -FilePath "PowerShell" -ArgumentList "wsl", "--install" -Verb RunAs -Wait -WindowStyle Hidden
		}
	}

	# Komorebi
	$skipKomorebi = ($config.misc.komorebi -and $config.misc.komorebi.enable -eq $false)
	if (-not $skipKomorebi) {
		if ($config.misc.komorebi) {
			if (!(Get-Process -Name komorebi -ErrorAction SilentlyContinue)) {
				if ($config.misc.komorebi.enable_autostart) {
					Start-Process "powershell.exe" -ArgumentList "komorebic.exe", "enable-autostart", "--whkd" -WindowStyle Hidden -Wait
				}
				Start-Process "powershell.exe" -ArgumentList "komorebic.exe", "start", "--whkd" -WindowStyle Hidden
			}
		}
	}

	# YASB
	$skipYasb = ($config.misc.yasb -and $config.misc.yasb.enable -eq $false)
	if (-not $skipYasb) {
		if ($config.misc.yasb) {
			if (!(Get-Process -Name yasb -ErrorAction SilentlyContinue)) {
				if ($config.misc.yasb.enable_autostart) {
					Start-Process "powershell.exe" -ArgumentList "yasbc.exe", "enable-autostart", "--task" -WindowStyle Hidden -Wait
				}
				Start-Process "powershell.exe" -ArgumentList "yasbc.exe", "start" -WindowStyle Hidden
			}
		}
	}
} else {
	Write-Color -Text "Miscellaneous configuration is disabled in config." -Color Yellow
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
Write-Color -Text "`n`n", "For more information, please visit: ", "https://github.com/cwelsys/windows`n" -Color Gray, Blue
Write-Color -Text "😤 ", "Submit an issue via: ", "https://github.com/cwelsys/windows/issues/new" -Color White, Gray, Blue
Write-Color -Text "📨 ", "Contact me via email: ", "cwel@cwel.sh" -Color White, Gray, Cyan
