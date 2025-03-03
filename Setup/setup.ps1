# MetaBundle Setup Script
# This script guides users through setting up the MetaBundle infrastructure and dashboard

param (
    [Parameter(Mandatory = $false)]
    [switch]$NonInteractive,
    
    [Parameter(Mandatory = $false)]
    [string]$GitHubToken,
    
    [Parameter(Mandatory = $false)]
    [string]$GitHubOrg,
    
    [Parameter(Mandatory = $false)]
    [string]$CloneRepos,
    
    [Parameter(Mandatory = $false)]
    [string]$Environment,
    
    [Parameter(Mandatory = $false)]
    [string]$TestMode
)

# Function to display colored text
function Write-ColorText {
    param (
        [Parameter(Mandatory = $false)]
        [string]$Text = "",
        
        [Parameter(Mandatory = $false)]
        [string]$ForegroundColor = "White"
    )
    
    Write-Host $Text -ForegroundColor $ForegroundColor
}

# Function to create a directory if it doesn't exist
function Ensure-Directory {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    
    if (-not (Test-Path -Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        Write-ColorText "Created directory: $Path" -ForegroundColor "Yellow"
    }
}

# Function to get user input with validation
function Get-ValidatedInput {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Prompt,
        
        [Parameter(Mandatory = $false)]
        [string]$Default = "",
        
        [Parameter(Mandatory = $true)]
        [scriptblock]$Validator,
        
        [Parameter(Mandatory = $false)]
        [string]$ErrorMessage = "Invalid input. Please try again."
    )
    
    $promptWithDefault = if ($Default) { "$Prompt (default: $Default): " } else { "$Prompt: " }
    
    do {
        $input = Read-Host -Prompt $promptWithDefault
        
        if ([string]::IsNullOrWhiteSpace($input) -and $Default) {
            $input = $Default
        }
        
        $isValid = & $Validator $input
        
        if (-not $isValid) {
            Write-Host $ErrorMessage -ForegroundColor Red
        }
    } while (-not $isValid)
    
    return $input
}

# Function to create a .env file
function Create-EnvFile {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Variables
    )
    
    $content = "# Environment variables for MetaBundle`n"
    $content += "# This file is auto-generated by the setup script`n"
    $content += "# Note: System environment variables take precedence over these values`n`n"
    
    foreach ($key in $Variables.Keys) {
        $content += "$key=$($Variables[$key])`n"
    }
    
    Set-Content -Path $Path -Value $content -Force
    Write-ColorText "Created .env file: $Path" -ForegroundColor "Green"
}

# Function to set a global environment variable
function Set-GlobalEnvironmentVariable {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Name,
        
        [Parameter(Mandatory = $true)]
        [string]$Value
    )
    
    try {
        [Environment]::SetEnvironmentVariable($Name, $Value, [EnvironmentVariableTarget]::Machine)
        Write-ColorText "Set global environment variable: $Name" -ForegroundColor "Green"
    } catch {
        Write-ColorText "Warning: Could not set machine-level environment variable $Name. Running as administrator may be required." -ForegroundColor "Yellow"
        # Still set it for the user level as fallback
        [Environment]::SetEnvironmentVariable($Name, $Value, [EnvironmentVariableTarget]::User)
        Write-ColorText "Set user-level environment variable: $Name" -ForegroundColor "Green"
    }
}

# Function to clone a GitHub repository
function Clone-Repository {
    param (
        [Parameter(Mandatory = $true)]
        [string]$RepoName,
        
        [Parameter(Mandatory = $true)]
        [string]$Organization,
        
        [Parameter(Mandatory = $true)]
        [string]$Token,
        
        [Parameter(Mandatory = $true)]
        [string]$DestinationPath
    )
    
    if (Test-Path -Path $DestinationPath) {
        Write-ColorText "Repository already exists at: $DestinationPath" -ForegroundColor "Yellow"
        return $true
    }
    
    Write-ColorText "Cloning $RepoName repository..." -ForegroundColor "Green"
    $repoUrl = "https://${Token}@github.com/${Organization}/${RepoName}.git"
    
    try {
        git clone $repoUrl $DestinationPath
        if ($LASTEXITCODE -ne 0) {
            Write-ColorText "Failed to clone repository: $RepoName" -ForegroundColor "Red"
            return $false
        }
        Write-ColorText "Successfully cloned $RepoName repository to: $DestinationPath" -ForegroundColor "Green"
        return $true
    } catch {
        Write-ColorText "Error cloning repository: $_" -ForegroundColor "Red"
        return $false
    }
}

