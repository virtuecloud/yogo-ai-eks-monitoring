# VirtueCloud Yogo-AI Onboarding Guide

Welcome to VirtueCloud! This guide explains how to deploy the `yogo-ai` machine learning agent into your own AWS EKS cluster and securely connect it to our Central Dashboard.

Our architecture uses a **Push-Based, Zero-Trust model**. You do not need to grant us cross-account IAM roles or expose your cluster to the public internet. Instead, we use an internal load balancer combined with an API Gateway VPC Link.

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

## Step 1: Deploy the Helm Chart
First, you will deploy the `yogo-ai` application into your EKS cluster using either the provided Helm chart tarball (`.tgz`) or the actual unarchived chart directory, along with the `client-values.yaml` configuration file.

1. **Configure your Secrets**: Copy `client-values.yaml.example` to `client-values.yaml` and open it in a text editor.
   - Insert your AI provider's API key.
   - Generate a random string and place it in the two `token` fields.

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

Once the chart is deployed, you need to expose the services using an **Internal AWS Network Load Balancer (NLB)**. This ensures that your services are completely isolated from the public internet.

Apply the provided load balancer configurations:
```bash
kubectl apply -f internal-nlbs.yaml
```

Wait a few minutes for the AWS Load Balancers to be provisioned. You can check their status by running:

```bash
kubectl get svc -n yogo-ai
```
Look at the `EXTERNAL-IP` column for `dot-ai-nlb` and `dot-ai-qdrant-nlb`. If it says `<pending>`, they are still provisioning. Once an AWS hostname (e.g., `internal-k8s-...amazonaws.com`) appears, they are successfully provisioned.
---

## Step 2: Retrieve your CloudFormation Parameters
To securely expose the endpoints to VirtueCloud, you need to deploy the provided CloudFormation template. You will need 5 pieces of information:

1. **`ClusterName`**: 
   - The exact name of your EKS cluster (e.g., `production-eks`).
2. **`VpcId`**:
   - The VPC ID where your EKS cluster is deployed.
3. **`SubnetIds`**:
   - Select at least two subnets in your VPC where the internal load balancers reside.
4. **`YogoAiLoadBalancerArn`** & **`QdrantLoadBalancerArn`**:
   - Run the following command to get the hostnames of the newly created internal Load Balancers:
     ```bash
     kubectl get svc -n dot-ai
     ```
   - Look for the `EXTERNAL-IP` of `dot-ai-nlb` and `dot-ai-qdrant-nlb`.
   - Run the following exact CLI commands (replace `<EXTERNAL-IP>` with the actual hostnames) to retrieve the ARNs:
     ```bash
     # Get Yogo-AI NLB ARN
     aws elbv2 describe-load-balancers --query "LoadBalancers[?contains(DNSName, '<DOT_AI_EXTERNAL_IP>')].LoadBalancerArn" --output text
     
     # Get Qdrant NLB ARN
     aws elbv2 describe-load-balancers --query "LoadBalancers[?contains(DNSName, '<QDRANT_EXTERNAL_IP>')].LoadBalancerArn" --output text
     ```

---

## Step 3: Run the CloudFormation Template
Deploy the `yogo-ai-cloudformation.yaml` template using the AWS CloudFormation Console. 
**Note:** You must run this CloudFormation stack individually for *each* EKS cluster you are onboarding.

**Option A: 1-Click Deployment (Recommended)**
Use the following 1-click URL to automatically load the template in your AWS Console (ensure you are logged into your AWS account):
[Launch Yogo-AI CloudFormation Stack](https://console.aws.amazon.com/cloudformation/home?region=ap-south-1#/stacks/create/review?templateURL=https://dashboard-client-assets-898896902478-prod.s3.ap-south-1.amazonaws.com/client-setup/yogo-ai-cloudformation.yaml&stackName=yogo-ai-eks-Integration)

**Option B: Manual Upload**
1. Go to **AWS CloudFormation** -> **Create Stack** (With new resources).
2. Upload the local `yogo-ai-cloudformation.yaml` file provided in this folder.
3. Fill in the parameters you gathered in Step 2.
4. Click **Next** through the options and hit **Submit**.

*What does this do?*
It creates an API Gateway with a VPC Link. This acts as a secure tunnel from the API Gateway directly into your private subnets to reach the internal Load Balancer. It also provisions a secure API Key.

---

## Step 4: Finalize the Connection
Once the CloudFormation stack status says `CREATE_COMPLETE`, run the following command to fetch your secure endpoints and API key:

```bash
aws cloudformation describe-stacks \
  --stack-name <YOUR_STACK_NAME> \
  --query "Stacks[0].Outputs" \
  --output table
```

You will receive 3 values:
- `YogoAiApiUrl`
- `QdrantUrl`
- `MonitoringApiKey` (Note: This is only the API Key ID)

**Important:** The `MonitoringApiKey` output only provides the Key ID, because AWS hides the secret value. To get the actual key value:
1. Go to the **AWS Console**.
2. Navigate to **API Gateway** -> **API Keys**.
3. Select the Key ID that matches the output from the CloudFormation stack.
4. Click **Show** to reveal the actual API Key value.

**Final Step:** Please **log into your VirtueCloud Central Dashboard**, navigate to the specific **Kubernetes Cluster Monitoring page**, and input the two URLs and the **actual API Key value** when prompted. The dashboard will securely encrypt and save the API Key, establishing the secure connection between the AI Agent and your cluster!
