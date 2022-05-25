. ([String]::Concat(($profile | Split-Path | Split-Path), "\private.ps1"))

function DevShell() {
    $installPath = . 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe' -latest -Property installationPath

    Import-Module (Join-Path $installPath "Common7\Tools\Microsoft.VisualStudio.DevShell.dll")
    $null = Enter-VsDevShell -VsInstallPath $installPath -SkipAutomaticLocation
}

# Finds files that are not in excluded files or folders
function GetFiles {
    param([Parameter(ValueFromPipeline = $true)][Object[]]$files) 

    process {
        if (-not $PSBoundParameters.ContainsKey('files')) {
            $files = (*.*)
        }
        return (Get-ChildItem $files -Exclude *.dbmdl, *.pubxml, *.Designer.cs, *.map, *.exe, *.dll, *.crx, *.jpg, *.mp3, *.ogg, *.opus, *.png, *.dacpac, Xrm.cs, OptionSets.cs -Recurse | Where-Object FullName -NotMatch "obj|bin|.git|.vs|.vscode|bower_components|node_modules|sqlite3|vendor|PublishPProfiles|HelpPage")
    }
}

function FileVersions($file) { (GetFiles $file).VersionInfo }

# Finds all instances of given text in non-excluded files, returns relative paths
function FindRelative {
    param([string]$text, [Parameter(ValueFromPipeline = $true)][Object[]]$files) 
    process {
        $dir = Get-Location
        GetFiles $files | Select-String -Pattern $text | ForEach-Object { [String]::Concat( [System.IO.Path]::GetRelativePath($dir, $_.Path), ":", $_.LineNumber) }
    }
}

# Finds all instances of given text in non-excluded files, returns absolute paths
function FindAbsolute {
    param([string]$text, [Parameter(ValueFromPipeline = $true)][Object[]]$files) 
    process {
        GetFiles $files | Select-String -Pattern $text -List | ForEach-Object { [String]::Concat($_.Path, ":", $_.LineNumber) }
    }
}

# Finds Windows Scheduler Tasks by its Actions
function TasksByActions($text) { Get-ScheduledTask | Where-Object { $_.Actions.Arguments -Like ("*" + $text + "*") } }

# Finds Windows Scheduler Tasks by its Action Arguments
function TasksByArguments($text) { Get-ScheduledTask | Where-Object { $_.Actions -Like ("*" + $text + "*") } }

# Zips up current directory and puts it in the parent directory
function ZipDir () {
    $path = (Get-Location).Path
    Set-Location ..
    Add-Type -Assembly "system.io.compression.filesystem"
    [IO.Compression.ZipFile]::CreateFromDirectory($path, $path + ".zip")
}

function ClearNuget() { dotnet nuget locals all --clear }
function GitIgnore { process { dotnet new gitignore } }

# Creates a git repo in current directory if needed, then pushes it to GitHub
function GitNew ($IsPublic = $false) {

    try {
        $repo = (get-item .).Name
        $localRepoExists = $false;
        
        if (-not (Test-Path ".gitignore")) {
            GitIgnore 
        }

        if (-not (Test-Path -Path ".git")) {
            git init
            & git add -A
            & git commit -m "Initial Commit"
        }
        else {
            $localRepoExists = $true
        }
   
        if ($IsPublic -eq $true) {
            gh repo create "$repo" --public --source "." --push
        }
        else {
            gh repo create "$repo" --private --source "." --push
        }
    }
    catch {
        if ($localRepoExists -eq $false) {
            Write-Output "Found an issue deleting the created git directory"
            GitDelete
        }
    }
}

function GitList { gh repo list --json name | ConvertFrom-Json | ForEach-Object { $_.name } } # List all GitHub repos
function GitDelete { rmfr .git }

# Does git fetch in all the subdirectories in parallel
function GitFetchAll() {
    $script = {
        param($dir)
        Set-Location $dir
        Write-Output $dir
        git fetch origin
        Set-Location ..
    }

    $dirs = Get-ChildItem -Directory
    
    foreach ($dir in $dirs) {
        Start-Job $script -ArgumentList $dir
    }
}

# Does git status in all the subdirectories
function GitStatusAll() {
    $dirs = Get-ChildItem -Directory

    foreach ($dir in $dirs) {
        Set-Location $dir
        Write-Output $dir.Name
        git status
        Set-Location ..
    }
}
function GitTemplate($template) { gh repo create --clone --template "$template" } # Create a repo based on a GitHub repo
function GitGet ($repo) { gh repo clone "$repo" } # Clones given repo from GitHub
function GitGetAll() { GitList | ForEach-Object { GitGet $_ } } # Clones all your GitHub repos 
function GitCheck() { GitList | ForEach-Object { Write-Output "${_}: $(Test-Path $_)" } } # Checks if GitHub repos exist
function GitMissing() { GitCheck | Select-String "False" } # Displays which GitHub repos are missing

# Shortcuts
function c([Parameter(ValueFromPipeline = $true)][string] $file) { code -g $file } # Makes VS Code Pipelined for file or file:line input
function b([Parameter(ValueFromPipeline = $true)][string] $text) { process { $x = $text -Split ':'; bat $x[0] -r $x[1] } } # pipeline bat for file:line input
function ch() { code . } # Open VS Code Here
function p() { code $profile } # Edit PowerShell Profile in VS Code
function pd() { $profile | Split-Path } # PowerShell Profile Directory
function pcd() { pd | Set-Location } # Change Directory to PowerShell Profile Directory
function pe() { pd | e } # Opens PowerShell Profile in Windows Explorer
function pr() { . $profile } # Reload PowerShell Profile
function lt { wsl exa --icons --tree -L2 --group-directories-first } # List file directory tree with exa
function lsf { wsl exa --icons --group-directories-first } # List file directory with exa
function rmfr($dir) { Remove-Item $dir -Force -Recurse } # Removes directories without prompts

# Find text in files and display them with bat
function frab { 
    param([string]$text, [Parameter(ValueFromPipeline = $true)][Object[]]$files) 
    process { 
        FindRelative -text $text -files $files | ForEach-Object { $x = $_ -Split ':'; bat $x[0] -r $x[1] }
    } 
}
# Find text in files and display them with VS Code
function frac { 
    param([string]$text, [Parameter(ValueFromPipeline = $true)][Object[]]$files)
    process { 
        FindRelative -text $text -files $files | ForEach-Object { c($_) } 
    } 
}

# Give pipeline ability to Windows Explorer
function explorer { 
    param([Parameter(ValueFromPipeline = $true)][string]$dir = '.') 
    process { 
        explorer.exe $dir 
    } 
}

Set-Alias -Name "~" -Value $HOME
Set-Alias -Name "e" -Value "explorer"
Set-Alias -Name "f" -Value "FindRelative"
Set-Alias -Name "fab" -Value "FindAbsolute"
Set-Alias -Name "touch" -Value "New-Item"
Set-Alias -Name "py" -Value "python"
function ProfileVersion() { Write-Output "v1.8" }
