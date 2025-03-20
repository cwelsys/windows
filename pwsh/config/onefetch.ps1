# git repository greeter
$global:lastRepository = $null

function Check-DirectoryForNewRepository {
  $currentRepository = git rev-parse --show-toplevel 2>$null
  if ($currentRepository -and ($currentRepository -ne $global:lastRepository)) {
    onefetch | Write-Host
  }
  $global:lastRepository = $currentRepository
}

function Set-Location {
  Microsoft.PowerShell.Management\Set-Location @args
  Check-DirectoryForNewRepository
}

# Optional: Check the repository also when opening a shell directly in a repository directory
# Uncomment the following line if desired
#Check-DirectoryForNewRepository
