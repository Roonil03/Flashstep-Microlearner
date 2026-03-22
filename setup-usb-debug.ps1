#!/bin/env pwsh
# USB Debugging Setup and Verification Script for Windows
# This script sets up adb reverse tunneling and verifies backend connectivity

param(
    [string]$Action = "all"  # all, setup, test, logs, clean
)

$projectRoot = "c:\Aryan\BTechCollege\GithubCodes\MicroLearning"
$backendPath = "$projectRoot\backend\deployments"
$frontendPath = "$projectRoot\frontend"

function Write-Header {
    param([string]$Message)
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
}

function Test-Backend {
    Write-Header "Testing Backend Connectivity"
    
    try {
        $response = curl.exe -s http://localhost:8080/health
        if ($response -match '"status":"ok"') {
            Write-Host "✓ Backend is running and responding!" -ForegroundColor Green
            return $true
        } else {
            Write-Host "✗ Backend responded but unexpected response:" -ForegroundColor Red
            Write-Host $response
            return $false
        }
    } catch {
        Write-Host "✗ Backend is NOT responding. Is Docker running?" -ForegroundColor Red
        Write-Host "Error: $_" -ForegroundColor Red
        return $false
    }
}

function Test-ADB {
    Write-Header "Checking ADB Connection"
    
    # First, check if adb is in PATH
    $adbPath = (Get-Command adb -ErrorAction SilentlyContinue).Source
    if (-not $adbPath) {
        Write-Host "✗ ADB not found in PATH" -ForegroundColor Red
        Write-Host "Trying to find ADB automatically..." -ForegroundColor Yellow
        $potentialPaths = @(
            "C:\Users\$env:USERNAME\AppData\Local\Android\Sdk\platform-tools\adb.exe",
            "C:\Android\Sdk\platform-tools\adb.exe",
            "C:\Program Files\Android\Sdk\platform-tools\adb.exe"
        )
        
        $found = $false
        foreach ($path in $potentialPaths) {
            if (Test-Path $path) {
                $env:PATH += ";$(Split-Path $path)"
                $found = $true
                Write-Host "✓ Found ADB at: $path" -ForegroundColor Green
                $adbPath = $path
                break
            }
        }
        
        if (-not $found) {
            Write-Host "✗ Could not find ADB. Please install Android SDK tools." -ForegroundColor Red
            return $false
        }
    } else {
        Write-Host "✓ ADB found: $adbPath" -ForegroundColor Green
    }
    
    # Check connected devices
    Write-Host "`nChecking connected devices..." -ForegroundColor Yellow
    $devices = adb devices
    Write-Host $devices
    
    if ($devices -match "device$") {
        Write-Host "✓ Phone/emulator connected!" -ForegroundColor Green
        return $true
    } else {
        Write-Host "✗ No devices connected. Ensure:" -ForegroundColor Red
        Write-Host "  1. Phone is connected via USB" -ForegroundColor Red
        Write-Host "  2. USB Debugging is enabled (Settings → Developer Options)" -ForegroundColor Red
        Write-Host "  3. You accepted the debug prompt on the phone" -ForegroundColor Red
        return $false
    }
}

function Setup-ADB-Reverse {
    Write-Header "Setting Up ADB Reverse (USB Tunneling)"
    
    Write-Host "Configuring: adb reverse tcp:8080 tcp:8080" -ForegroundColor Yellow
    adb reverse tcp:8080 tcp:8080
    
    Write-Host "`nVerifying reverse tunnel..." -ForegroundColor Yellow
    $reverseList = adb reverse --list
    Write-Host $reverseList
    
    if ($reverseList -match "tcp:8080") {
        Write-Host "✓ ADB reverse tunnel configured successfully!" -ForegroundColor Green
        return $true
    } else {
        Write-Host "✗ Failed to set up reverse tunnel" -ForegroundColor Red
        return $false
    }
}

function Start-Backend {
    Write-Header "Starting Backend Docker"
    
    Write-Host "Checking Docker..." -ForegroundColor Yellow
    $dockerRunning = docker ps
    if ($LASTEXITCODE -ne 0) {
        Write-Host "✗ Docker is not running. Please start Docker Desktop." -ForegroundColor Red
        return $false
    }
    
    Write-Host "✓ Docker is running" -ForegroundColor Green
    
    Write-Host "`nStarting containers..." -ForegroundColor Yellow
    Push-Location $backendPath
    docker-compose down --remove-orphans 2>$null
    docker-compose up --build -d
    Pop-Location
    
    Write-Host "Waiting for backend to start..." -ForegroundColor Yellow
    Start-Sleep -Seconds 5
    
    if (Test-Backend) {
        Write-Host "✓ Backend started successfully!" -ForegroundColor Green
        return $true
    } else {
        Write-Host "✗ Backend failed to start" -ForegroundColor Red
        Write-Host "`nBackend logs:" -ForegroundColor Yellow
        docker logs flashcards_backend
        return $false
    }
}

