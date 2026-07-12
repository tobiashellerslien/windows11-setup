### PowerShell-profil
### Utgangspunkt: Chris Titus Tech sin profil (https://github.com/ChrisTitusTech/powershell-profile)
### Tilpasset: ingen auto-oppdatering fra hans repo, ingen separat custom-fil - alt redigeres direkte her.

function Enable-Tls12 {
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    } catch {
        Write-Verbose "Unable to enable TLS 1.2 explicitly: $_"
    }
}

Enable-Tls12

function Test-InteractiveShell {
    try {
        return $Host.Name -eq 'ConsoleHost' -and
            -not [Console]::IsInputRedirected -and
            -not [Console]::IsOutputRedirected
    } catch {
        return $false
    }
}

function Get-ProfileDir {
    switch ($PSVersionTable.PSEdition) {
        'Core' { Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell'; break }
        'Desktop' { Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'WindowsPowerShell'; break }
        default {
            throw "Unsupported PowerShell edition: $($PSVersionTable.PSEdition)"
        }
    }
}

function Test-Command {
    param([Parameter(Mandatory)][string]$Name)
    $null -ne (Get-Command -Name $Name -ErrorAction SilentlyContinue)
}

function Save-UriToFile {
    param(
        [Parameter(Mandatory)][string]$Uri,
        [Parameter(Mandatory)][string]$OutFile
    )

    $client = New-Object System.Net.WebClient
    try {
        $client.DownloadFile($Uri, $OutFile)
    } finally {
        $client.Dispose()
    }
}

function Get-UriContent {
    param([Parameter(Mandatory)][string]$Uri)

    $client = New-Object System.Net.WebClient
    try {
        $client.DownloadString($Uri)
    } finally {
        $client.Dispose()
    }
}

$isInteractiveShell = Test-InteractiveShell
$profileDir = Get-ProfileDir

function Update-PowerShell {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if (-not (Test-Command winget)) {
        Write-Warning 'winget is required to update PowerShell automatically.'
        return
    }

    try {
        $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/PowerShell/PowerShell/releases/latest' -ErrorAction Stop
        $currentVersion = [version]$PSVersionTable.PSVersion
        $latestVersion = [version]($release.tag_name -replace '^v', '')

        if ($currentVersion -ge $latestVersion) {
            Write-Host "PowerShell $currentVersion is up to date." -ForegroundColor Green
            return
        }

        if ($PSCmdlet.ShouldProcess("PowerShell $currentVersion", "Upgrade to $latestVersion")) {
            winget upgrade --id Microsoft.PowerShell --exact --accept-source-agreements --accept-package-agreements
            if ($LASTEXITCODE -ne 0) {
                Write-Error "winget failed to update PowerShell. Exit code: $LASTEXITCODE"
                return
            }
            Write-Host 'PowerShell has been updated. Restart your shell to use the new version.' -ForegroundColor Magenta
        }
    } catch {
        Write-Error "Failed to update PowerShell. Error: $_"
    }
}

function Clear-Cache {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $paths = @(
        "$env:SystemRoot\Prefetch\*",
        "$env:SystemRoot\Temp\*",
        "$env:TEMP\*",
        "$env:LOCALAPPDATA\Microsoft\Windows\INetCache\*"
    )

    foreach ($path in $paths) {
        if ($PSCmdlet.ShouldProcess($path, 'Remove cached files')) {
            Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Initialize-OptionalModule {
    if (-not $isInteractiveShell) {
        return
    }

    if (Get-Module -ListAvailable -Name Terminal-Icons) {
        Import-Module -Name Terminal-Icons -ErrorAction SilentlyContinue
    } else {
        Write-Warning 'Terminal-Icons module is not installed. Run Setup-Windows.ps1 to install dependencies.'
    }

    $chocolateyProfile = if ($env:ChocolateyInstall) {
        Join-Path $env:ChocolateyInstall 'helpers\chocolateyProfile.psm1'
    } else {
        $null
    }

    if ($chocolateyProfile -and (Test-Path -Path $chocolateyProfile -PathType Leaf)) {
        Import-Module $chocolateyProfile -ErrorAction SilentlyContinue
    }
}

function Resolve-Editor {
    foreach ($candidate in 'nvim', 'pvim', 'vim', 'vi', 'code', 'codium', 'notepad++', 'sublime_text') {
        if (Test-Command $candidate) {
            return $candidate
        }
    }

    return 'notepad'
}

Initialize-OptionalModule

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$EDITOR = Resolve-Editor
Set-Alias -Name vim -Value $EDITOR -Force

if ($isInteractiveShell) {
    try {
        $adminSuffix = if ($isAdmin) { ' [ADMIN]' } else { '' }
        $Host.UI.RawUI.WindowTitle = "PowerShell $($PSVersionTable.PSVersion)$adminSuffix"
    } catch {
        Write-Verbose "Unable to set console title: $_"
    }
}

function prompt {
    $marker = if ($isAdmin) { '#' } else { '$' }
    "[$(Get-Location)] $marker "
}

function Edit-Profile {
    & $EDITOR $PROFILE.CurrentUserAllHosts
}
Set-Alias -Name ep -Value Edit-Profile -Force

function Invoke-Profile {
    . $PROFILE.CurrentUserCurrentHost
}

function touch {
    param([Parameter(Mandatory)][string]$File)

    if (Test-Path -Path $File) {
        (Get-Item -Path $File).LastWriteTime = Get-Date
    } else {
        New-Item -Path $File -ItemType File -Force | Out-Null
    }
}

function mkcd {
    param([Parameter(Mandatory)][string]$Path)
    New-Item -Path $Path -ItemType Directory -Force | Out-Null
    Set-Location -Path $Path
}

function ff {
    param([Parameter(Mandatory)][string]$Name)
    Get-ChildItem -Recurse -Filter "*$Name*" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
}

function pubip {
    (Get-UriContent -Uri 'https://ifconfig.me/ip').Trim()
}

function winutil {
    & ([ScriptBlock]::Create((Invoke-RestMethod -Uri 'https://christitus.com/win'))) @args
}

function winutildev {
    & ([ScriptBlock]::Create((Invoke-RestMethod -Uri 'https://christitus.com/windev'))) @args
}

function admin {
    $cwd = (Get-Location).ProviderPath
    $shell = if (Test-Command pwsh) { 'pwsh.exe' } else { 'powershell.exe' }
    $shellArgs = if ($args.Count -gt 0) { @('-NoExit', '-Command', ($args -join ' ')) } else { @('-NoExit') }

    if (Test-Command wt) {
        Start-Process wt -Verb RunAs -ArgumentList (@('-d', $cwd, $shell) + $shellArgs)
    } else {
        Start-Process $shell -Verb RunAs -WorkingDirectory $cwd -ArgumentList $shellArgs
    }
}
Set-Alias -Name su -Value admin -Force

function uptime {
    $boot = if (Get-Command Get-Uptime -ErrorAction SilentlyContinue) {
        Get-Uptime -Since
    } else {
        (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
    }

    (Get-Date) - $boot | Select-Object Days, Hours, Minutes, Seconds
}

function unzip {
    param([Parameter(Mandatory)][string]$File)

    if (-not (Test-Path -Path $File -PathType Leaf)) {
        Write-Error "File not found: $File"
        return
    }

    Expand-Archive -Path $File -DestinationPath (Get-Location) -Force
}

function grep {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)][string]$Pattern,
        [Parameter(Position = 1)][string]$Path,
        [Parameter(ValueFromPipeline)][object]$InputObject
    )

    begin {
        $pipelineInput = [System.Collections.Generic.List[object]]::new()
    }

    process {
        if ($PSBoundParameters.ContainsKey('InputObject')) {
            $pipelineInput.Add($InputObject)
        }
    }

    end {
        if ($Path) {
            Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue | Select-String -Pattern $Pattern
        } elseif ($pipelineInput.Count -gt 0) {
            $pipelineInput | Select-String -Pattern $Pattern
        } else {
            Write-Error 'Usage: grep <pattern> [path] or pipe input to grep'
        }
    }
}

function df { Get-Volume }

function sed {
    param(
        [Parameter(Mandatory)][string]$File,
        [Parameter(Mandatory)][string]$Find,
        [Parameter(Mandatory)][string]$Replace
    )

    (Get-Content -Path $File).Replace($Find, $Replace) | Set-Content -Path $File
}

function which {
    param([Parameter(Mandatory)][string]$Name)
    Get-Command -Name $Name | Select-Object -ExpandProperty Definition
}

function export {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Value
    )
    Set-Item -Path "env:$Name" -Value $Value -Force
}

function pkill {
    param([Parameter(Mandatory)][string]$Name)
    Get-Process -Name $Name -ErrorAction SilentlyContinue | Stop-Process -Force
}

function pgrep {
    param([Parameter(Mandatory)][string]$Name)
    Get-Process -Name $Name -ErrorAction SilentlyContinue
}

function head {
    param([Parameter(Mandatory)][string]$Path, [int]$n = 10)
    Get-Content -Path $Path -Head $n
}

function tail {
    param([Parameter(Mandatory)][string]$Path, [int]$n = 10, [switch]$f)
    Get-Content -Path $Path -Tail $n -Wait:$f
}

function nf {
    param([Parameter(Mandatory)][string]$Name)
    New-Item -ItemType File -Path . -Name $Name -Force | Out-Null
}

function trash {
    param([Parameter(Mandatory)][string]$Path)

    $resolvedPath = Resolve-Path -LiteralPath $Path -ErrorAction SilentlyContinue
    if (-not $resolvedPath) {
        Write-Error "Item not found: $Path"
        return
    }

    $fullPath = $resolvedPath.ProviderPath
    $item = Get-Item -LiteralPath $fullPath
    $parentPath = if ($item.PSIsContainer) {
        if ($item.Parent) { $item.Parent.FullName } else { Split-Path -Path $item.FullName -Parent }
    } else {
        $item.DirectoryName
    }

    if ([string]::IsNullOrWhiteSpace($parentPath)) {
        Write-Error "Cannot move root path to Recycle Bin: $fullPath"
        return
    }

    $shell = New-Object -ComObject 'Shell.Application'
    $shellFolder = $shell.NameSpace($parentPath)
    $shellItem = if ($shellFolder) { $shellFolder.ParseName($item.Name) } else { $null }

    if ($shellItem) {
        $shellItem.InvokeVerb('delete')
    } else {
        Write-Error "Could not move item to Recycle Bin: $fullPath"
    }
}

function docs {
    Set-Location -Path ([Environment]::GetFolderPath('MyDocuments'))
}

function dtop {
    Set-Location -Path ([Environment]::GetFolderPath('Desktop'))
}

function k9 { param([Parameter(Mandatory)][string]$Name) pkill $Name }
function la { Get-ChildItem | Format-Table -AutoSize }
function ll { Get-ChildItem -Force | Format-Table -AutoSize }
function gs { git status }
function ga { git add . }
function gc { git commit -m ($args -join ' ') }
function gpush { git push @args }
function gpull { git pull @args }
function gcl { git clone @args }

function g {
    if (Get-Command __zoxide_z -ErrorAction SilentlyContinue) {
        __zoxide_z github
    } elseif (Test-Path -Path "$HOME\github") {
        Set-Location "$HOME\github"
    }
}

function gcom {
    git add .
    git commit -m ($args -join ' ')
}

function lazyg {
    git add .
    git commit -m ($args -join ' ')
    git push
}

function sysinfo { Get-ComputerInfo }

function flushdns {
    Clear-DnsClientCache
    Write-Host 'DNS has been flushed'
}

function cpy { Set-Clipboard ($args -join ' ') }
function pst { Get-Clipboard }

# python venv
function ve {
    param(
        [string]$Path = ".\.venv\Scripts\Activate.ps1"
    )
    $full = Resolve-Path -Path $Path -ErrorAction SilentlyContinue
    if (-not $full) {
        Write-Error "Virtual environment activate script not found at $Path"
        return
    }
    & $full
}

function Set-PSReadLineOptionsCompat {
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)][hashtable]$Options)

    $safeOptions = $Options.Clone()
    if ($PSVersionTable.PSEdition -ne 'Core') {
        $safeOptions.Remove('PredictionSource')
        $safeOptions.Remove('PredictionViewStyle')
    }

    if ($PSCmdlet.ShouldProcess('PSReadLine', 'Set PSReadLine options')) {
        Set-PSReadLineOption @safeOptions
    }
}