# Clear the console and display welcome message
Clear-Host
Write-ColorText "===============================================" -ForegroundColor "Cyan"
Write-ColorText "       MetaBundle Setup Wizard" -ForegroundColor "Cyan"
Write-ColorText "===============================================" -ForegroundColor "Cyan"
Write-ColorText "This wizard will guide you through setting up the MetaBundle infrastructure and dashboard." -ForegroundColor "White"
Write-ColorText "You will need to provide some information to configure the environment." -ForegroundColor "White"
Write-ColorText ""

# Step 1: GitHub Configuration
Write-ColorText "Step 1: GitHub Configuration..." -ForegroundColor "Green"
Write-ColorText "You need a GitHub Personal Access Token with 'repo' and 'read:org' permissions." -ForegroundColor "White"
Write-ColorText "If you don't have one, create it at: https://github.com/settings/tokens" -ForegroundColor "White"

# Get GitHub token from environment variable or ask user
$defaultGithubToken = if ($env:GITHUB_TOKEN) { $env:GITHUB_TOKEN } else { "" }
if ($NonInteractive) {
    $githubToken = $GitHubToken
} else {
    $githubToken = Get-ValidatedInput -Prompt "Enter your GitHub Personal Access Token" -Default $defaultGithubToken -Validator {
        param($token)
        return $token -ne ""
    } -ErrorMessage "GitHub token cannot be empty."
}

# Get GitHub organization from environment variable or ask user
$defaultGithubOrg = if ($env:GITHUB_ORG) { $env:GITHUB_ORG } else { "MetaBundleAutomation" }
if ($NonInteractive) {
    $githubOrg = $GitHubOrg
} else {
    $githubOrg = Get-ValidatedInput -Prompt "Enter your GitHub organization name" -Default $defaultGithubOrg -Validator {
        param($org)
        return $org -ne ""
    } -ErrorMessage "GitHub organization cannot be empty."
}

Write-ColorText "GitHub Token: $('*' * [Math]::Min($githubToken.Length, 10))..." -ForegroundColor "Yellow"
Write-ColorText "GitHub Organization: $githubOrg" -ForegroundColor "Yellow"
Write-ColorText ""

# Step 2: Repository Configuration
Write-ColorText "Step 2: Repository Configuration..." -ForegroundColor "Green"

# Define default paths
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$parentPath = Split-Path -Parent $scriptPath
$defaultInfrastructurePath = Join-Path -Path $parentPath -ChildPath "Infrastructure"
$defaultDashboardPath = Join-Path -Path $parentPath -ChildPath "Dashboard"

# Ask if user wants to clone repositories
if ($NonInteractive) {
    $cloneRepos = $CloneRepos
} else {
    $cloneRepos = Get-ValidatedInput -Prompt "Do you want to clone the Infrastructure and Dashboard repositories? (yes/no)" -Default "yes" -Validator {
        param($input)
        $input = $input.ToString().ToLower().Trim()
        return $input -eq "yes" -or $input -eq "no"
    } -ErrorMessage "Please enter 'yes' or 'no'."
}

if ($cloneRepos -eq "yes") {
    # Clone Infrastructure repository
    $infrastructureSuccess = Clone-Repository -RepoName "Infrastructure" -Organization $githubOrg -Token $githubToken -DestinationPath $defaultInfrastructurePath
    
    # Clone Dashboard repository
    $dashboardSuccess = Clone-Repository -RepoName "Dashboard" -Organization $githubOrg -Token $githubToken -DestinationPath $defaultDashboardPath
    
    if (-not $infrastructureSuccess -or -not $dashboardSuccess) {
        Write-ColorText "Failed to clone one or more repositories. Please check your GitHub token and organization name." -ForegroundColor "Red"
        exit 1
    }
    
    $infrastructurePath = $defaultInfrastructurePath
    $dashboardPath = $defaultDashboardPath
} else {
    # Ask for Infrastructure path
    $infrastructurePath = Get-ValidatedInput -Prompt "Enter the path to the Infrastructure directory" -Default $defaultInfrastructurePath -Validator {
        param($path)
        if (-not (Test-Path -Path $path)) {
            return $false
        }
        return $true
    } -ErrorMessage "Directory does not exist. Please enter a valid path."
    
    # Ask for Dashboard path
    $dashboardPath = Get-ValidatedInput -Prompt "Enter the path to the Dashboard directory" -Default $defaultDashboardPath -Validator {
        param($path)
        if (-not (Test-Path -Path $path)) {
            return $false
        }
        return $true
    } -ErrorMessage "Directory does not exist. Please enter a valid path."
}

Write-ColorText "Infrastructure directory: $infrastructurePath" -ForegroundColor "Yellow"
Write-ColorText "Dashboard directory: $dashboardPath" -ForegroundColor "Yellow"
Write-ColorText ""

# Step 3: Docker Configuration
Write-ColorText "Step 3: Docker Configuration..." -ForegroundColor "Green"

