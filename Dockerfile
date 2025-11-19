# Use the base image that has necessary CUDA and Python environments
FROM wlsdml1114/multitalk-base:1.3 as runtime

WORKDIR /MultiTalk

# Enable faster downloads (for the entrypoint fallback)
ENV HF_HUB_ENABLE_HF_TRANSFER=1
ENV HF_HUB_DISABLE_PROGRESS_BARS=1

# We do NOT download models here anymore. 
# Instead, we create the directory structure where the volume will be linked.
RUN mkdir -p ./weights/Wan2.1-I2V-14B-480P \
    ./weights/chinese-wav2vec2-base \
    ./weights/Kokoro-82M \
    ./weights/MeiGen-MultiTalk

# --- Final Setup ---
WORKDIR /

# Copy all necessary files
COPY . .

RUN chmod +x ./entrypoint.sh

ENTRYPOINT ["./entrypoint.sh"]