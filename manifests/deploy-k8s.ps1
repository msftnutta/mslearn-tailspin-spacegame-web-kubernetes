#!/usr/bin/env powershell

<#
.SYNOPSIS
    Deploy Tailspin Space Game to Kubernetes
.DESCRIPTION
    This script deploys the Tailspin Space Game applications to a Kubernetes cluster
.EXAMPLE
    .\deploy-k8s.ps1
    .\deploy-k8s.ps1 -Remove
    .\deploy-k8s.ps1 -Status
#>

param(
    [switch]$Remove,
    [switch]$Status,
    [switch]$Help,
    [string]$Namespace = "default"
)

function Show-Help {
    Write-Host "Tailspin Space Game Kubernetes Deployment" -ForegroundColor Green
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  .\deploy-k8s.ps1                    - Deploy to Kubernetes"
    Write-Host "  .\deploy-k8s.ps1 -Remove            - Remove deployment from Kubernetes"
    Write-Host "  .\deploy-k8s.ps1 -Status            - Show deployment status"
    Write-Host "  .\deploy-k8s.ps1 -Namespace test    - Deploy to specific namespace"
    Write-Host "  .\deploy-k8s.ps1 -Help              - Show this help"
    Write-Host ""
    Write-Host "Prerequisites:"
    Write-Host "  - kubectl configured and connected to your cluster"
    Write-Host "  - Container images pushed to your registry (azurecr9001.azurecr.io)"
    Write-Host "  - Kubernetes cluster with appropriate permissions"
}

function Test-Prerequisites {
    Write-Host "Checking prerequisites..." -ForegroundColor Yellow
    
    # Check kubectl
    try {
        $kubectlVersion = kubectl version --client --short 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✓ kubectl is available" -ForegroundColor Green
        } else {
            Write-Host "  ✗ kubectl is not available or not configured" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "  ✗ kubectl is not available" -ForegroundColor Red
        return $false
    }
    
    # Check cluster connection
    try {
        $clusterInfo = kubectl cluster-info 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✓ Connected to Kubernetes cluster" -ForegroundColor Green
        } else {
            Write-Host "  ✗ Not connected to Kubernetes cluster" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "  ✗ Cannot connect to Kubernetes cluster" -ForegroundColor Red
        return $false
    }
    
    # Check namespace
    try {
        $namespaces = kubectl get namespaces --no-headers -o custom-columns=":metadata.name" 2>$null
        if ($namespaces -contains $Namespace) {
            Write-Host "  ✓ Namespace '$Namespace' exists" -ForegroundColor Green
        } else {
            Write-Host "  ! Namespace '$Namespace' does not exist, will be created" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  ! Cannot check namespaces" -ForegroundColor Yellow
    }
    
    return $true
}

function Deploy-Applications {
    Write-Host "Deploying applications to Kubernetes..." -ForegroundColor Green
    
    # Ensure we're in the manifests directory
    $manifestsPath = Join-Path $PSScriptRoot ""
    Set-Location $manifestsPath
    
    # Create namespace if it doesn't exist
    if ($Namespace -ne "default") {
        Write-Host "  Creating namespace: $Namespace"
        kubectl create namespace $Namespace --dry-run=client -o yaml | kubectl apply -f - | Out-Null
    }
    
    # Apply deployments
    Write-Host "  Applying deployments..."
    $deployResult = kubectl apply -f deployment.yml -n $Namespace 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to apply deployments!" -ForegroundColor Red
        Write-Host $deployResult
        return $false
    }
    
    # Apply services
    Write-Host "  Applying services..."
    $serviceResult = kubectl apply -f service.yml -n $Namespace 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to apply services!" -ForegroundColor Red
        Write-Host $serviceResult
        return $false
    }
    
    Write-Host "  Applications deployed successfully!" -ForegroundColor Green
    return $true
}

function Remove-Applications {
    Write-Host "Removing applications from Kubernetes..." -ForegroundColor Yellow
    
    # Ensure we're in the manifests directory
    $manifestsPath = Join-Path $PSScriptRoot ""
    Set-Location $manifestsPath
    
    # Remove services first
    Write-Host "  Removing services..."
    kubectl delete -f service.yml -n $Namespace --ignore-not-found=true | Out-Null
    
    # Remove deployments
    Write-Host "  Removing deployments..."
    kubectl delete -f deployment.yml -n $Namespace --ignore-not-found=true | Out-Null
    
    Write-Host "  Applications removed successfully!" -ForegroundColor Green
}

