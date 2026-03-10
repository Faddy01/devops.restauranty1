# 🍽️ Restauranty — DevOps Pipeline

A full-stack restaurant management platform with microservices architecture, containerised and deployed on Azure Kubernetes Service (AKS).

## Architecture

```
Internet
   │
   ▼  HTTPS (443)
┌──────────────────────┐
│  NGINX Ingress / AKS │
└──────────┬───────────┘
           │
  ┌────────┼────────────────────┐
  │        │                    │
/api/auth  /api/items  /api/discounts
  │        │                    │
Auth:3001  Items:3003  Discounts:3002
  └────────┴────────────────────┘
           │
     MongoDB (Atlas or in-cluster)
```

| Service | Port | Description |
|---|---|---|
| **auth** | 3001 | JWT authentication & user management |
| **discounts** | 3002 | Campaigns & coupon management |
| **items** | 3003 | Menu items, dietary info & orders |
| **frontend** | 3000 | React SPA (served by nginx) |

---

## 📋 Prerequisites

| Tool | Version | Install |
|---|---|---|
| Docker | ≥ 24 | https://docs.docker.com/get-docker/ |
| docker compose | ≥ 2.20 | (bundled with Docker Desktop) |
| kubectl | ≥ 1.28 | https://kubernetes.io/docs/tasks/tools/ |
| Azure CLI | ≥ 2.57 | https://learn.microsoft.com/cli/azure/install-azure-cli |
| Terraform | ≥ 1.6 | https://developer.hashicorp.com/terraform/install |
| Node.js | 20 LTS | https://nodejs.org |

---

## 🚀 Local Development (Docker Compose)

### 1. Clone the repository

```bash
git clone https://github.com/YOUR_ORG/devops.restauranty.git
cd devops.restauranty
```

### 2. Create environment files

```bash
# Create .env for each microservice
for svc in backend/auth backend/discounts backend/items; do
  cp $svc/.env.example $svc/.env
done
# Edit each .env file with real values:
#   SECRET, MONGODB_URI, CLOUD_NAME, CLOUD_API_KEY, CLOUD_API_SECRET
```

### 3. Start the full stack

```bash
docker compose up --build
```

| URL | Service |
|---|---|
| http://localhost | React frontend (via HAProxy) |
| http://localhost:8404 | HAProxy stats dashboard |
| http://localhost:3001 | Auth service (direct) |
| http://localhost:3002 | Discounts service (direct) |
| http://localhost:3003 | Items service (direct) |
| http://localhost:27017 | MongoDB |

### 4. Stop and clean up

```bash
docker compose down -v   # -v removes volumes (mongo data)
```

---

## 🏗️ Manual Local Setup (without Docker)

```bash
# Terminal 1 — MongoDB
docker run -d --name my-mongo -p 27017:27017 -v mongo-data:/data/db mongo:latest

# Terminal 2 — Auth
cd backend/auth && npm install && npm start

# Terminal 3 — Discounts
cd backend/discounts && npm install && npm start

# Terminal 4 — Items
cd backend/items && npm install && npm start

# Terminal 5 — Frontend
cd client && npm install && npm start

# Terminal 6 — HAProxy
haproxy -f haproxy.cfg
```

---

## ☁️ Azure Infrastructure (Terraform)

### 1. Login to Azure

```bash
az login
az account set --subscription "YOUR_SUBSCRIPTION_ID"
```

### 2. Provision infrastructure

```bash
cd terraform

# Initialise
terraform init

# Preview changes
terraform plan -var-file=terraform.tfvars.example

# Apply (creates AKS, ACR, Key Vault, VNet, Log Analytics)
terraform apply -var-file=terraform.tfvars.example
```

### 3. Configure kubectl

```bash
# Copy the output command from terraform apply, e.g.:
az aks get-credentials --resource-group restauranty-rg --name restauranty-aks
kubectl get nodes
```

---

## 🐳 Build & Push Docker Images

```bash
# Set your ACR login server (from terraform output)
ACR=$(terraform -chdir=terraform output -raw acr_login_server)

# Login to ACR
az acr login --name $ACR

# Build and push all images
SHORT_SHA=$(git rev-parse --short HEAD)

for SVC in auth discounts items; do
  docker build -t $ACR/restauranty-$SVC:$SHORT_SHA ./backend/$SVC
  docker push $ACR/restauranty-$SVC:$SHORT_SHA
done

# Frontend
docker build -t $ACR/restauranty-frontend:$SHORT_SHA ./client
docker push $ACR/restauranty-frontend:$SHORT_SHA
```

---

## ☸️ Deploy to AKS

### 1. Create namespace and secrets

```bash
kubectl apply -f k8s/namespace.yaml

kubectl create secret generic restauranty-secrets \
  --from-literal=SECRET="your-jwt-secret" \
  --from-literal=MONGODB_URI="mongodb+srv://user:pass@cluster.mongodb.net/restauranty" \
  --from-literal=CLOUD_NAME="your-cloudinary-cloud" \
  --from-literal=CLOUD_API_KEY="your-cloudinary-key" \
  --from-literal=CLOUD_API_SECRET="your-cloudinary-secret" \
  --namespace restauranty
```

