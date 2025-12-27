#!/bin/bash
# Collect ML environment information for dashboard
# Reports on GPU, CUDA, PyTorch, TensorFlow status

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

OUTPUT_FILE="$REPORTS_DIR/ml-environment.json"

log_info "Collecting ML environment information..."

# Initialize output structure
cat > "$OUTPUT_FILE" <<EOF
{
  "collected": "$(date -u +%Y-%m-%dT%H:%M:%S%z)",
  "hostname": "$(hostname)",
  "gpu": {},
  "cuda": {},
  "pytorch": {},
  "tensorflow": {}
}
EOF

# Function to update JSON field
update_json() {
    local key="$1"
    local value="$2"
    python3 <<PYTHON
import json
with open("$OUTPUT_FILE", 'r') as f:
    data = json.load(f)
keys = "$key".split('.')
obj = data
for k in keys[:-1]:
    if k not in obj:
        obj[k] = {}
    obj = obj[k]
obj[keys[-1]] = $value
with open("$OUTPUT_FILE", 'w') as f:
    json.dump(data, f, indent=2)
PYTHON
}

# Check GPU
if command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null; then
    GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
    DRIVER_VERSION=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1)
    CUDA_VERSION=$(nvidia-smi | grep "CUDA Version" | awk '{print $9}' || echo "N/A")
    GPU_MEMORY_TOTAL=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1)
    GPU_MEMORY_USED=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>/dev/null | head -1)
    GPU_TEMP=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader 2>/dev/null | head -1)
    GPU_UTIL=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -1)

    update_json "gpu.present" "True"
    update_json "gpu.name" "\"$GPU_NAME\""
    update_json "gpu.driver_version" "\"$DRIVER_VERSION\""
    update_json "gpu.memory_total_mb" "$GPU_MEMORY_TOTAL"
    update_json "gpu.memory_used_mb" "$GPU_MEMORY_USED"
    update_json "gpu.temperature_c" "$GPU_TEMP"
    update_json "gpu.utilization_percent" "$GPU_UTIL"
    update_json "gpu.status" "\"healthy\""

    # Check temperature status
    if [[ $GPU_TEMP -gt 85 ]]; then
        update_json "gpu.status" "\"warning\""
        update_json "gpu.status_message" "\"Temperature high: ${GPU_TEMP}°C\""
    elif [[ $GPU_TEMP -gt 95 ]]; then
        update_json "gpu.status" "\"critical\""
        update_json "gpu.status_message" "\"Temperature critical: ${GPU_TEMP}°C\""
    else
        update_json "gpu.status_message" "\"Operating normally\""
    fi

    log_info "✓ GPU: $GPU_NAME (Driver: $DRIVER_VERSION)"
else
    update_json "gpu.present" "False"
    update_json "gpu.status" "\"unavailable\""
    update_json "gpu.status_message" "\"No NVIDIA GPU detected or driver not installed\""
    log_info "No GPU detected"
fi

# Check CUDA toolkit installation
if command -v nvcc &>/dev/null; then
    CUDA_TOOLKIT_VERSION=$(nvcc --version | grep "release" | awk '{print $5}' | sed 's/,//')
    update_json "cuda.toolkit_installed" "True"
    update_json "cuda.toolkit_version" "\"$CUDA_TOOLKIT_VERSION\""
    update_json "cuda.driver_version" "\"$CUDA_VERSION\""
    log_info "✓ CUDA toolkit: $CUDA_TOOLKIT_VERSION"
else
    update_json "cuda.toolkit_installed" "False"
    if [[ -n "${CUDA_VERSION:-}" ]]; then
        update_json "cuda.driver_version" "\"$CUDA_VERSION\""
    fi
    log_info "CUDA toolkit not installed (driver API: ${CUDA_VERSION:-N/A})"
fi

# Check PyTorch
if python3 -c "import torch" &>/dev/null; then
    PYTORCH_VERSION=$(python3 -c "import torch; print(torch.__version__)" 2>/dev/null)
    PYTORCH_CUDA=$(python3 -c "import torch; print('Yes' if torch.cuda.is_available() else 'No')" 2>/dev/null)
    PYTORCH_CUDA_VERSION=$(python3 -c "import torch; print(torch.version.cuda if torch.cuda.is_available() else 'N/A')" 2>/dev/null)

    update_json "pytorch.installed" "True"
    update_json "pytorch.version" "\"$PYTORCH_VERSION\""
    update_json "pytorch.cuda_available" "$([ "$PYTORCH_CUDA" = "Yes" ] && echo "True" || echo "False")"
    update_json "pytorch.cuda_version" "\"$PYTORCH_CUDA_VERSION\""

    if [[ "$PYTORCH_CUDA" = "Yes" ]]; then
        update_json "pytorch.status" "\"healthy\""
        update_json "pytorch.status_message" "\"GPU support enabled\""
        log_info "✓ PyTorch: $PYTORCH_VERSION (CUDA: $PYTORCH_CUDA_VERSION)"
    else
        update_json "pytorch.status" "\"warning\""
        update_json "pytorch.status_message" "\"CPU-only, GPU support not available\""
        log_warning "PyTorch: $PYTORCH_VERSION (CPU-only)"
    fi
else
    update_json "pytorch.installed" "False"
    update_json "pytorch.status" "\"not_installed\""
    log_info "PyTorch not installed"
fi

# Check TensorFlow
if python3 -c "import tensorflow" &>/dev/null; then
    TF_VERSION=$(python3 -c "import tensorflow as tf; print(tf.__version__)" 2>/dev/null)
    TF_GPU=$(python3 -c "import tensorflow as tf; print('Yes' if len(tf.config.list_physical_devices('GPU')) > 0 else 'No')" 2>/dev/null)

    update_json "tensorflow.installed" "True"
    update_json "tensorflow.version" "\"$TF_VERSION\""
    update_json "tensorflow.gpu_available" "$([ "$TF_GPU" = "Yes" ] && echo "True" || echo "False")"

    if [[ "$TF_GPU" = "Yes" ]]; then
        update_json "tensorflow.status" "\"healthy\""
        update_json "tensorflow.status_message" "\"GPU support enabled\""
        log_info "✓ TensorFlow: $TF_VERSION (GPU enabled)"
    else
        update_json "tensorflow.status" "\"warning\""
        update_json "tensorflow.status_message" "\"CPU-only, GPU support not available\""
        log_warning "TensorFlow: $TF_VERSION (CPU-only)"
    fi
else
    update_json "tensorflow.installed" "False"
    update_json "tensorflow.status" "\"not_installed\""
    log_info "TensorFlow not installed"
fi

log_info "✓ ML environment data written to: $OUTPUT_FILE"
