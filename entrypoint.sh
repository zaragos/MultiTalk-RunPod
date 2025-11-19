#!/bin/bash
set -e

export HF_HUB_ENABLE_HF_TRANSFER=1
export HF_HUB_DISABLE_PROGRESS_BARS=1

# Define paths
VOLUME_PATH="/runpod-volume"
WEIGHTS_DIR="/MultiTalk/weights"
VOLUME_WEIGHTS="$VOLUME_PATH/weights"

echo ">>> Starting Entrypoint Script..."

# Function to download models
download_models() {
    TARGET_DIR=$1
    echo ">>> Downloading models to $TARGET_DIR..."
    
    mkdir -p "$TARGET_DIR"
    cd "$TARGET_DIR"
    
    # Create subdirectories
    mkdir -p Wan2.1-I2V-14B-480P chinese-wav2vec2-base Kokoro-82M MeiGen-MultiTalk

    # Use huggingface-cli (faster)
    huggingface-cli download Wan-AI/Wan2.1-I2V-14B-480P --local-dir ./Wan2.1-I2V-14B-480P
    huggingface-cli download TencentGameMate/chinese-wav2vec2-base --local-dir ./chinese-wav2vec2-base
    huggingface-cli download TencentGameMate/chinese-wav2vec2-base model.safetensors --revision refs/pr/1 --local-dir ./chinese-wav2vec2-base
    huggingface-cli download hexgrad/Kokoro-82M --local-dir ./Kokoro-82M
    huggingface-cli download MeiGen-AI/MeiGen-MultiTalk --local-dir ./MeiGen-MultiTalk

    # Download extra files
    wget -q https://huggingface.co/vrgamedevgirl84/Wan14BT2VFusioniX/resolve/main/FusionX_LoRa/Wan2.1_I2V_14B_FusionX_LoRA.safetensors -O ./Wan2.1_I2V_14B_FusionX_LoRA.safetensors
    wget -q https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan21_T2V_14B_lightx2v_cfg_step_distill_lora_rank32.safetensors -O ./Wan21_T2V_14B_lightx2v_cfg_step_distill_lora_rank32.safetensors

    # Fix index json
    if [ -f "./Wan2.1-I2V-14B-480P/diffusion_pytorch_model.safetensors.index.json" ]; then
        mv ./Wan2.1-I2V-14B-480P/diffusion_pytorch_model.safetensors.index.json ./Wan2.1-I2V-14B-480P/diffusion_pytorch_model.safetensors.index.json_old
    fi
    
    echo ">>> Download complete."
}

# Function to setup symlinks
setup_symlinks() {
    BASE_DIR=$1
    echo ">>> Setting up internal symlinks in $BASE_DIR..."
    
    # Link MeiGen weights to Wan2.1 directory as required by the code
    ln -sf "$BASE_DIR/MeiGen-MultiTalk/diffusion_pytorch_model.safetensors.index.json" "$BASE_DIR/Wan2.1-I2V-14B-480P/"
    ln -sf "$BASE_DIR/MeiGen-MultiTalk/multitalk.safetensors" "$BASE_DIR/Wan2.1-I2V-14B-480P/"
}

# --- Logic Start ---

if [ -d "$VOLUME_PATH" ]; then
    echo ">>> Network Volume detected at $VOLUME_PATH"
    
    # Check if volume has weights. If not, download them.
    if [ ! -d "$VOLUME_WEIGHTS" ] || [ -z "$(ls -A $VOLUME_WEIGHTS)" ]; then
        echo ">>> Volume is empty. Initializing models in volume..."
        download_models "$VOLUME_WEIGHTS"
        setup_symlinks "$VOLUME_WEIGHTS"
    else
        echo ">>> Models found in Network Volume. Skipping download."
    fi
    
    # Remove empty local weights dir if exists (to avoid conflict)
    rm -rf "$WEIGHTS_DIR"
    
    # Link volume weights to application path
    echo ">>> Linking Volume Weights to Application..."
    ln -s "$VOLUME_WEIGHTS" "$WEIGHTS_DIR"
    
else
    echo ">>> NO Network Volume detected."
    # Fallback: Check if we need to download locally
    if [ ! -f "$WEIGHTS_DIR/Wan2.1_I2V_14B_FusionX_LoRA.safetensors" ]; then
        echo ">>> Downloading models to local container (Ephemeral)..."
        download_models "$WEIGHTS_DIR"
        setup_symlinks "$WEIGHTS_DIR"
    fi
fi

# --- Start Handler ---
echo ">>> Starting application..."
cd /
python handler.py