# Get repository base directory from environment variable or ask user
$defaultRepoBaseDir = if ($env:REPO_BASE_DIR) { $env:REPO_BASE_DIR } else { "C:/repos/metabundle_repos" }
$repoBaseDir = Get-ValidatedInput -Prompt "Enter the repository base directory" -Default $defaultRepoBaseDir -Validator {
    param($dir)
    return $dir -ne ""
} -ErrorMessage "Repository base directory cannot be empty."

# Create the repository base directory if it doesn't exist
Ensure-Directory -Path $repoBaseDir

Write-ColorText "Repository Base Directory: $repoBaseDir" -ForegroundColor "Yellow"
Write-ColorText ""

# Step 4: API Configuration
Write-ColorText "Step 4: API Configuration..." -ForegroundColor "Green"

# Get API port from environment variable or ask user
$defaultApiPort = if ($env:API_PORT) { $env:API_PORT } else { "8080" }
$apiPort = Get-ValidatedInput -Prompt "Enter the API port" -Default $defaultApiPort -Validator {
    param($port)
    return $port -match '^\d+$' -and [int]$port -gt 0 -and [int]$port -lt 65536
} -ErrorMessage "Please enter a valid port number (1-65535)."

# Get WebSocket port from environment variable or ask user
$defaultWebsocketPort = if ($env:WEBSOCKET_PORT) { $env:WEBSOCKET_PORT } else { "8081" }
$websocketPort = Get-ValidatedInput -Prompt "Enter the WebSocket port" -Default $defaultWebsocketPort -Validator {
    param($port)
    return $port -match '^\d+$' -and [int]$port -gt 0 -and [int]$port -lt 65536
} -ErrorMessage "Please enter a valid port number (1-65535)."

Write-ColorText "API Port: $apiPort" -ForegroundColor "Yellow"
Write-ColorText "WebSocket Port: $websocketPort" -ForegroundColor "Yellow"
Write-ColorText ""

# Step 5: Environment Configuration
Write-ColorText "Step 5: Environment Configuration..." -ForegroundColor "Green"

# Get environment from environment variable or ask user
$defaultEnvironment = if ($env:ENVIRONMENT) { $env:ENVIRONMENT } else { "development" }
if ($NonInteractive) {
    $environment = $Environment
} else {
    $environment = Get-ValidatedInput -Prompt "Enter the environment (development/production)" -Default $defaultEnvironment -Validator {
        param($env)
        $env = $env.ToString().ToLower().Trim()
        return $env -eq "development" -or $env -eq "production"
    } -ErrorMessage "Please enter 'development' or 'production'."
}

# Get test mode from environment variable or ask user
$defaultTestMode = if ($env:METABUNDLE_TEST_MODE) { $env:METABUNDLE_TEST_MODE } else { "false" }
if ($NonInteractive) {
    $testMode = $TestMode
} else {
    $testMode = Get-ValidatedInput -Prompt "Run in test mode without Docker? (true/false)" -Default $defaultTestMode -Validator {
        param($mode)
        $mode = $mode.ToString().ToLower().Trim()
        return $mode -eq "true" -or $mode -eq "false"
    } -ErrorMessage "Please enter 'true' or 'false'."
}

Write-ColorText "Environment: $environment" -ForegroundColor "Yellow"
Write-ColorText "Test Mode: $testMode" -ForegroundColor "Yellow"
Write-ColorText ""

# Step 6: Set Environment Variables
Write-ColorText "Step 6: Setting Environment Variables..." -ForegroundColor "Green"

# Set environment variables for Infrastructure
Set-GlobalEnvironmentVariable -Name "GITHUB_TOKEN" -Value $githubToken
Set-GlobalEnvironmentVariable -Name "GITHUB_ORG" -Value $githubOrg
Set-GlobalEnvironmentVariable -Name "REPO_BASE_DIR" -Value $repoBaseDir
Set-GlobalEnvironmentVariable -Name "API_PORT" -Value $apiPort
Set-GlobalEnvironmentVariable -Name "WEBSOCKET_PORT" -Value $websocketPort
Set-GlobalEnvironmentVariable -Name "ENVIRONMENT" -Value $environment
Set-GlobalEnvironmentVariable -Name "METABUNDLE_TEST_MODE" -Value $testMode

# Step 7: Dashboard Configuration
Write-ColorText "Step 7: Dashboard Configuration..." -ForegroundColor "Green"

# Get Dashboard API URL from environment variable or ask user
$defaultDashboardApiUrl = if ($env:INFRASTRUCTURE_API_URL) { $env:INFRASTRUCTURE_API_URL } else { "http://localhost:$apiPort" }
$dashboardApiUrl = Get-ValidatedInput -Prompt "Enter the Dashboard API URL" -Default $defaultDashboardApiUrl -Validator {
    param($url)
    return $url -ne ""
} -ErrorMessage "Dashboard API URL cannot be empty."