function Set-PredictionSource {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if ($PSCmdlet.ShouldProcess('PSReadLine', 'Set prediction source')) {
        if ($PSVersionTable.PSEdition -eq 'Core') {
            Set-PSReadLineOption -PredictionSource HistoryAndPlugin
        }

        Set-PSReadLineOption -MaximumHistoryCount 10000
    }
}

function Initialize-PSReadLine {
    if (-not $isInteractiveShell -or -not (Get-Module -ListAvailable -Name PSReadLine)) {
        return
    }

    $options = @{
        EditMode                    = 'Windows'
        HistoryNoDuplicates        = $true
        HistorySearchCursorMovesToEnd = $true
        PredictionSource           = 'History'
        PredictionViewStyle        = 'ListView'
        BellStyle                  = 'None'
        Colors                     = @{
            Command   = '#87CEEB'
            Parameter = '#98FB98'
            Operator  = '#FFB6C1'
            Variable  = '#DDA0DD'
            String    = '#FFDAB9'
            Number    = '#B0E0E6'
            Type      = '#F0E68C'
            Comment   = '#D3D3D3'
            Keyword   = '#8367c7'
            Error     = '#FF6347'
        }
    }

    Set-PSReadLineOptionsCompat -Options $options
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
    Set-PSReadLineKeyHandler -Chord 'Ctrl+d' -Function DeleteChar
    Set-PSReadLineKeyHandler -Chord 'Ctrl+w' -Function BackwardDeleteWord
    Set-PSReadLineKeyHandler -Chord 'Alt+d' -Function DeleteWord
    Set-PSReadLineKeyHandler -Chord 'Ctrl+LeftArrow' -Function BackwardWord
    Set-PSReadLineKeyHandler -Chord 'Ctrl+RightArrow' -Function ForwardWord
    Set-PSReadLineKeyHandler -Chord 'Ctrl+z' -Function Undo
    Set-PSReadLineKeyHandler -Chord 'Ctrl+y' -Function Redo

    Set-PSReadLineOption -AddToHistoryHandler {
        param([string]$line)
        $line -notmatch '(?i)(password|secret|token|apikey|connectionstring)'
    }

    Set-PredictionSource
}