### 2. Install NGINX Ingress Controller

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace
```

### 3. Update image references

```bash
ACR=$(terraform -chdir=terraform output -raw acr_login_server)
SHORT_SHA=$(git rev-parse --short HEAD)

# Update all deployment manifests with the real image tags
for SVC in auth discounts items; do
  sed -i "s|YOUR_REGISTRY/restauranty-$SVC:latest|$ACR/restauranty-$SVC:$SHORT_SHA|g" \
    k8s/${SVC}-deployment.yaml
done
sed -i "s|YOUR_REGISTRY/restauranty-frontend:latest|$ACR/restauranty-frontend:$SHORT_SHA|g" \
  k8s/frontend-deployment.yaml
```

### 4. Apply all manifests

```bash
kubectl apply -f k8s/
```

### 5. Get public IP

```bash
kubectl get ingress -n restauranty
# Point your domain's A record to the EXTERNAL-IP shown
```

---

## 📊 Monitoring (Prometheus + Grafana)

```bash
# Deploy Prometheus and Grafana
kubectl apply -f monitoring/k8s-monitoring.yaml

# Get Grafana IP
kubectl get svc grafana -n monitoring

# Access: http://<EXTERNAL-IP>:3000
# Default credentials: admin / admin  (change immediately!)
```

Import `monitoring/grafana/dashboard.json` in Grafana:
**+ → Import → Upload JSON file**

---

## 🔄 CI/CD Pipeline

The GitHub Actions pipeline (`.github/workflows/ci-cd.yaml`) runs:

| Trigger | Jobs |
|---|---|
| PR to `main` | Lint + Test all services |
| Push to `main` | Test → Build & Push images → Deploy to AKS |

### Required GitHub Secrets

Go to `Settings → Secrets and variables → Actions` and add:

| Secret | Value |
|---|---|
| `AZURE_CREDENTIALS` | Output of `az ad sp create-for-rbac --sdk-auth` |
| `ACR_LOGIN_SERVER` | e.g. `restaurantyacr.azurecr.io` |
| `ACR_USERNAME` | ACR admin username |
| `ACR_PASSWORD` | ACR admin password |
| `APP_SECRET` | JWT secret |
| `MONGODB_URI` | MongoDB connection string |
| `CLOUD_NAME` | Cloudinary cloud name |
| `CLOUD_API_KEY` | Cloudinary key |
| `CLOUD_API_SECRET` | Cloudinary secret |

### Create the Azure Service Principal

```bash
az ad sp create-for-rbac \
  --name "restauranty-github-actions" \
  --role contributor \
  --scopes /subscriptions/YOUR_SUBSCRIPTION_ID \
  --sdk-auth
# Paste the JSON output as the AZURE_CREDENTIALS secret
```

---

## 🗂️ Project Structure

```
devops.restauranty/
├── .github/
│   └── workflows/
│       └── ci-cd.yaml          # GitHub Actions CI/CD pipeline
├── backend/
│   ├── auth/                   # Auth microservice (port 3001)
│   │   └── Dockerfile
│   ├── discounts/              # Discounts microservice (port 3002)
│   │   └── Dockerfile
│   └── items/                  # Items microservice (port 3003)
│       └── Dockerfile
├── client/                     # React frontend (port 3000)
│   ├── Dockerfile
│   └── nginx.conf
├── k8s/                        # Kubernetes manifests
│   ├── namespace.yaml
│   ├── secrets.yaml
│   ├── auth-deployment.yaml
│   ├── discounts-deployment.yaml
│   ├── items-deployment.yaml
│   ├── frontend-deployment.yaml
│   ├── ingress.yaml
│   └── network-policy.yaml
├── terraform/                  # Azure IaC
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars.example
├── monitoring/                 # Observability
│   ├── prometheus/
│   │   ├── prometheus.yml
│   │   └── alert-rules.yaml
│   ├── grafana/
│   │   └── dashboard.json
│   └── k8s-monitoring.yaml
├── docker-compose.yaml         # Local multi-container dev
├── haproxy.cfg                 # Local load balancer
├── SECURITY.md
└── README.md
```

---

## 🔒 Security

See [SECURITY.md](./SECURITY.md) for the full security posture.

**Quick summary:**
- All secrets in Kubernetes Secrets / Azure Key Vault — never in Git
- Non-root containers with read-only filesystems
- NetworkPolicies enforce default-deny
- TLS enforced at the Ingress (Let's Encrypt)
- JWT authentication on all protected routes

---

## 📝 Environment Variables

Each microservice requires a `.env` file:

```env
SECRET=MySecret1!
MONGODB_URI="mongodb://127.0.0.1:27017/restauranty"
CLOUD_NAME="your-cloudinary-name"
CLOUD_API_KEY="your-cloudinary-key"
CLOUD_API_SECRET="your-cloudinary-secret"
PORT=300x        # 3001 / 3002 / 3003
```

---

## 🆘 Troubleshooting

```bash
# Check pod status
kubectl get pods -n restauranty

# View logs
kubectl logs -n restauranty deployment/auth -f

# Describe a crashing pod
kubectl describe pod -n restauranty <pod-name>

# Check ingress
kubectl get ingress -n restauranty
kubectl describe ingress restauranty-ingress -n restauranty

# Port-forward a service for local debugging
kubectl port-forward svc/auth-service 3001:80 -n restauranty
```
