# Optimization for RunPod Serverless Cold Start

This document details the changes made to the project to resolve the issue where the model took 30 minutes to initialize on every RunPod cold start.

## Problem
The original setup downloaded over 20GB of model weights in the `entrypoint.sh` script **at runtime**. 
In a Serverless environment, "cold starts" (starting a fresh worker) are frequent. This meant that for every new worker instance, the system would:
1. Start the container.
2. Run `entrypoint.sh`.
3. Spend ~30 minutes downloading models from Hugging Face.
4. Only then process the request.

## Solution
We moved the model download process from **Runtime** (`entrypoint.sh`) to **Build Time** (`Dockerfile`).
This means the model weights are now "baked into" the Docker image. When RunPod starts a worker, the files are already there, reducing startup time from ~30 minutes to a few seconds (excluding image pull time).

## Step-by-Step Changes

### 1. Fixed `base.Dockerfile` (H100 & Stability Fix)
We downgraded the environment stack to a "Gold Standard" stable version to resolve `RuntimeError: CUDA unknown error` on H100 GPUs and ensure compatibility with RTX 4090/5090.

*   **Base Image**: Changed from `nvidia/cuda:12.8.1` (bleeding edge) to `nvidia/cuda:12.4.1` (stable).
*   **PyTorch**: Changed from `2.7.0` (non-existent/nightly) to `2.5.1+cu124` (Official Stable).
*   **GPU Architecture**: Updated `TORCH_CUDA_ARCH_LIST` to `"7.0;7.5;8.0;8.6;8.9;9.0"`.
    *   `7.0`: Adds support for **V100**.
    *   `7.5`: Adds support for **T4**.
    *   `8.0`: Adds support for **A100**.
    *   `8.6`: Adds support for **A6000 / A40**.
    *   `8.9`: Adds explicit support for **RTX 4090**.
    *   `9.0`: Adds explicit support for **H100**.
    *   (RTX 5090 will work via backward compatibility with these architectures).
*   **Dependencies**: Updated `flash_attn` and `SageAttention` build steps to compile correctly against CUDA 12.4.

### 2. Modified `Dockerfile` (Startup Speed Fix)
We added the following steps to the `Dockerfile` to download models during the `docker build` process:

*   **Enabled Faster Downloads**: Set environment variables `HF_HUB_ENABLE_HF_TRANSFER=1` to speed up Hugging Face downloads.
*   **Downloaded Models**: Added `RUN huggingface-cli download ...` commands for:
    *   `Wan-AI/Wan2.1-I2V-14B-480P`
    *   `TencentGameMate/chinese-wav2vec2-base`
    *   `hexgrad/Kokoro-82M`
    *   `MeiGen-AI/MeiGen-MultiTalk`
*   **Downloaded Extra Components**: Added `wget` commands for LoRA weights (`FusionX_LoRa`, `lightx2v`).
*   **Created Symbolic Links**: Set up necessary symlinks (e.g., linking `MeiGen-MultiTalk` weights to the `Wan2.1` directory) inside the image.
*   **Set Install Flag**: Created a file `/opt/all_installed.flag`. This tells the existing `entrypoint.sh` that the installation is already complete.

### 2. How it Works Now
1.  **Build Phase**: You run `docker build`. The builder downloads all 20GB+ of data and saves it into the image layers.
2.  **Push Phase**: You push this large image to a registry (Docker Hub, etc.).
3.  **RunPod Runtime**:
    *   RunPod pulls the image (cached on their nodes for faster subsequent starts).
    *   Container starts.
    *   `entrypoint.sh` checks for `/opt/all_installed.flag`.
    *   It sees the flag exists, prints "Setup has already been completed", and **skips the download**.
    *   The handler starts immediately.

## Usage
To apply these changes, you must rebuild and push your image:

```bash
# Build the image (this will take time as it downloads the models)
docker build -t <your-docker-username>/multitalk-runpod:v2 .

# Push the image
docker push <your-docker-username>/multitalk-runpod:v2
```

Then, update your RunPod Serverless Endpoint configuration to use the new image tag (`:v2`).