function Register-CustomCompletion {
    if (-not $isInteractiveShell) {
        return
    }

    $completionMap = @{
        git  = @('status', 'add', 'commit', 'push', 'pull', 'clone', 'checkout')
        npm  = @('install', 'start', 'run', 'test', 'build')
        deno = @('run', 'compile', 'bundle', 'test', 'lint', 'fmt', 'cache', 'info', 'doc', 'upgrade')
    }

    Register-ArgumentCompleter -Native -CommandName git, npm, deno -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        $null = $cursorPosition
        $completionWord = $wordToComplete
        $map = $completionMap
        $command = $commandAst.CommandElements[0].Value
        if ($map.ContainsKey($command)) {
            $map[$command] |
                Where-Object { $_ -like "$completionWord*" } |
                ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
        }
    }.GetNewClosure()

    if (Test-Command dotnet) {
        Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock {
            param($wordToComplete, $commandAst, $cursorPosition)
            $null = $wordToComplete
            dotnet complete --position $cursorPosition $commandAst.ToString() |
                ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
        }
    }
}

function Resolve-OhMyPoshTheme {
    $candidates = @(
        $env:POSH_THEME,
        (Join-Path $profileDir 'hul10.omp.json'),
        (Join-Path $HOME 'hul10.omp.json')
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    foreach ($candidate in $candidates) {
        if (Test-Path -Path $candidate -PathType Leaf) {
            return $candidate
        }
    }

    return $null
}

function Initialize-PromptTool {
    if (-not $isInteractiveShell) {
        return
    }

    if (Test-Command oh-my-posh) {
        $theme = Resolve-OhMyPoshTheme
        if ($theme) {
            oh-my-posh init pwsh --config $theme | Invoke-Expression
        } else {
            Write-Warning 'Oh My Posh theme not found. Run Setup-Windows.ps1 to install hul10.omp.json.'
        }
    } else {
        Write-Warning 'oh-my-posh is not installed. Run Setup-Windows.ps1 to install dependencies.'
    }

    if (Test-Command zoxide) {
        Invoke-Expression (& { (zoxide init --cmd z powershell | Out-String) })
    } else {
        Write-Warning 'zoxide is not installed. Run Setup-Windows.ps1 to install dependencies.'
    }
}

function Invoke-Fastfetch {
    if (Test-Command fastfetch) {
        fastfetch
    } elseif ($isInteractiveShell) {
        Write-Warning 'fastfetch is not installed. Run Setup-Windows.ps1 to install dependencies.'
    }
}

function Show-Help {
    @'
PowerShell Profile Help
=======================

Profile:
  Edit-Profile      Open the current user's all-hosts profile for editing.
  Invoke-Profile    Reload this profile in the current session.
  Update-PowerShell Check for the latest PowerShell release and update with winget.

Python:
  ve [path]         Activate a Python venv (defaults to .\.venv\Scripts\Activate.ps1).

Git:
  g                 Go to the GitHub directory with zoxide fallback.
  ga                git add .
  gc <message>      git commit -m <message>
  gcl <repo>        git clone <repo>
  gcom <message>    git add .; git commit -m <message>
  gp/gpush          git push
  gpull             git pull
  gs                git status
  lazyg <message>   git add .; git commit -m <message>; git push

Shortcuts:
  cpy <text>        Copy text to the clipboard.
  df                Show volume information.
  docs/dtop         Go to Documents/Desktop.
  ff <name>         Find files recursively by name.
  flushdns          Clear the DNS cache.
  grep <regex> [p]  Search files or piped input.
  head/tail         Show the first or last lines of a file.
  k9/pkill <name>   Kill processes by name.
  la/ll             List visible/all files.
  mkcd <dir>        Create and enter a directory.
  nf/touch <file>   Create a file.
  pgrep <name>      Find processes by name.
  pst               Paste clipboard text.
  sed <f> <a> <b>   Replace text in a file.
  sysinfo           Show system information.
  unzip <file>      Extract a zip file here.
  uptime            Show system uptime.
  which <name>      Show command path.
  winutil           Run the latest WinUtil release script.
  winutildev        Run the latest WinUtil prerelease script.
'@ | Write-Host
}

Set-Alias -Name gp -Value gpush -Force

Initialize-PSReadLine
Register-CustomCompletion
Initialize-PromptTool

if ($isInteractiveShell) {
    Invoke-Fastfetch
    Write-Host "Use 'Show-Help' to display help" -ForegroundColor Yellow
}
