# 🚀 Deployment Guide: MultiTalk on RunPod Serverless

This guide will walk you through taking this modified template, pushing it to your own GitHub, building the Docker images, and deploying it to RunPod.

## Prerequisites

1.  **GitHub Account**: To host your code.
2.  **Docker Hub Account**: To host your Docker images (the heavy model files).
3.  **RunPod Account**: To run the GPU worker.
4.  **Installed locally**:
    *   Git
    *   Docker Desktop

---

## Step 1: Push Code to GitHub

Since you cloned this and modified it, you should save it to your own repository.

1.  **Create a new Repository on GitHub**:
    *   Go to [GitHub.com](https://github.com) -> Click **New Repository**.
    *   Name it `MultiTalk-RunPod` (or similar).
    *   **Do NOT** check "Initialize with README". Create an empty repo.

2.  **Push your local code**:
    Open your terminal (in this project folder) and run:

    ```bash
    # Remove the original git link (since you cloned someone else's)
    rm -rf .git
    
    # Initialize your own git
    git init
    git add .
    git commit -m "Initial commit with H100 fix and baked-in models"
    
    # Link to your new GitHub repo (Replace YOUR_USERNAME)
    git remote add origin https://github.com/YOUR_USERNAME/MultiTalk-RunPod.git
    
    # Push
    git branch -M main
    git push -u origin main
    ```

---

## Step 2: Build and Push the Docker Images

This is the most important part. We have two images to build: the **Base** (system dependencies) and the **Worker** (models + code).

### 2.1 Login to Docker
In your terminal:
```bash
docker login
# Enter your Docker Hub username and password
```

### 2.2 Build the Base Image
*Run this first. It sets up CUDA 12.4 and PyTorch 2.5.1.*

```bash
# Replace 'YOUR_DOCKER_USER' with your actual Docker Hub username
docker build -t YOUR_DOCKER_USER/multitalk-base:1.3 -f base.Dockerfile .

docker push YOUR_DOCKER_USER/multitalk-base:1.3
```

> **IMPORTANT**: Once this is pushed, you **MUST** open `Dockerfile` (not base.Dockerfile) and update line 2 to use **your** new base image name:
>
> **Change:**
> `FROM wlsdml1114/multitalk-base:1.3 as runtime`
> **To:**
> `FROM YOUR_DOCKER_USER/multitalk-base:1.3 as runtime`

### 2.3 Build the Worker Image
*This will take a while (10-20 mins) because it downloads 20GB+ of models during the build.*

```bash
# Replace 'YOUR_DOCKER_USER' with your actual Docker Hub username
docker build -t YOUR_DOCKER_USER/multitalk-worker:v1 .

docker push YOUR_DOCKER_USER/multitalk-worker:v1
```

---

## Step 3: Deploy on RunPod

1.  **Go to RunPod Console**: [console.runpod.io](https://console.runpod.io/)
2.  **Navigate to Serverless** -> **My Templates**.
3.  **Click "New Template"**:
    *   **Template Name**: `MultiTalk v1`
    *   **Container Image**: `YOUR_DOCKER_USER/multitalk-worker:v1` (The one you just pushed)
    *   **Container Disk**: `40 GB` (We need space for the uncompressed models)
    *   **Env Variables**:
        *   `HF_TOKEN` (Optional, if you need to access private repos, otherwise leave blank)
4.  **Save Template**.
5.  **Create Endpoint**:
    *   Go to **Serverless** -> **Endpoints**.
    *   Click **New Endpoint**.
    *   Select your `MultiTalk v1` template.
    *   Select a GPU (RTX 4090, A100, H100 - all will work now!).
    *   Click **Deploy**.

---

## Step 4: Test It

Once the endpoint says **"Ready"** (it might take a minute to pull the image the first time), use the example python code in `README.md` to send a request.

Since the models are baked in, your first request should start processing in seconds, not 30 minutes!
