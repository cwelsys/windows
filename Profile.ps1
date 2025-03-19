# 👾 UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 🚌 Tls12
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# 📦 Modules
Import-Module -Name Microsoft.WinGet.CommandNotFound
Import-Module scoop-completion -Global
Import-Module posh-git -Global
Import-Module Terminal-Icons -Global
Import-Module -Name CompletionPredictor
# Import-Module PsFzf

# 🌏 Env
$Env:DOTS = Split-Path (Get-ChildItem $PSScriptRoot | Where-Object FullName -EQ $PROFILE.CurrentUserAllHosts).Target
$Env:PWSH = Join-Path -Path "$Env:DOTS" -ChildPath "pwsh"
$Env:STARSHIP_CONFIG = "$ENV:PWSH\starship.toml"
$Env:_ZO_DATA_DIR = $Env:DOTS

# 📝 Editor
if (Get-Command code -ErrorAction SilentlyContinue) { $Env:EDITOR = "code" }
else {
	if (Get-Command nvim -ErrorAction SilentlyContinue) { $Env:EDITOR = "nvim" }
	elseif (Get-Command vim -ErrorAction SilentlyContinue) { $Env:EDITOR = "vim" }
	else { $Env:EDITOR = "notepad" }
}

# 🐶 FastFetch
if (Get-Command fastfetch -ErrorAction SilentlyContinue) {
	if ([Environment]::GetCommandLineArgs().Contains("-NonInteractive")) {
		Return
	}
	fastfetch
}

# 🐚 Prompt
# function Invoke-Starship-TransientFunction {
# 	&starship module character
# }
# Invoke-Expression (&starship init powershell)
# Enable-TransientPrompt
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
	oh-my-posh init pwsh --config "$Env:PWSH\posh.toml" | Invoke-Expression
	$Env:POSH_GIT_ENABLED = $true
}
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
# 🍫 Choco
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
	Import-Module "$ChocolateyProfile"
}
# 🥣 Scoop
Invoke-Expression (&scoop-search --hook)

# 💤 zoxide
Invoke-Expression (& { ( zoxide init powershell --cmd cd | Out-String ) })
