# 👾 UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 🚌 Tls12
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12


# 🔗 Aliases
Set-Alias -Name cat -Value bat
Set-Alias -Name df -Value Get-Volume
Set-Alias -Name vi -Value nvim
Set-Alias -Name vim -Value nvim
Set-Alias -Name c -Value clear
Set-Alias -Name lg -Value lazygit
Set-Alias -Name r -Value reload

# 🌏 Env
$Env:DOTS = Split-Path (Get-ChildItem $PSScriptRoot | Where-Object FullName -EQ $PROFILE.CurrentUserAllHosts).Target
$Env:PWSH = Join-Path -Path "$Env:DOTS" -ChildPath "pwsh"
$Env:STARSHIP_CONFIG = "$ENV:DOTS\config\starship\starship.toml"
$Env:_ZO_DATA_DIR = $Env:DOTS

# 📝 Editor
if (Get-Command code -ErrorAction SilentlyContinue) { $Env:EDITOR = "code" }
else {
	if (Get-Command nvim -ErrorAction SilentlyContinue) { $Env:EDITOR = "nvim" }
	elseif (Get-Command vim -ErrorAction SilentlyContinue) { $Env:EDITOR = "vim" }
	else { $Env:EDITOR = "notepad" }
}

# 🐳 Modules
# Import-Module -Name Terminal-Icons
# Import-Module PSFzf

# 🐶 FastFetch
if (Get-Command fastfetch -ErrorAction SilentlyContinue) {
	if ([Environment]::GetCommandLineArgs().Contains("-NonInteractive")) {
		Return
	}
	fastfetch
}

# 🐚 Prompt
function Invoke-Starship-TransientFunction {
	&starship module character
}
Invoke-Expression (&starship init powershell)
Enable-TransientPrompt
Invoke-Expression (& { ( zoxide init powershell --cmd cd | Out-String ) })

# 🛠️ Include
foreach ($module in $((Get-ChildItem -Path "$env:PWSH\module\*" -Include *.psm1).FullName )) {
	Import-Module "$module" -Global
}
foreach ($file in $((Get-ChildItem -Path "$env:PWSH\config\*" -Include *.ps1).FullName)) {
	. "$file"
}