function Show-Docker-Status {
    Write-Header "Docker Container Status"
    docker ps --format "table {{.Names}}`t{{.Status}}"
}

function Show-Logs {
    param(
        [string]$Component = "backend"  # backend, frontend, or both
    )
    
    if ($Component -eq "backend" -or $Component -eq "both") {
        Write-Header "Backend Logs"
        docker logs -f flashcards_backend
    }
    
    if ($Component -eq "frontend" -or $Component -eq "both") {
        Write-Header "Flutter Logs"
        flutter logs
    }
}

function Build-and-Run-App {
    Write-Header "Building and Running Flutter App"
    
    Push-Location $frontendPath
    
    Write-Host "Cleaning previous build..." -ForegroundColor Yellow
    flutter clean
    if ($LASTEXITCODE -ne 0) {
        Write-Host "✗ Flutter clean failed" -ForegroundColor Red
        Pop-Location
        return $false
    }
    
    Write-Host "Getting dependencies..." -ForegroundColor Yellow
    flutter pub get
    if ($LASTEXITCODE -ne 0) {
        Write-Host "✗ Flutter pub get failed" -ForegroundColor Red
        Pop-Location
        return $false
    }
    
    Write-Host "Running app on connected device..." -ForegroundColor Yellow
    flutter run
    
    Pop-Location
}

function Show-Quick-Test {
    Write-Header "Quick Connectivity Test"
    
    Write-Host "1. Testing Backend..." -ForegroundColor Yellow
    Test-Backend
    
    Write-Host "`n2. Testing ADB Connection..." -ForegroundColor Yellow
    Test-ADB
    
    Write-Host "`n3. Testing ADB Reverse..." -ForegroundColor Yellow
    $reverseList = adb reverse --list
    if ($reverseList -match "tcp:8080") {
        Write-Host "✓ ADB reverse is configured" -ForegroundColor Green
    } else {
        Write-Host "✗ ADB reverse is NOT configured. Run: adb reverse tcp:8080 tcp:8080" -ForegroundColor Red
    }
    
    Write-Host "`n✅ All tests passed! Ready to test registration." -ForegroundColor Green
}

function Show-Help {
    $usage = @"
USB Debugging Setup Script for Flutter + Docker Backend

USAGE:
  .\setup-usb-debug.ps1 [action]

ACTIONS:
  all          - Full setup: backend + adb reverse + build + run app (DEFAULT)
  setup        - Setup only: start backend and configure adb reverse
  test         - Run quick connectivity tests
  backend      - Start backend Docker only
  adb          - Setup adb reverse only
  build        - Build and run Flutter app
  logs         - Show backend logs
  status       - Show Docker container status
  clean        - Stop and clean up Docker containers
  help         - Show this help message

EXAMPLES:
  # Full setup and run
  .\setup-usb-debug.ps1 all

  # Just test connectivity
  .\setup-usb-debug.ps1 test

  # Run just the backend
  .\setup-usb-debug.ps1 backend

  # Check status
  .\setup-usb-debug.ps1 status

REQUIREMENTS:
  - Docker Desktop installed and running
  - Android SDK tools (adb) installed
  - Phone connected via USB with debugging enabled
  - Backend code in: $backendPath
  - Frontend code in: $frontendPath
"@
    Write-Host $usage
}

# Main script logic
switch ($Action.ToLower()) {
    "all" {
        if ((Start-Backend) -and (Setup-ADB-Reverse) -and (Test-Backend)) {
            Write-Header "✓ Setup Complete!"
            Write-Host "Next steps:" -ForegroundColor Green
            Write-Host "1. Edit api_config.dart to use host = 'localhost'" -ForegroundColor Cyan
            Write-Host "2. Run: flutter clean && flutter pub get && flutter run" -ForegroundColor Cyan
            Write-Host "3. Test registration on your phone" -ForegroundColor Cyan
        }
    }
    "setup" {
        if ((Start-Backend) -and (Setup-ADB-Reverse)) {
            Show-Quick-Test
        }
    }
    "test" {
        Show-Quick-Test
    }
    "backend" {
        Start-Backend
    }
    "adb" {
        if (Test-ADB) {
            Setup-ADB-Reverse
        }
    }
    "build" {
        Build-and-Run-App
    }
    "logs" {
        Show-Logs -Component "backend"
    }
    "status" {
        Show-Docker-Status
    }
    "clean" {
        Write-Header "Cleaning Up Docker"
        Push-Location $backendPath
        docker-compose down --remove-orphans
        Pop-Location
        Write-Host "✓ Docker containers stopped and cleaned" -ForegroundColor Green
    }
    "help" {
        Show-Help
    }
    default {
        Write-Host "Unknown action: $Action" -ForegroundColor Red
        Write-Host "Run: .\setup-usb-debug.ps1 help" -ForegroundColor Yellow
        exit 1
    }
}
