# 👾 Encoding
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 🚌 Tls
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# 🌏 Env
$Env:DOTS = Split-Path (Get-ChildItem $PSScriptRoot | Where-Object FullName -EQ $PROFILE.CurrentUserAllHosts).Target
$Env:PWSH = Join-Path -Path "$Env:DOTS" -ChildPath "pwsh"
$Env:_ZO_DATA_DIR = "$Env:DOTS"
# $Env:STARSHIP_CONFIG = "$PSScriptRoot\config\starship.toml"

# 📝 Editor
if (Get-Command code -ErrorAction SilentlyContinue) { $Env:EDITOR = "code" }
else {
	if (Get-Command nvim -ErrorAction SilentlyContinue) { $Env:EDITOR = "nvim" }
	else { $Env:EDITOR = "notepad" }
}

# 📦 Imports
Import-Module PSFzf
Import-Module CompletionPredictor
Import-Module Catppuccin

# 🐚 Prompt
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
	oh-my-posh init pwsh --config "$Env:PWSH\posher.toml" | Invoke-Expression
	$Env:POSH_GIT_ENABLED = $true
}

# function Invoke-Starship-TransientFunction {
# 	&starship module character
# }
# Invoke-Expression (&starship init powershell)
# Enable-TransientPrompt

# 🐶 FastFetch
if (Get-Command fastfetch -ErrorAction SilentlyContinue) {
	if ([Environment]::GetCommandLineArgs().Contains("-NonInteractive")) {
		Return
	}
	fastfetch
}

# 😎 Stolye
$Flavor = $Catppuccin['Mocha']

$PSStyle.Formatting.Debug = $Flavor.Sky.Foreground()
$PSStyle.Formatting.Error = $Flavor.Red.Foreground()
$PSStyle.Formatting.ErrorAccent = $Flavor.Blue.Foreground()
$PSStyle.Formatting.FormatAccent = $Flavor.Teal.Foreground()
$PSStyle.Formatting.TableHeader = $Flavor.Rosewater.Foreground()
$PSStyle.Formatting.Verbose = $Flavor.Yellow.Foreground()
$PSStyle.Formatting.Warning = $Flavor.Peach.Foreground()

# 🛠️ Include
foreach ($module in $((Get-ChildItem -Path "$env:PWSH\module\*" -Include *.psm1).FullName )) {
	Import-Module "$module" -Global
}
foreach ($file in $((Get-ChildItem -Path "$env:PWSH\config\*" -Include *.ps1).FullName)) {
	. "$file"
}

# 🦆 yazi
function y {
	$tmp = [System.IO.Path]::GetTempFileName()
	yazi $args --cwd-file="$tmp"
	$cwd = Get-Content -Path $tmp -Encoding UTF8
	if (-not [String]::IsNullOrEmpty($cwd) -and $cwd -ne $PWD.Path) {
		Set-Location -LiteralPath ([System.IO.Path]::GetFullPath($cwd))
	}
	Remove-Item -Path $tmp
}

# 🍫 choco
# if (Get-Command choco -ErrorAction SilentlyContinue) {
# 	Import-Module $env:ChocolateyInstall\helpers\chocolateyProfile.psm1 -Global
# }

# 🥣 scoop
Invoke-Expression (&scoop-search --hook)

# git aliases
if (Get-Module -ListAvailable -Name git-aliases -ErrorAction SilentlyContinue) {
	Import-Module git-aliases -Global -DisableNameChecking
}

# 💤 zoxide
Invoke-Expression (& { (zoxide init powershell --cmd cd | Out-String) })
