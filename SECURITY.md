# Security Policy — Restauranty

## 1. IAM & Access Control

| Layer | Approach |
|---|---|
| Azure RBAC | Least-privilege roles per team member; no standing Owner access |
| AKS RBAC | Kubernetes RBAC — `ClusterRole` / `RoleBinding` per namespace |
| Service Identity | AKS uses a **SystemAssigned Managed Identity** — no client secrets in code |
| ACR Access | AKS kubelet identity granted **AcrPull** role only via `azurerm_role_assignment` |

## 2. Secret Management

- **Never** commit secrets to Git. All `.env` files are listed in `.gitignore`.
- **Local development**: secrets stored in `.env` files (not tracked).
- **CI/CD**: secrets stored in GitHub Actions Encrypted Secrets (`Settings → Secrets → Actions`).
- **Kubernetes (production)**: secrets injected as `kind: Secret` objects and referenced via `secretKeyRef` in pod specs. Manifests use placeholder values; real values are applied by the pipeline.
- **Recommended**: migrate to **Azure Key Vault** with the [Secrets Store CSI Driver](https://secrets-store-csi-driver.sigs.k8s.io/) for zero-secret-in-etcd storage.

### Secrets Required

| Key | Description |
|---|---|
| `SECRET` | JWT signing secret |
| `MONGODB_URI` | MongoDB connection string |
| `CLOUD_NAME` | Cloudinary cloud name |
| `CLOUD_API_KEY` | Cloudinary API key |
| `CLOUD_API_SECRET` | Cloudinary API secret |
| `AZURE_CREDENTIALS` | Service principal JSON for GitHub Actions → Azure |
| `ACR_LOGIN_SERVER` | Azure Container Registry login server |
| `ACR_USERNAME` / `ACR_PASSWORD` | ACR credentials |

## 3. Network Security

- **Ingress** is the only publicly exposed endpoint (port 443). All backend services use `ClusterIP` (internal only).
- **NetworkPolicies** (`k8s/network-policy.yaml`) enforce:
  - Default-deny on all pods
  - Backend pods only accept traffic from within the `restauranty` namespace
  - Egress restricted to DNS (UDP/TCP 53) and MongoDB (27017)
- **TLS/HTTPS**: the Ingress resource terminates TLS using a certificate from `cert-manager` (Let's Encrypt). HTTP is automatically redirected to HTTPS.
- **Azure NSG**: the AKS node pool subnet has an NSG allowing only 443 inbound from the internet.

## 4. Container Security

- All microservice images run as **non-root** (`runAsNonRoot: true`, `runAsUser: 1000`).
- Containers use `readOnlyRootFilesystem: true` and drop all Linux capabilities (`capabilities.drop: ALL`).
- Images use **multi-stage builds** to minimise the attack surface (no dev dependencies in the final image).
- Images are based on `node:20-alpine` (minimal OS footprint).
- **Image scanning**: integrate [Microsoft Defender for Containers](https://learn.microsoft.com/azure/defender-for-cloud/defender-for-containers-introduction) or Trivy in the CI pipeline.

## 5. Authentication & Authorisation

- The **auth** microservice issues signed **JWT tokens** (HS256) with expiry.
- The **discounts** and **items** microservices validate tokens via shared middleware before processing any request.
- Passwords are hashed with **bcrypt** before storage.
- Tokens are never logged.

## 6. Data Encryption

| Data | Encryption |
|---|---|
| Data in transit | TLS 1.2+ enforced at the Ingress |
| Data at rest (MongoDB Atlas) | AES-256 encryption at rest (Atlas default) |
| Data at rest (Azure disks) | Azure-managed encryption (SSE with platform keys) |
| Secrets in etcd | Kubernetes secret encryption at rest (enable via AKS encryption config) |

## 7. Compliance Considerations

- **GDPR**: user PII (email, name) is stored in MongoDB. Implement a data-deletion API endpoint to support the right to erasure.
- **Logging**: avoid logging PII. Mask email addresses in log output.
- **Audit logs**: AKS control plane audit logs are forwarded to Azure Log Analytics.
- **Dependency scanning**: use `npm audit` in CI (`npm audit --audit-level=high`).

## 8. Reporting a Vulnerability

Please open a **private security advisory** via GitHub (`Security → Advisories → New draft`) rather than a public issue.