function Show-Status {
    Write-Host "Kubernetes Deployment Status" -ForegroundColor Cyan
    Write-Host "============================" -ForegroundColor Cyan
    
    Write-Host ""
    Write-Host "Deployments:" -ForegroundColor Yellow
    kubectl get deployments -n $Namespace -o wide 2>$null
    
    Write-Host ""
    Write-Host "Pods:" -ForegroundColor Yellow
    kubectl get pods -n $Namespace -o wide 2>$null
    
    Write-Host ""
    Write-Host "Services:" -ForegroundColor Yellow
    kubectl get services -n $Namespace -o wide 2>$null
    
    Write-Host ""
    Write-Host "Service URLs:" -ForegroundColor Cyan
    
    # Get service information
    $services = kubectl get services -n $Namespace -o json 2>$null | ConvertFrom-Json
    if ($services -and $services.items) {
        foreach ($service in $services.items) {
            $serviceName = $service.metadata.name
            $serviceType = $service.spec.type
            
            if ($serviceType -eq "LoadBalancer") {
                $loadBalancer = $service.status.loadBalancer
                if ($loadBalancer.ingress -and $loadBalancer.ingress.Count -gt 0) {
                    $externalIP = $loadBalancer.ingress[0].ip
                    if (-not $externalIP) {
                        $externalIP = $loadBalancer.ingress[0].hostname
                    }
                    if ($externalIP) {
                        $port = $service.spec.ports[0].port
                        if ($serviceName -eq "web") {
                            Write-Host "  Web Application:  http://$externalIP:$port" -ForegroundColor White
                        } elseif ($serviceName -eq "leaderboard") {
                            Write-Host "  Leaderboard API:  http://$externalIP:$port/api/Leaderboard" -ForegroundColor White
                        }
                    } else {
                        Write-Host "  $serviceName : LoadBalancer IP pending..." -ForegroundColor Yellow
                    }
                } else {
                    Write-Host "  $serviceName : LoadBalancer IP pending..." -ForegroundColor Yellow
                }
            }
        }
    }
    
    Write-Host ""
    Write-Host "Useful Commands:" -ForegroundColor Cyan
    Write-Host "  View logs:           kubectl logs -f deployment/web -n $Namespace" -ForegroundColor White
    Write-Host "                       kubectl logs -f deployment/leaderboard -n $Namespace" -ForegroundColor White
    Write-Host "  Describe pods:       kubectl describe pods -n $Namespace" -ForegroundColor White
    Write-Host "  Port forward:        kubectl port-forward service/web 8080:80 -n $Namespace" -ForegroundColor White
    Write-Host "  Scale deployment:    kubectl scale deployment web --replicas=3 -n $Namespace" -ForegroundColor White
}

function Wait-ForDeployment {
    Write-Host "Waiting for deployments to be ready..." -ForegroundColor Yellow
    
    $deployments = @("web", "leaderboard")
    foreach ($deployment in $deployments) {
        Write-Host "  Waiting for $deployment..."
        $waitResult = kubectl wait --for=condition=available deployment/$deployment -n $Namespace --timeout=300s 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    ✓ $deployment is ready" -ForegroundColor Green
        } else {
            Write-Host "    ⚠ $deployment may not be ready: $waitResult" -ForegroundColor Yellow
        }
    }
}

# Main execution
try {
    if ($Help) {
        Show-Help
        exit 0
    }
    
    if ($Status) {
        Show-Status
        exit 0
    }
    
    if ($Remove) {
        if (-not (Test-Prerequisites)) {
            exit 1
        }
        Remove-Applications
        exit 0
    }
    
    Write-Host "🚀 Tailspin Space Game Kubernetes Deployment" -ForegroundColor Magenta
    Write-Host "=============================================" -ForegroundColor Magenta
    
    # Check prerequisites
    if (-not (Test-Prerequisites)) {
        Write-Host ""
        Write-Host "Prerequisites not met. Please ensure:" -ForegroundColor Red
        Write-Host "  1. kubectl is installed and configured" -ForegroundColor Red
        Write-Host "  2. You are connected to a Kubernetes cluster" -ForegroundColor Red
        Write-Host "  3. Container images are available in the registry" -ForegroundColor Red
        exit 1
    }
    
    # Deploy applications
    if (-not (Deploy-Applications)) {
        exit 1
    }
    
    # Wait for deployments
    Wait-ForDeployment
    
    # Show status
    Write-Host ""
    Show-Status
    
    Write-Host ""
    Write-Host "🎉 Deployment complete!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Note: If using LoadBalancer services, it may take a few minutes" -ForegroundColor Yellow
    Write-Host "for external IPs to be assigned by your cloud provider." -ForegroundColor Yellow
    
} catch {
    Write-Host "An error occurred: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}