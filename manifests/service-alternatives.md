# Alternative Service Configurations

This directory contains alternative service configurations for different deployment scenarios.

## service.yml (Current - LoadBalancer)
- **Type**: LoadBalancer
- **Use Case**: Cloud environments (AKS, EKS, GKE) with external load balancer support
- **Access**: External IP provided by cloud provider
- **Cost**: May incur cloud provider load balancer costs

## Alternative Configurations

### 1. NodePort Services (service-nodeport.yml)
```yaml
apiVersion: v1
kind: Service
metadata:
    name: leaderboard
    labels:
      app: leaderboard
      component: api
spec:
    type: NodePort
    ports:
    - name: http
      port: 80
      targetPort: 80
      nodePort: 30081
      protocol: TCP
    selector:
        app: leaderboard
---
apiVersion: v1
kind: Service
metadata:
    name: web
    labels:
      app: web
      component: frontend
spec:
    type: NodePort
    ports:
    - name: http
      port: 80
      targetPort: 80
      nodePort: 30080
      protocol: TCP
    selector:
        app: web
```

**Use Case**: On-premises clusters, local development clusters
**Access**: `http://<node-ip>:30080` for web, `http://<node-ip>:30081` for leaderboard

### 2. ClusterIP with Ingress (service-ingress.yml)
```yaml
apiVersion: v1
kind: Service
metadata:
    name: leaderboard
    labels:
      app: leaderboard
      component: api
spec:
    type: ClusterIP
    ports:
    - name: http
      port: 80
      targetPort: 80
      protocol: TCP
    selector:
        app: leaderboard
---
apiVersion: v1
kind: Service
metadata:
    name: web
    labels:
      app: web
      component: frontend
spec:
    type: ClusterIP
    ports:
    - name: http
      port: 80
      targetPort: 80
      protocol: TCP
    selector:
        app: web
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tailspin-ingress
  labels:
    app: tailspin
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    # For Azure Application Gateway:
    # kubernetes.io/ingress.class: azure/application-gateway
    # For AWS ALB:
    # kubernetes.io/ingress.class: alb
    # alb.ingress.kubernetes.io/scheme: internet-facing
spec:
  rules:
  - host: tailspin.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web
            port:
              number: 80
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: leaderboard
            port:
              number: 80
```

**Use Case**: Production environments with ingress controller, SSL termination, domain routing
**Access**: `https://tailspin.example.com` for web, `https://tailspin.example.com/api` for leaderboard

## Deployment Recommendations

### Local/Development
- Use **NodePort** services for simplicity
- No external dependencies required

### Cloud Production
- Use **LoadBalancer** services (current setup) for simple external access
- Use **ClusterIP + Ingress** for advanced routing, SSL, multiple domains

### On-Premises Production
- Use **NodePort** with external load balancer/proxy
- Use **ClusterIP + Ingress** with ingress controller

## Cloud-Specific Annotations

### Azure AKS
```yaml
annotations:
  service.beta.kubernetes.io/azure-load-balancer-internal: "false"
  service.beta.kubernetes.io/azure-dns-label-name: "tailspin-web"
  service.beta.kubernetes.io/azure-load-balancer-resource-group: "myResourceGroup"
```

### AWS EKS
```yaml
annotations:
  service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
  service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
  service.beta.kubernetes.io/aws-load-balancer-backend-protocol: "http"
```

### Google GKE
```yaml
annotations:
  cloud.google.com/load-balancer-type: "External"
  cloud.google.com/backend-config: '{"default": "my-backend-config"}'
```