# Generate a random secret key for the Dashboard
$secretKey = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 32 | ForEach-Object { [char]$_ })

# Set environment variables for Dashboard
Set-GlobalEnvironmentVariable -Name "INFRASTRUCTURE_API_URL" -Value $dashboardApiUrl
Set-GlobalEnvironmentVariable -Name "SECRET_KEY" -Value $secretKey
Set-GlobalEnvironmentVariable -Name "DEBUG_MODE" -Value ($environment -eq "development").ToString().ToLower()

Write-ColorText "Dashboard API URL: $dashboardApiUrl" -ForegroundColor "Yellow"
Write-ColorText "Secret Key: $('*' * 10)..." -ForegroundColor "Yellow"
Write-ColorText ""

# Step 8: Create .env files
Write-ColorText "Step 8: Creating .env files..." -ForegroundColor "Green"

# Create .env file for Infrastructure
$infrastructureEnvPath = Join-Path -Path $infrastructurePath -ChildPath ".env"
$infrastructureEnvVars = @{
    "GITHUB_TOKEN" = $githubToken
    "GITHUB_ORG" = $githubOrg
    "REPO_BASE_DIR" = $repoBaseDir
    "API_PORT" = $apiPort
    "WEBSOCKET_PORT" = $websocketPort
    "ENVIRONMENT" = $environment
    "METABUNDLE_TEST_MODE" = $testMode
}
Create-EnvFile -Path $infrastructureEnvPath -Variables $infrastructureEnvVars

# Create .env file for Dashboard
$dashboardEnvPath = Join-Path -Path $dashboardPath -ChildPath ".env"
$dashboardEnvVars = @{
    "INFRASTRUCTURE_API_URL" = $dashboardApiUrl
    "SECRET_KEY" = $secretKey
    "DEBUG_MODE" = ($environment -eq "development").ToString().ToLower()
}
Create-EnvFile -Path $dashboardEnvPath -Variables $dashboardEnvVars

# Step 9: Create Docker .env files
Write-ColorText "Step 9: Creating Docker .env files..." -ForegroundColor "Green"

# Create .env.docker file for Infrastructure
$infrastructureDockerEnvPath = Join-Path -Path $infrastructurePath -ChildPath ".env.docker"
Create-EnvFile -Path $infrastructureDockerEnvPath -Variables $infrastructureEnvVars

# Create .env.docker file for Dashboard
$dashboardDockerEnvPath = Join-Path -Path $dashboardPath -ChildPath ".env.docker"
Create-EnvFile -Path $dashboardDockerEnvPath -Variables $dashboardEnvVars

# Step 10: Finish
Write-ColorText "===============================================" -ForegroundColor "Cyan"
Write-ColorText "       Setup Complete!" -ForegroundColor "Cyan"
Write-ColorText "===============================================" -ForegroundColor "Cyan"
Write-ColorText "Environment variables have been set and .env files have been created." -ForegroundColor "White"
Write-ColorText ""

# Ask if user wants to start the services
$startServices = Get-ValidatedInput -Prompt "Do you want to start the services now? (yes/no)" -Default "yes" -Validator {
    param($input)
    return $input -in @("yes", "no")
} -ErrorMessage "Please enter 'yes' or 'no'."

if ($startServices -eq "yes") {
    Write-ColorText "Starting Infrastructure Backend..." -ForegroundColor "Green"
    $currentLocation = Get-Location
    Set-Location -Path $infrastructurePath
    Start-Process powershell -ArgumentList "-NoExit", "-Command", ".\start-backend.ps1 -TestMode"
    
    Write-ColorText "Starting Dashboard Frontend..." -ForegroundColor "Green"
    Set-Location -Path $dashboardPath
    Start-Process powershell -ArgumentList "-NoExit", "-Command", ".\start-dashboard.ps1"
    
    Set-Location -Path $currentLocation
} else {
    Write-ColorText "To start the services later:" -ForegroundColor "White"
    Write-ColorText "1. Infrastructure Backend: Run .\start-backend.ps1 in the Infrastructure directory" -ForegroundColor "White"
    Write-ColorText "2. Dashboard Frontend: Run .\start-dashboard.ps1 in the Dashboard directory" -ForegroundColor "White"
    Write-ColorText "3. Or use Docker: Run .\Setup\run-docker-with-env.ps1 from the root directory" -ForegroundColor "White"
}

Write-ColorText ""
Write-ColorText "Thank you for setting up MetaBundle!" -ForegroundColor "Green"
