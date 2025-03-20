# readlines

$Colors = @{
	# Powershell colours
	ContinuationPrompt     = $Flavor.Teal.Foreground()
	Emphasis               = $Flavor.Red.Foreground()
	Selection              = $Flavor.Surface0.Background()

	# PSReadLine prediction colours
	InlinePrediction       = $Flavor.Overlay0.Foreground()
	ListPrediction         = $Flavor.Teal.Foreground()
	ListPredictionSelected = $Flavor.Surface0.Background()

	# Syntax highlighting
	Command                = $Flavor.Blue.Foreground()
	Comment                = $Flavor.Overlay0.Foreground()
	Default                = $Flavor.Text.Foreground()
	Error                  = $Flavor.Red.Foreground()
	Keyword                = $Flavor.Mauve.Foreground()
	Member                 = $Flavor.Rosewater.Foreground()
	Number                 = $Flavor.Peach.Foreground()
	Operator               = $Flavor.Sky.Foreground()
	Parameter              = $Flavor.Pink.Foreground()
	String                 = $Flavor.Green.Foreground()
	Type                   = $Flavor.Yellow.Foreground()
	Variable               = $Flavor.Lavender.Foreground()
}

$PSReadLineOptions = @{
	ExtraPromptLineCount = $true
	HistoryNoDuplicates  = $true
	MaximumHistoryCount  = 5000
	PredictionSource     = "HistoryAndPlugin"
	PredictionViewStyle  = "ListView"
	ShowToolTips         = $true
}

Set-PSReadLineOption -Colors $Colors
Set-PSReadLineOption @PSReadLineOptions
Set-PSReadlineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadlineKeyHandler -Key DownArrow -Function HistorySearchForward

# fzf

$env:FZF_DEFAULT_OPTS = @"
--color=fg:#cad3f5,fg+:#d0d0d0,bg:-1,bg+:#262626
--color=hl:#ed8796,hl+:#5fd7ff,info:#94e2d5,marker:#AAE682
--color=prompt:#94e2d5,spinner:#f4dbd6,pointer:#f4dbd6,header:#ed8796
--color=border:#585b70,label:#aeaeae,query:#d9d9d9
--layout=reverse --cycle --height=~80% --border="rounded"
--prompt=" " --marker="" --padding=1
--separator="─" --scrollbar="│"
--bind alt-w:toggle-preview-wrap
--bind ctrl-e:toggle-preview
"@

$env:_PSFZF_FZF_DEFAULT_OPTS = $env:FZF_DEFAULT_OPTS

$env:FZF_ALT_C_COMMAND = "fd --type d --hidden --follow --exclude .git --fixed-strings --strip-cwd-prefix --color always"
$env:FZF_ALT_C_OPTS = @"
--prompt='Directory  '
--preview="eza --tree --level=1 --color=always --icons=always {}"
--preview-window=right:50%:border-left
"@

$commandOverride = [ScriptBlock] { param($Location) cd $Location }
Set-PsFzfOption -AltCCommand $commandOverride

Set-PSReadlineKeyHandler -Key Tab -ScriptBlock { Invoke-FzfTabCompletion }
Set-PsFzfOption -PSReadlineChordProvider "Ctrl+t" -PSReadlineChordReverseHistory "Ctrl+r" -PSReadlineChordReverseHistoryArgs "Alt+a"
Set-PsFzfOption -GitKeyBindings -EnableAliasFuzzyGitStatus -EnableAliasFuzzyEdit -EnableAliasFuzzyKillProcess -EnableAliasFuzzyScoop -EnableFd
Set-PsFzfOption -TabExpansion
