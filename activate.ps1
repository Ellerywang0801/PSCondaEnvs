<#
.SYNOPSIS
Activates a Conda virtual environment.

.DESCRIPTION
Deactivates previously activated Conda environment if any, then activates the chosen one.
During activation, PS1 scripts in etc\conda\activate.d will be run as well.

Note that on Windows there may be several directories in which envs are stored.
When Anaconda is installed by Visual Studio Installer,
one location is in the Anaconda installation dir\envs (may be read-only for the current user), 
another one in $HOME\.conda\envs.
More locations can be configured in $HOME\.condarc

.PARAMETER Name 
Name of a virtual enviroment created by conda.

.NOTES
Tested with Anaconda 4.3.8

Modifies the search PATH variable.

Creates the following environment variables: 
    CONDA_DEFAULT_ENV : name of the active environment
    CONDA_PREFIX      : path to the root directory of the environment

Creates the following PS variables:
    CondaEnvPaths     : array of search paths added during activation

Creates the following functions:
    CondaUserPrompt   : saved original user prompt

.LINK
deactivate.ps1
https://github.com/BCSharp/PSCondaEnvs

.EXAMPLE
PS C:> activate.ps1 TestEnv
(TestEnv) PS C:>

This command activates a Conda environment named "TestEnv".
Any previously active Conda environment will be deactivated.

#>

Param(
    [Parameter(
        Mandatory=$true,
        HelpMessage="Name of a virtual enviroment created by conda"
    )]
    [string] $Name
)

Write-Information "Ensure that path or name passed is valid before deactivating anything"
conda "..checkenv" "cmd.exe" "$Name"
if (-not $?)
{
    Write-Host "Environment not changed." -ForegroundColor Red
    exit 
}

# Deactivate a previous activation if it is live
if (Test-Path Env:\CONDA_DEFAULT_ENV) {
    Invoke-Expression deactivate.ps1
}

Write-Host
Write-Host "Activating environment `"$Name`"..."
$newPath = (conda "..activate" "cmd.exe" "$Name")
if (-not $?)
{
    Write-Host 'Environment not activated.' -ForegroundColor Red
    exit 
}
$global:CondaEnvPaths = $newPath -split ';'
$Env:CONDA_DEFAULT_ENV = $Name

# Do we have CONDA_PATH_PLACEHOLDER in PATH?
$pathArray = $Env:PATH -split ';'
$hasPlaceholder = $pathArray -contains "CONDA_PATH_PLACEHOLDER"
# look if the deactivate script left a placeholder for us.
if ($hasPlaceholder) {
    # If it did, replace it with our newPath
    $Env:PATH = ($pathArray | foreach {$_ -replace "CONDA_PATH_PLACEHOLDER","$newPath"}) -join ';'
} else {
    # If it did not, prepend newPath
    $Env:PATH="$newPath;$Env:PATH"    
}

# always store the full path to the environment, since location of CONDA_DEFAULT_ENV varies
$Env:CONDA_PREFIX = $CondaEnvPaths[0]

Write-Host
Write-Host

# Capture existing user prompt
function global:CondaUserPrompt {''}
$Function:CondaUserPrompt = $Function:prompt

function global:prompt
{
    # Add the env name to the current user prompt.
    Write-Host "($Env:CONDA_DEFAULT_ENV) " -nonewline -ForegroundColor Green
    & $Function:CondaUserPrompt
}

# Run any activate scripts
$activate_d = "${Env:CONDA_PREFIX}\etc\conda\activate.d"
if (Test-Path $activate_d) {
    Push-Location $activate_d
    Get-ChildItem -Filter *.ps1 | select -ExpandProperty FullName | Invoke-Expression
    Pop-Location
}
