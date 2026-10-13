# Gemma 3 Air-Gapped (Offline) Architecture on OpenShift Local (CRC)

This project provides a fully air-gapped, offline deployment of Gemma 3 models on OpenShift Local (CRC) using a PersistentVolumeClaim (PVC). 

## Why Air-Gapped?
- **Zero In-Cluster Internet:** The vLLM pod is physically blocked from reaching the internet (`HF_HUB_OFFLINE="1"`).
- **Secure Credential Handling:** Your `HF_TOKEN` never enters the Kubernetes cluster.
- **Explicit File Paths:** We download standard folders rather than Hugging Face symlinks, making model swapping extremely simple.

---

## 🛠️ Manual Step-by-Step Instructions

### Step 1: Pre-requisites & Setup
1. **OpenShift Local (CRC):** Ensure CRC is running and you are logged in:
   ```powershell
   & crc oc-env | Invoke-Expression
   oc login -u kubeadmin https://api.crc.testing:6443
   ```
2. **Environment File:** Copy your Hugging Face token (starting with `hf_`) into the `.env` file replacing `your_token_here`.
3. **Load Token:** Run the loader script in your PowerShell session:
   ```powershell
   . .\scripts\load-hf-token.ps1
   ```

### Step 2: Download Models Locally (Windows Host)
Run the download script. This uses Python to fetch ~10GB of model weights directly to the `./offline-models` folder on your local machine.
```powershell
.\scripts\00-download-models.ps1
```

### Step 3: Setup OpenShift Infrastructure
Create the `vllm-gemma-3-x86` namespace, apply security contexts, and create the 20Gi PVC.
```powershell
.\scripts\01-setup-namespace-pvc.ps1
```

### Step 4: Transfer Models to PVC (The Air-Gap Bridge)
This script spins up a temporary Alpine Linux pod, copies the `./offline-models` folder from your Windows machine into the OpenShift PVC over your local network, and then deletes the temporary pod.
```powershell
.\scripts\02-transfer-to-pvc.ps1
```

### Step 5: Deploy the Offline vLLM Server
Launch the vLLM server. Because networking is disabled inside the pod and the weights are already on disk, startup is fast.
```powershell
.\scripts\03-deploy-offline-app.ps1
```

### Step 6: Test Inference
Send a sample completion request to the running pod.
```powershell
.\scripts\04-test-inference.ps1
```

---

## 🔄 How to Swap Models & Adjust Memory

By default, the deployment runs the `RedHatAI/gemma-3-1b-it-quantized.w8a8` model which requires **~7GB** of memory and fits perfectly inside the default 18GB CRC setup with an **8Gi pod limit**.

To switch models, open `k8s/03-gemma-offline-app.yaml` and modify the `--model` argument and the container `limits`.

### Option A: Unquantized 1B Model
- **Change `--model` to:** `/models-cache/offline-models/google/gemma-3-1b-it`
- **Memory Requirements:** Fits within the current `8Gi` pod limit on the standard 18GB CRC VM.

### Option B: Quantized 4B Model (Requires CRC Memory Increase)
The 4B model requires ~10.5GB of RAM to run. You must first increase your CRC VM memory from 18GB to 24GB.
1. `crc stop`
2. `crc config set memory 24576`
3. `crc start`
4. **Change `--model` to:** `/models-cache/offline-models/RedHatAI/gemma-3-4b-it-quantized.w8a8`
5. **Change YAML Memory Limit:**
   ```yaml
   resources:
     requests:
       memory: "8Gi"
     limits:
       memory: "12Gi" # Increased for 4B
   ```
6. Re-apply the deployment: `oc apply -f k8s/03-gemma-offline-app.yaml -n vllm-gemma-3-x86`

---

## 📡 Sample API Calls

If you want to test the API using standard `curl`, here is the raw request format. Replace `<ROUTE_HOST>` with the output of `oc get route gemma-1b-offline -n vllm-gemma-3-x86 -o jsonpath='{.spec.host}'`.

```bash
curl -X POST "http://<ROUTE_HOST>/v1/chat/completions" \
     -H "Content-Type: application/json" \
     -d '{
       "model": "/models-cache/offline-models/RedHatAI/gemma-3-1b-it-quantized.w8a8",
       "messages": [
         {"role": "user", "content": "Explain air-gapped container networks."}
       ],
       "max_tokens": 100,
       "temperature": 0.2
     }'
```
