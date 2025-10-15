#!/usr/bin/env powershell

<#
.SYNOPSIS
    Build and run Tailspin Space Game containers locally
.DESCRIPTION
    This script builds both the web and leaderboard Docker images and runs them locally
    with proper networking so they can communicate with each other.
.EXAMPLE
    .\run-local.ps1
    .\run-local.ps1 -Clean
#>

param(
    [switch]$Clean,
    [switch]$Stop,
    [switch]$Help
)

# Configuration
$NETWORK_NAME = "spacegame-network"
$WEB_CONTAINER = "web"
$LEADERBOARD_CONTAINER = "leaderboard"
$WEB_PORT = 8080
$LEADERBOARD_PORT = 8081

function Show-Help {
    Write-Host "Tailspin Space Game Local Runner" -ForegroundColor Green
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  .\run-local.ps1           - Build and run containers"
    Write-Host "  .\run-local.ps1 -Clean    - Clean up and rebuild everything"
    Write-Host "  .\run-local.ps1 -Stop     - Stop and remove containers"
    Write-Host "  .\run-local.ps1 -Help     - Show this help"
    Write-Host ""
    Write-Host "Access URLs:"
    Write-Host "  Web Application:  http://localhost:$WEB_PORT"
    Write-Host "  Leaderboard API:  http://localhost:$LEADERBOARD_PORT/api/Leaderboard"
}

function Stop-Containers {
    Write-Host "Stopping and removing containers..." -ForegroundColor Yellow
    
    # Stop and remove containers if they exist
    $containers = @($WEB_CONTAINER, $LEADERBOARD_CONTAINER)
    foreach ($container in $containers) {
        $exists = docker ps -a --format "{{.Names}}" | Select-String -Pattern "^$container$" -Quiet
        if ($exists) {
            Write-Host "  Removing container: $container"
            docker rm -f $container | Out-Null
        }
    }
    
    # Remove network if it exists
    $networkExists = docker network ls --format "{{.Name}}" | Select-String -Pattern "^$NETWORK_NAME$" -Quiet
    if ($networkExists) {
        Write-Host "  Removing network: $NETWORK_NAME"
        docker network rm $NETWORK_NAME | Out-Null
    }
}

function Build-Images {
    Write-Host "Building Docker images..." -ForegroundColor Green
    
    # Ensure we're in the repository root
    $repoRoot = Split-Path -Parent $PSScriptRoot
    Set-Location $repoRoot
    
    Write-Host "  Building web image..."
    $webBuild = docker build -f Tailspin.SpaceGame.Web/Dockerfile -t web:latest . 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to build web image!" -ForegroundColor Red
        Write-Host $webBuild
        exit 1
    }
    
    Write-Host "  Building leaderboard image..."
    $leaderboardBuild = docker build -f Tailspin.SpaceGame.LeaderboardContainer/Dockerfile -t leaderboard:latest . 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to build leaderboard image!" -ForegroundColor Red
        Write-Host $leaderboardBuild
        exit 1
    }
    
    Write-Host "  Images built successfully!" -ForegroundColor Green
}

function Start-Containers {
    Write-Host "Starting containers..." -ForegroundColor Green
    
    # Create network
    Write-Host "  Creating network: $NETWORK_NAME"
    docker network create $NETWORK_NAME | Out-Null
    
    # Start leaderboard container
    Write-Host "  Starting leaderboard container..."
    docker run -d `
        --name $LEADERBOARD_CONTAINER `
        --network $NETWORK_NAME `
        -p ${LEADERBOARD_PORT}:80 `
        -e ASPNETCORE_URLS=http://0.0.0.0:80 `
        leaderboard:latest | Out-Null
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to start leaderboard container!" -ForegroundColor Red
        exit 1
    }
    
    # Start web container
    Write-Host "  Starting web container..."
    docker run -d `
        --name $WEB_CONTAINER `
        --network $NETWORK_NAME `
        -p ${WEB_PORT}:80 `
        -e ASPNETCORE_URLS=http://0.0.0.0:80 `
        web:latest | Out-Null
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to start web container!" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "  Containers started successfully!" -ForegroundColor Green
}

function Test-Services {
    Write-Host "Testing services..." -ForegroundColor Green
    
    # Wait a moment for services to start
    Start-Sleep -Seconds 3
    
    # Test web application
    Write-Host "  Testing web application..."
    try {
        $webResponse = Invoke-WebRequest -Uri "http://localhost:$WEB_PORT" -UseBasicParsing -TimeoutSec 10
        if ($webResponse.StatusCode -eq 200) {
            Write-Host "    ✓ Web application is responding" -ForegroundColor Green
        } else {
            Write-Host "    ✗ Web application returned status: $($webResponse.StatusCode)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "    ✗ Web application is not responding: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Test leaderboard API
    Write-Host "  Testing leaderboard API..."
    try {
        $leaderboardResponse = Invoke-WebRequest -Uri "http://localhost:$LEADERBOARD_PORT/api/Leaderboard" -UseBasicParsing -TimeoutSec 10
        if ($leaderboardResponse.StatusCode -eq 200) {
            Write-Host "    ✓ Leaderboard API is responding" -ForegroundColor Green
        } else {
            Write-Host "    ✗ Leaderboard API returned status: $($leaderboardResponse.StatusCode)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "    ✗ Leaderboard API is not responding: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Show-Status {
    Write-Host ""
    Write-Host "Container Status:" -ForegroundColor Cyan
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" --filter "name=$WEB_CONTAINER" --filter "name=$LEADERBOARD_CONTAINER"
    
    Write-Host ""
    Write-Host "Access URLs:" -ForegroundColor Cyan
    Write-Host "  Web Application:  http://localhost:$WEB_PORT" -ForegroundColor White
    Write-Host "  Leaderboard API:  http://localhost:$LEADERBOARD_PORT/api/Leaderboard" -ForegroundColor White
    Write-Host ""
    Write-Host "Management Commands:" -ForegroundColor Cyan
    Write-Host "  Stop containers:   .\run-local.ps1 -Stop" -ForegroundColor White
    Write-Host "  View logs:         docker logs $WEB_CONTAINER" -ForegroundColor White
    Write-Host "                     docker logs $LEADERBOARD_CONTAINER" -ForegroundColor White
}

# Main execution
try {
    if ($Help) {
        Show-Help
        exit 0
    }
    
    if ($Stop) {
        Stop-Containers
        Write-Host "Containers stopped and removed." -ForegroundColor Green
        exit 0
    }
    
    Write-Host "🚀 Tailspin Space Game Local Runner" -ForegroundColor Magenta
    Write-Host "=====================================" -ForegroundColor Magenta
    
    # Clean up if requested or if containers are already running
    if ($Clean -or (docker ps --format "{{.Names}}" | Select-String -Pattern "^($WEB_CONTAINER|$LEADERBOARD_CONTAINER)$" -Quiet)) {
        Stop-Containers
    }
    
    # Build images
    Build-Images
    
    # Start containers
    Start-Containers
    
    # Test services
    Test-Services
    
    # Show status
    Show-Status
    
    Write-Host ""
    Write-Host "🎉 Setup complete! Your applications are running locally." -ForegroundColor Green
    
} catch {
    Write-Host "An error occurred: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}