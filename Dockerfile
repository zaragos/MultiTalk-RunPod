# Use the base image that has necessary CUDA and Python environments
FROM wlsdml1114/multitalk-base:1.3 as runtime

# --- Pre-download Models during Build ---
WORKDIR /MultiTalk

# Enable faster downloads
ENV HF_HUB_ENABLE_HF_TRANSFER=1
ENV HF_HUB_DISABLE_PROGRESS_BARS=1

# 1. Download Models
# We use huggingface-cli which is more standard than 'hf'
RUN huggingface-cli download Wan-AI/Wan2.1-I2V-14B-480P --local-dir ./weights/Wan2.1-I2V-14B-480P && \
    huggingface-cli download TencentGameMate/chinese-wav2vec2-base --local-dir ./weights/chinese-wav2vec2-base && \
    huggingface-cli download TencentGameMate/chinese-wav2vec2-base model.safetensors --revision refs/pr/1 --local-dir ./weights/chinese-wav2vec2-base && \
    huggingface-cli download hexgrad/Kokoro-82M --local-dir ./weights/Kokoro-82M && \
    huggingface-cli download MeiGen-AI/MeiGen-MultiTalk --local-dir ./weights/MeiGen-MultiTalk

# 2. Rename and Download Extra Files
RUN mv ./weights/Wan2.1-I2V-14B-480P/diffusion_pytorch_model.safetensors.index.json ./weights/Wan2.1-I2V-14B-480P/diffusion_pytorch_model.safetensors.index.json_old && \
    wget -q https://huggingface.co/vrgamedevgirl84/Wan14BT2VFusioniX/resolve/main/FusionX_LoRa/Wan2.1_I2V_14B_FusionX_LoRA.safetensors -O ./weights/Wan2.1_I2V_14B_FusionX_LoRA.safetensors && \
    wget -q https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan21_T2V_14B_lightx2v_cfg_step_distill_lora_rank32.safetensors -O ./weights/Wan21_T2V_14B_lightx2v_cfg_step_distill_lora_rank32.safetensors

# 3. Create Symlinks
RUN ln -s /MultiTalk/weights/MeiGen-MultiTalk/diffusion_pytorch_model.safetensors.index.json /MultiTalk/weights/Wan2.1-I2V-14B-480P/ && \
    ln -s /MultiTalk/weights/MeiGen-MultiTalk/multitalk.safetensors /MultiTalk/weights/Wan2.1-I2V-14B-480P/

# 4. Create the install flag to signal entrypoint.sh that setup is done
RUN touch /opt/all_installed.flag

# --- Final Setup ---
WORKDIR /

# Copy all necessary files from your project folder into the container.
# This includes the modified entrypoint.sh, handler.py, and any other required files.
COPY . .

RUN chmod +x ./entrypoint.sh

# Set the entrypoint script to run when the container starts.
# All setup tasks are now handled within this script.
ENTRYPOINT ["./entrypoint.sh"]