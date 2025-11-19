# 🗂️ Network Volume Setup Guide for MultiTalk

This guide details how to set up a **RunPod Network Volume** to host the MultiTalk model weights (~20GB).
This strategy allows for **instant cold starts** (< 30s) while keeping your Docker image tiny.

## How it Works
1.  **First Run**: The container detects the empty volume, downloads the models into it (takes ~5 mins), and saves them permanently.
2.  **Subsequent Runs**: The container sees the models are already there, links them, and starts instantly.

---

## Step 1: Create a Network Volume

1.  Go to [RunPod Console](https://console.runpod.io/).
2.  Navigate to **Storage** (or **Network Volumes**).
3.  Click **New Volume**.
4.  **Configure**:
    *   **Name**: `multitalk-weights` (or any name you prefer).
    *   **Data Center**: **IMPORTANT!** Must be the same region where you plan to deploy your GPU workers (e.g., `US-East` or `EU-Romania`). Network volumes are region-specific.
    *   **Size**: `30 GB` (Models are ~20GB, so 30GB gives breathing room).
5.  Click **Create**.

---

## Step 2: Update Your Deployment Template

You need to tell your RunPod Template to mount this volume.

1.  Go to **Serverless** -> **My Templates**.
2.  Edit your `MultiTalk` template.
3.  **Container Image**: Ensure it is pointing to your new lightweight image (e.g., `zaragos/multitalk-worker:v1`).
4.  **Container Disk**: You can lower this to `10 GB` (since models are now on the network volume).
5.  **Network Volume**:
    *   **Volume Path**: `/runpod-volume` (**CRITICAL**: Must be exactly this path).
6.  **Save Template**.

---

## Step 3: Initialize the Volume (First Run)

Now we need to run the container once to populate the volume.

1.  **Deploy an Endpoint** using your updated template.
    *   **Select Volume**: When deploying, you might be asked to select the specific Network Volume you created in Step 1. Make sure it is attached.
2.  **Send a Dummy Request**:
    *   The endpoint will start.
    *   The first request might time out or take 5-10 minutes because the `entrypoint.sh` is downloading the models into the volume.
    *   **Check Logs**: Look at the "Logs" tab in the RunPod console. You should see:
        ```
        >>> Network Volume detected at /runpod-volume
        >>> Volume is empty. Initializing models in volume...
        >>> Downloading models to /runpod-volume/weights...
        ...
        >>> Download complete.
        ```
3.  **Wait for "Ready"**: Once the logs say "Starting application...", the volume is populated.

---

## Step 4: Production Use

Once Step 3 is done, your volume contains all the files.

*   **Restart/New Workers**: Any new worker started with this Volume attached will skip the download.
*   **Logs**: You will see:
    ```
    >>> Network Volume detected at /runpod-volume
    >>> Models found in Network Volume. Skipping download.
    >>> Linking Volume Weights to Application...
    ```
*   **Startup Time**: Should be < 30 seconds.

## Troubleshooting

*   **"No Network Volume detected"**: You didn't attach the volume or mounted it to the wrong path. Check Template settings -> Volume Mount Path must be `/runpod-volume`.
*   **Slow Startup Every Time**: The volume might not be persisting. Ensure you didn't delete the volume.
