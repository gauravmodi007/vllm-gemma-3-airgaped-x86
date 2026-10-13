# Troubleshooting Log

Errors hit while running the workflow in `agent-prompt.md` on Windows + OpenShift Local (CRC), and how each was resolved.

| # | Step | Error | Cause | Fix |
|---|------|-------|-------|-----|
| 1 | Pre-check | `oc` not recognized | `oc` not on PATH in a new shell | `& crc oc-env \| Invoke-Expression` (needed in every new shell) |
| 2 | 00 download | `pip` `ConnectionResetError(10054)`, then `huggingface_hub.errors.LocalEntryNotFoundError` / `WinError 10054` | Network intermittently resets about half of connections to huggingface.co (curl showed the same). Not a block, and not a Python-specific problem | Added a retry loop (30 attempts, 3s apart) in `scripts/download-models.py`; `snapshot_download` resumes partial files. `HF_HUB_DISABLE_XET=1` was also set for the run |
| 3 | 02 transfer | Loader pod stuck in `ContainerCreating`; event `FailedCreatePodSandBox ... Multus: error waiting for pod: Unauthorized` | Stale Multus service-account token in CRC (typical after the VM has been suspended or has been up a long time) | `oc delete pod -n openshift-multus -l app=multus` (and `-l app=multus-additional-cni-plugins`), then delete and recreate the loader pod |
| 4 | 02 transfer | `oc apply` warning: resource "is currently being deleted" | Re-applied the loader pod while the old one was terminating | `oc delete pod gemma-model-loader --wait=true`, then rerun |
| 5 | 02 transfer | `Websocket Ping failed ... i/o timeout`; only 4.1G of about 10G copied | A single `oc cp` of the whole 10 GB folder dropped its websocket | Copied one model at a time (`oc cp .\offline-models\<org>\<model> ...`) and compared sizes. Files under `.cache` are not needed |
| 6 | 03 deploy | `ImagePullBackOff`: `manifest unknown` for `vllm/vllm-openai-cpu:v0.6.1.post2` | That tag does not exist on Docker Hub | Changed the image to `vllm/vllm-openai-cpu:v0.31.0-x86_64` in `k8s/03-gemma-offline-app.yaml` |
| 7 | 03 deploy | Container restarted once: `ValueError: Available memory on node 0 (0.28/8.0 GiB) ... less than requested memory for kv (1.0 GiB)` | The 8Gi limit left too little free memory for the KV cache during profiling | The restarted container started successfully with no change. See recommendations |

Result: the 1B quantized model serves on the route and `04-test-inference.ps1` returns a valid response. All three models are verified in the PVC.

## Changes applied (all verified end to end)

- `scripts/00-download-models.ps1`: skips the pip install if `huggingface_hub` is present, retries it otherwise, and checks the exit code of the download.
- `scripts/00-preflight.ps1` (new): checks `oc` and login, and detects recent Multus `Unauthorized` errors. `-FixMultus` restarts the Multus pods.
- `scripts/02-transfer-to-pvc.ps1`: copies one model at a time, verifies sizes, retries up to 4 times, and waits for the old loader pod to be gone. It uses relative source paths because `oc cp` reads `C:\...` as a `pod:path` spec.
- `scripts/03-deploy-offline-app.ps1`: prints pod events and previous logs when the rollout fails.
- `scripts/05-diagnostics.ps1`: removed the PowerShell 7-only `||` operator.
- `k8s/03-gemma-offline-app.yaml`: memory limit 8Gi to 10Gi (first start now has 0 restarts), `OMP_NUM_THREADS` 4 to 6, and a comment about mirroring the image.
- `k8s/02-loader-pod.yaml`: note about the ReadWriteOnce PVC.
- `agent-prompt.md`: removed the kubeadmin password (rotate it if the file was shared).

## Original recommendations (for reference)

1. **`scripts/02-transfer-to-pvc.ps1`**: copy per model (loop) with retries and a size check instead of one `oc cp` of `./offline-models`. Wait for any old loader pod to be fully deleted before `oc apply`.
2. **`scripts/00-download-models.ps1`**: stop on the `pip` failure. Skip the install if `huggingface_hub` is already present, and retry it otherwise. Under `$ErrorActionPreference = "Stop"`, pip's stderr warnings can look like failures.
3. **`k8s/03-gemma-offline-app.yaml`**:
   - Pin the image tag deliberately and note it is the x86_64 CPU build.
   - Increase the memory limit or lower `--max-model-len` or `VLLM_CPU_KVCACHE_SPACE` for a clean first start. The `Unhealthy` and restart noise at startup is avoidable.
   - Set `OMP_NUM_THREADS` and the CPU limit consistently. vLLM auto-detected 7 threads while the env var was 4.
4. **`scripts/03-deploy-offline-app.ps1`**: on rollout failure, print `oc describe pod` and `oc logs --previous` automatically, and use a longer timeout for the first image pull.
5. **Add a pre-flight script**: `oc whoami`, and check that no pods in `openshift-multus` or the namespace have `Unauthorized` sandbox events (restart Multus if so).
6. **`k8s/02-loader-pod.yaml`**: the PVC is `ReadWriteOnce`. Remind users to scale the vLLM deployment to 0 first on multi-node clusters. This worked on single-node CRC.
7. **Air-gap note**: the vLLM image is still pulled from Docker Hub. For a true air gap, mirror it to the internal registry (`oc image mirror`) and reference that.
8. **Secrets**: remove the `kubeadmin` password from `agent-prompt.md` and any shared files, and keep `.env` out of version control.
