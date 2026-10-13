import os
import time
from huggingface_hub import snapshot_download

token = os.environ.get("HF_TOKEN")
if not token:
    print("Error: HF_TOKEN environment variable is not set.")
    exit(1)

# The 3 models requested
models = [
    "RedHatAI/gemma-3-1b-it-quantized.w8a8",
    "google/gemma-3-1b-it",
    "RedHatAI/gemma-3-4b-it-quantized.w8a8"
]

print("Starting offline model downloads...")
for repo_id in models:
    local_path = f"./offline-models/{repo_id}"
    os.makedirs(local_path, exist_ok=True)
    
    print(f"\n--- Downloading {repo_id} ---")
    # Using local_dir flattens the files into a normal directory structure, 
    # avoiding Windows symlink issues and making it easy to browse.
    # Connections can reset intermittently; downloads resume on retry.
    for attempt in range(1, 31):
        try:
            snapshot_download(repo_id=repo_id, local_dir=local_path, token=token)
            break
        except Exception as e:
            print(f"Attempt {attempt} failed: {type(e).__name__}; retrying...")
            time.sleep(3)
    else:
        raise SystemExit(f"Failed to download {repo_id}")

print("\nAll models downloaded successfully to ./offline-models/")
