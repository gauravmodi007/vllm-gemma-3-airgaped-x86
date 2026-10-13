# OpenShift Local (CRC) Offline Air-Gapped POC

**Goal:**
Deploy `RedHatAI/gemma-3-1b-it-quantized.w8a8` (and alternatives) in a fully offline OpenShift Local (CRC) environment. Models are downloaded locally to `./offline-models` and `oc cp` transferred into a PersistentVolumeClaim (PVC).

**Workspace Context:**
- **Namespace:** `vllm-gemma-3-x86`
- **PVC Path:** `/models-cache` inside the pod.
- **Execution Environment:** Windows PowerShell (Requires `$env:HF_TOKEN`).

**Workflow for VS Code / GitHub Copilot Agent:**
1. Verify `oc` is available (`oc whoami`). If not, remind user to run `& crc oc-env | Invoke-Expression`.
2. Ensure user has added their token to `.env` and loaded it via `. .\scripts\load-hf-token.ps1`.
3. Execute `.\scripts\00-download-models.ps1` to download weights locally.
4. Execute `.\scripts\01-setup-namespace-pvc.ps1` to create namespace, SCC, and PVC.
5. Execute `.\scripts\02-transfer-to-pvc.ps1` to load files into OpenShift via temporary alpine pod.
6. Execute `.\scripts\03-deploy-offline-app.ps1` to start the air-gapped vLLM instance.
7. Execute `.\scripts\04-test-inference.ps1` to validate the API response.
8. If pod crashes with OOM (Exit 137), execute `.\scripts\05-diagnostics.ps1` and verify memory limits vs model choice (1B vs 4B).

Started the OpenShift cluster.

The server is accessible via web console at:
  https://console-openshift-console.apps-crc.testing

Log in as administrator:
  Username: kubeadmin
  Password: (run `crc console --credentials` to display it)

Log in as user:
  Username: developer
  Password: developer

Use the 'oc' command line interface:
  PS> & crc oc-env | Invoke-Expression
  PS> oc login -u developer https://api.crc.testing:6443
PS C:\Users\ergau\Projects\vllm-gemma-3-x86>