# Local Development Scripts

This folder contains scripts to build and run the Tailspin Space Game containers locally for development and testing, as well as deploy them to Kubernetes.

## Scripts

### Local Development

#### PowerShell Script (Windows)
```powershell
# Run the application locally
.\run-local.ps1

# Clean rebuild
.\run-local.ps1 -Clean

# Stop containers
.\run-local.ps1 -Stop

# Show help
.\run-local.ps1 -Help
```

#### Bash Script (Linux/macOS/WSL)
```bash
# Run the application locally
./run-local.sh

# Clean rebuild
./run-local.sh clean

# Stop containers
./run-local.sh stop

# Show help
./run-local.sh help
```

### Kubernetes Deployment

#### PowerShell Script
```powershell
# Deploy to Kubernetes
.\deploy-k8s.ps1

# Check deployment status
.\deploy-k8s.ps1 -Status

# Remove from Kubernetes
.\deploy-k8s.ps1 -Remove

# Deploy to specific namespace
.\deploy-k8s.ps1 -Namespace production

# Show help
.\deploy-k8s.ps1 -Help
```

## Local Development

### What the local scripts do

1. **🔨 Build Docker Images**: Builds both `web:latest` and `leaderboard:latest` images
2. **🌐 Create Network**: Creates a Docker network called `spacegame-network` for container communication
3. **🚀 Start Containers**: 
   - `leaderboard` container on port 8081
   - `web` container on port 8080
4. **✅ Test Services**: Verifies both services are responding correctly
5. **📊 Display Status**: Displays running containers and access URLs

### Local Access URLs

- **Web Application**: http://localhost:8080
- **Leaderboard API**: http://localhost:8081/api/Leaderboard

### Container Communication

The containers are connected via a custom Docker network (`spacegame-network`) which allows the web application to communicate with the leaderboard service using the hostname `leaderboard` as configured in `appsettings.json`.

## Kubernetes Deployment

### Prerequisites

- kubectl installed and configured
- Connected to a Kubernetes cluster
- Container images pushed to `azurecr9001.azurecr.io` registry
- Appropriate permissions in the cluster

### Kubernetes Manifests

#### `deployment.yml`
- Defines Kubernetes Deployments for both applications
- Includes resource limits, health checks, and environment variables
- Configures proper container ports and labels

#### `service.yml`
- Defines Kubernetes Services to expose the applications
- Uses LoadBalancer type for external access
- Maps external ports to container ports

### Key Features of Kubernetes Deployment

1. **Resource Management**: CPU and memory limits/requests
2. **Health Checks**: Liveness and readiness probes
3. **Environment Configuration**: Proper ASP.NET Core settings
4. **Service Discovery**: Services can communicate using DNS names
5. **Load Balancing**: External LoadBalancer services for public access

### Deployment Updates Made

The `deployment.yml` has been enhanced with:

- **Environment Variables**: `ASPNETCORE_URLS` and `ASPNETCORE_ENVIRONMENT`
- **Resource Limits**: Memory (256Mi-512Mi) and CPU (250m-500m) constraints
- **Health Probes**: 
  - Web app: HTTP GET on `/`
  - Leaderboard: HTTP GET on `/api/Leaderboard`
- **Better Labels**: Component labels for organization
- **Proper Configuration**: Ensures apps bind to all interfaces

## Management Commands

### Local Development
```bash
# View container logs
docker logs web
docker logs leaderboard

# Stop and remove containers manually
docker rm -f web leaderboard
docker network rm spacegame-network

# List running containers
docker ps

# View images
docker images
```

### Kubernetes
```bash
# View deployment status
kubectl get deployments
kubectl get pods
kubectl get services

# View logs
kubectl logs -f deployment/web
kubectl logs -f deployment/leaderboard

# Port forward for testing
kubectl port-forward service/web 8080:80
kubectl port-forward service/leaderboard 8081:80

# Scale applications
kubectl scale deployment web --replicas=3
kubectl scale deployment leaderboard --replicas=2

# Describe resources for troubleshooting
kubectl describe deployment web
kubectl describe pod <pod-name>
kubectl describe service web
```

## Troubleshooting

### Local Development
If you encounter issues:

1. **Port conflicts**: Make sure ports 8080 and 8081 are not in use
2. **Container name conflicts**: Run `.\run-local.ps1 -Stop` to clean up
3. **Build failures**: Check that you're in the repository root directory
4. **Network issues**: The script automatically creates and manages the Docker network

### Kubernetes Deployment
Common issues and solutions:

1. **Image Pull Errors**: Ensure images are pushed to the registry and accessible
2. **Service Pending**: LoadBalancer IP assignment depends on cloud provider
3. **Pod Crashes**: Check logs with `kubectl logs <pod-name>`
4. **Health Check Failures**: Verify application starts correctly and endpoints respond
5. **Namespace Issues**: Ensure you have permissions in the target namespace

## Prerequisites

- Docker Desktop installed and running
- PowerShell (Windows) or Bash (Linux/macOS/WSL)
- .NET 8.0 SDK (for building the applications)
- kubectl (for Kubernetes deployment)
- Access to Kubernetes cluster
- Container registry access (for Kubernetes deployment)