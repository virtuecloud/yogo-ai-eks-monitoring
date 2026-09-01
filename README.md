# VirtueCloud Yogo-AI Onboarding Guide

Welcome to VirtueCloud! This guide explains how to deploy the `yogo-ai` machine learning agent into your own AWS EKS cluster and securely connect it to our Central Dashboard.

Our architecture uses a **Push-Based, Zero-Trust model**. You do not need to grant us cross-account IAM roles or expose your cluster to the public internet. Instead, the `yogo-ai` agent establishes an outbound-only WebSocket tunnel back to our secure centralized Dashboard.

## Prerequisites
- An active AWS EKS Cluster.
- `kubectl` and `helm` installed and configured to communicate with your cluster.
- The `yogo-ai` Helm chart directory (provided by us).

---

## Step 0: Accessing Container Images (ECR Setup)
The `yogo-ai` container images are securely hosted in VirtueCloud's private Amazon Elastic Container Registry (ECR). 

When you onboard and link your AWS account in the Yogo Cloud Dashboard, your AWS Account ID is **automatically whitelisted** in our ECR repositories. This automatically grants the IAM Roles assigned to your EKS worker nodes cross-account permissions to pull the images.

No manual authentication steps, Image Pull Secrets, or additional configurations are required.

---

## Step 1: AI Inference Security Setup (IRSA)
Yogo-AI uses AWS IAM Roles for Service Accounts (IRSA) for secure, keyless access to Bedrock AI models.
Before deploying, you must provide your cluster's OIDC Issuer URL to your VirtueCloud Administrator.

1. Retrieve your OIDC Issuer URL by running:
   ```bash
   aws eks describe-cluster --name <cluster-name> --query "cluster.identity.oidc.issuer" --output text
   ```
2. Send this URL to your VirtueCloud Administrator.
3. Your Administrator will register this URL and provide you with an **IAM Role ARN** (e.g., `arn:aws:iam::...`) to use in your `client-values.yaml` configuration.

---

## Step 2: Deploy the Helm Chart
First, you will deploy the `yogo-ai` application into your EKS cluster using either the provided Helm chart tarball (`.tgz`) or the actual unarchived chart directory, along with the `client-values.yaml` configuration file.

1. **Configure your Secrets**: Copy `client-values.yaml.example` to `client-values.yaml` and open it in a text editor.
   - Insert the `socketToken` provided by the VirtueCloud Central Dashboard.
   - Insert the **IAM Role ARN** provided by your Administrator into the `serviceAccount.annotations` section.
   - Generate a random string and place it in the `token` field under `auth`.

2. **Deploy the Chart**: Navigate to the directory containing these files and run one of the following commands depending on your preference:

**Option A: Using the `.tgz` package**
```bash
# Note: We use the 'dot-ai' namespace and release name for internal compatibility
helm install dot-ai ./yogo-ai-stack-0.67.0.tgz -f client-values.yaml --namespace yogo-ai --create-namespace
```

**Option B: Using the raw chart directory**
```bash
# Note: We use the 'dot-ai' namespace and release name for internal compatibility
helm install dot-ai ./yogo-ai-stack -f client-values.yaml --namespace yogo-ai --create-namespace
```

Once the chart is deployed, the Yogo-AI agent will automatically establish an outbound WebSocket connection to the VirtueCloud central dashboard. You do not need to configure any inbound networking, load balancers, or CloudFormation stacks.

---

## Step 3: Finalize the Connection
Please **log into your VirtueCloud Central Dashboard**, navigate to the specific **Kubernetes Cluster Monitoring page**, and input the `auth.token` you generated in your `client-values.yaml` when prompted. The dashboard will securely connect to your AI Agent!
