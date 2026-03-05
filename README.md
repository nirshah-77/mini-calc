# mini-calc — End-to-End DevOps Pipeline

A Java square-root calculator deployed through a fully automated CI/CD pipeline:
**Code → Docker → AWS EC2 (Kubernetes) via GitHub Actions + Terraform + Chef**

---

## Architecture Overview

```
 Push to main
      │
      ▼
 GitHub Actions
 ┌─────────────────────────────────┐
 │ Job 1: Build & Push             │
 │  javac SqrtApp.java             │
 │  docker build + push            │
 │  → Docker Hub: nirshah77/sqrt-app│
 └────────────┬────────────────────┘
              │ needs
              ▼
 ┌─────────────────────────────────┐
 │ Job 2: Terraform Apply          │
 │  S3 backend (remote state)      │
 │  Security Group (22/6443/30007) │
 │  EC2 master + EC2 worker        │
 │  user_data → chef-solo runs     │
 │    k8s_setup cookbook:          │
 │      - Docker CE                │
 │      - kubelet/kubeadm/kubectl  │
 │      - kubeadm init (master)    │
 │      - Flannel CNI              │
 └────────────┬────────────────────┘
              │ needs
              ▼
 ┌─────────────────────────────────┐
 │ Job 3: Deploy to Kubernetes     │
 │  SCP k8s/ manifests to master   │
 │  kubectl apply deployment.yaml  │
 │  kubectl apply service.yaml     │
 │  NodePort 30007 exposed         │
 └─────────────────────────────────┘
```

---

## Repository Structure

```
mini-calc/
├── SqrtApp.java                        # Java square-root calculator
├── Dockerfile                          # Build & run the Java app in a container
├── .github/
│   └── workflows/
│       └── pipeline.yml                # GitHub Actions CI/CD pipeline
├── chef/
│   └── cookbooks/
│       └── k8s_setup/
│           ├── metadata.rb             # Cookbook identity
│           └── recipes/
│               └── default.rb         # Installs Docker + Kubernetes
├── k8s/
│   ├── deployment.yaml                 # 2 replicas of the app
│   └── service.yaml                   # NodePort 30007
└── terraform/
    ├── main.tf                         # EC2 + SG + S3 backend
    ├── variables.tf
    └── outputs.tf
```

---

## Prerequisites

### 1. S3 Bucket for Terraform State
Create an S3 bucket in your AWS account before running the pipeline:
```bash
aws s3api create-bucket --bucket <your-bucket-name> --region us-east-1
aws s3api put-bucket-versioning --bucket <your-bucket-name> \
    --versioning-configuration Status=Enabled
```

### 2. EC2 Key Pair
Create an EC2 key pair in the AWS console (or CLI) and download the `.pem` file.

### 3. Ubuntu AMI ID
Find the Ubuntu 22.04 AMI ID for `us-east-1` in the AWS EC2 AMI catalog (e.g., `ami-0c7217cdde317cfec`).

---

## GitHub Secrets to Configure

Go to **Settings → Secrets and variables → Actions → New repository secret** and add:

| Secret | Description |
|---|---|
| `DOCKER_USERNAME` | Docker Hub username (e.g., `nirshah77`) |
| `DOCKER_PASSWORD` | Docker Hub password or access token |
| `AWS_ACCESS_KEY_ID` | AWS IAM access key ID |
| `AWS_SECRET_ACCESS_KEY` | AWS IAM secret access key |
| `EC2_SSH_PRIVATE_KEY` | Full content of your EC2 `.pem` private key file |
| `TF_VAR_AMI` | Ubuntu 22.04 AMI ID for `us-east-1` |
| `TF_VAR_KEY_NAME` | EC2 key pair name (just the name, not the file) |
| `TF_VAR_S3_BUCKET` | Name of the S3 bucket you created for state |

---

## How to Trigger the Pipeline

Simply push to the `main` branch:
```bash
git add .
git commit -m "Initial CI/CD pipeline setup"
git push origin main
```

Watch the run under the **Actions** tab in GitHub.

---

## Verifying the Deployment

After all 3 jobs are green:

1. **Docker Hub** → `hub.docker.com/r/nirshah77/sqrt-app` — `latest` tag exists  
2. **AWS S3** → your state bucket → `mini-calc/terraform.tfstate` file present  
3. **AWS EC2** → `calc-k8s-master` and `calc-k8s-worker` instances running  
4. **Kubernetes** — SSH into the master node:
   ```bash
   ssh -i your-key.pem ubuntu@<MASTER_IP>
   kubectl get nodes        # Both nodes: Ready
   kubectl get pods -o wide # Pod: Running
   kubectl get svc          # calc-service: NodePort 30007
   ```
5. **App accessible** at `http://<MASTER_IP>:30007` (NodePort exposed)

---

## Local Docker Test

To verify the Docker image works locally before pushing:
```bash
docker build -t sqrt-app .
docker run --rm sqrt-app
# Expected output:
# === Square Root Calculator ===
# sqrt(4.0) = 2.0000
# sqrt(9.0) = 3.0000
# ...
```
