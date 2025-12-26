#!/bin/bash
# GPU and CUDA environment health checks for ML/AI development
# Checks NVIDIA driver, CUDA toolkit, and Python GPU framework support

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Check if NVIDIA GPU is present
check_nvidia_hardware() {
    log_info "Checking for NVIDIA GPU hardware..."

    if ! lspci | grep -i nvidia &>/dev/null; then
        log_debug "No NVIDIA GPU detected in system"
        return 1
    fi

    local gpu_info=$(lspci | grep -i nvidia | head -1)
    log_info "✓ NVIDIA GPU detected: $gpu_info"
    return 0
}

# Check NVIDIA driver installation and health
check_nvidia_driver() {
    log_info "Checking NVIDIA driver..."

    # Check if nvidia-smi exists
    if ! command -v nvidia-smi &>/dev/null; then
        log_warning "nvidia-smi not found - NVIDIA driver not installed"
        update_alerts "high" "nvidia-driver-missing" \
            "NVIDIA Driver Not Installed" \
            "nvidia-smi command not available. Install with: sudo apt install nvidia-driver-XXX (check ubuntu-drivers devices for recommended version)"
        return 1
    fi

    # Check if driver is loaded and working
    if ! nvidia-smi &>/dev/null; then
        log_error "nvidia-smi fails - driver not loaded or broken"
        update_alerts "high" "nvidia-driver-failed" \
            "NVIDIA Driver Not Working" \
            "nvidia-smi command fails. Driver may not be loaded. Check: dmesg | grep -i nvidia. May need reboot after driver update or kernel upgrade."
        return 1
    fi

    # Get driver and CUDA version
    local driver_version=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1)
    local cuda_version=$(nvidia-smi --query-gpu=cuda_version --format=csv,noheader 2>/dev/null | head -1)
    local gpu_count=$(nvidia-smi --query-gpu=count --format=csv,noheader 2>/dev/null | head -1)

    log_info "✓ NVIDIA driver version: $driver_version"
    log_info "✓ CUDA driver API version: $cuda_version"
    log_info "✓ GPU count: $gpu_count"

    clear_alert "nvidia-driver-missing"
    clear_alert "nvidia-driver-failed"

    return 0
}

# Check GPU health (temperature, memory, utilization)
check_gpu_health() {
    log_info "Checking GPU health..."

    if ! command -v nvidia-smi &>/dev/null; then
        return 1
    fi

    # Get GPU temperature
    local temps=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader 2>/dev/null)
    local max_temp=0

    while read -r temp; do
        log_info "GPU temperature: ${temp}°C"
        if [[ $temp -gt $max_temp ]]; then
            max_temp=$temp
        fi
    done <<< "$temps"

    if [[ $max_temp -gt 85 ]]; then
        log_warning "GPU temperature high: ${max_temp}°C"
        update_alerts "medium" "gpu-temperature-high" \
            "High GPU Temperature" \
            "GPU temperature is ${max_temp}°C. Check cooling and GPU load."
    elif [[ $max_temp -gt 95 ]]; then
        log_critical "GPU temperature critical: ${max_temp}°C"
        update_alerts "high" "gpu-temperature-critical" \
            "Critical GPU Temperature" \
            "GPU temperature is ${max_temp}°C. Risk of thermal throttling or damage."
    else
        clear_alert "gpu-temperature-high"
        clear_alert "gpu-temperature-critical"
    fi

    # Get GPU memory usage
    local mem_used=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>/dev/null | head -1)
    local mem_total=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1)
    local mem_percent=$((mem_used * 100 / mem_total))

    log_info "GPU memory: ${mem_used}MB / ${mem_total}MB (${mem_percent}%)"

    # Get GPU utilization
    local gpu_util=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -1)
    log_info "GPU utilization: ${gpu_util}%"

    return 0
}

# Check CUDA toolkit installation
check_cuda_toolkit() {
    log_info "Checking CUDA toolkit installation..."

    # Check for nvcc (CUDA compiler)
    if command -v nvcc &>/dev/null; then
        local nvcc_version=$(nvcc --version | grep "release" | awk '{print $5}' | sed 's/,//')
        log_info "✓ CUDA toolkit installed: $nvcc_version"

        # Check if nvcc version matches driver CUDA version
        local driver_cuda=$(nvidia-smi --query-gpu=cuda_version --format=csv,noheader 2>/dev/null | head -1)
        log_info "Driver CUDA API: $driver_cuda, Toolkit: $nvcc_version"

        clear_alert "cuda-toolkit-missing"
    else
        log_warning "CUDA toolkit (nvcc) not found in PATH"
        update_alerts "medium" "cuda-toolkit-missing" \
            "CUDA Toolkit Not Found" \
            "nvcc compiler not found. Install CUDA toolkit or add to PATH. Check: /usr/local/cuda*/bin/nvcc"
    fi

    # Check CUDA library paths
    if [[ -d "/usr/local/cuda" ]]; then
        log_info "✓ CUDA installation found at /usr/local/cuda"
    fi

    # Check for cuDNN (required for deep learning)
    if ldconfig -p 2>/dev/null | grep -q "libcudnn"; then
        local cudnn_version=$(ldconfig -p 2>/dev/null | grep "libcudnn.so" | head -1 | awk '{print $1}' | grep -oP '\d+')
        log_info "✓ cuDNN library found (version $cudnn_version)"
        clear_alert "cudnn-missing"
    else
        log_debug "cuDNN library not found (optional for deep learning)"
        # Don't alert - cuDNN is optional
    fi

    return 0
}

# Check PyTorch CUDA support
check_pytorch_cuda() {
    log_info "Checking PyTorch CUDA support..."

    # Check if PyTorch is installed
    if ! python3 -c "import torch" 2>/dev/null; then
        log_debug "PyTorch not installed, skipping"
        return 0
    fi

    local torch_version=$(python3 -c "import torch; print(torch.__version__)" 2>/dev/null)
    log_info "PyTorch version: $torch_version"

    # Check CUDA availability
    local cuda_available=$(python3 -c "import torch; print(torch.cuda.is_available())" 2>/dev/null)

    if [[ "$cuda_available" == "True" ]]; then
        local cuda_count=$(python3 -c "import torch; print(torch.cuda.device_count())" 2>/dev/null)
        local cuda_version=$(python3 -c "import torch; print(torch.version.cuda)" 2>/dev/null)
        local device_name=$(python3 -c "import torch; print(torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'N/A')" 2>/dev/null)

        log_info "✓ PyTorch can access GPU"
        log_info "  - CUDA devices: $cuda_count"
        log_info "  - PyTorch CUDA version: $cuda_version"
        log_info "  - Device: $device_name"

        clear_alert "pytorch-cuda-unavailable"
    else
        log_warning "PyTorch installed but CUDA unavailable"
        update_alerts "high" "pytorch-cuda-unavailable" \
            "PyTorch Cannot Access GPU" \
            "torch.cuda.is_available() returns False. Common causes: CUDA version mismatch (PyTorch built for different CUDA), driver issue, or wrong PyTorch build (CPU-only). Reinstall with: pip install torch --index-url https://download.pytorch.org/whl/cu<version>"
    fi

    return 0
}

# Check TensorFlow CUDA support
check_tensorflow_cuda() {
    log_info "Checking TensorFlow CUDA support..."

    # Check if TensorFlow is installed
    if ! python3 -c "import tensorflow" 2>/dev/null; then
        log_debug "TensorFlow not installed, skipping"
        return 0
    fi

    local tf_version=$(python3 -c "import tensorflow as tf; print(tf.__version__)" 2>/dev/null)
    log_info "TensorFlow version: $tf_version"

    # Check GPU availability
    local tf_gpus=$(python3 -c "import tensorflow as tf; print(len(tf.config.list_physical_devices('GPU')))" 2>/dev/null)

    if [[ "$tf_gpus" -gt 0 ]]; then
        log_info "✓ TensorFlow can access GPU ($tf_gpus devices)"
        clear_alert "tensorflow-cuda-unavailable"
    else
        log_warning "TensorFlow installed but no GPU devices found"
        update_alerts "high" "tensorflow-cuda-unavailable" \
            "TensorFlow Cannot Access GPU" \
            "tf.config.list_physical_devices('GPU') returns empty. Check CUDA/cuDNN version compatibility with TensorFlow version. TensorFlow 2.x requires specific CUDA/cuDNN versions."
    fi

    return 0
}

# Check JAX CUDA support (if installed)
check_jax_cuda() {
    log_info "Checking JAX CUDA support..."

    if ! python3 -c "import jax" 2>/dev/null; then
        log_debug "JAX not installed, skipping"
        return 0
    fi

    local jax_version=$(python3 -c "import jax; print(jax.__version__)" 2>/dev/null)
    log_info "JAX version: $jax_version"

    # Check if JAX can see GPUs
    local jax_devices=$(python3 -c "import jax; print(len(jax.devices('gpu')))" 2>/dev/null)

    if [[ "$jax_devices" -gt 0 ]]; then
        log_info "✓ JAX can access GPU ($jax_devices devices)"
        clear_alert "jax-cuda-unavailable"
    else
        log_warning "JAX installed but no GPU devices found"
        update_alerts "medium" "jax-cuda-unavailable" \
            "JAX Cannot Access GPU" \
            "JAX cannot find GPU devices. Install JAX with CUDA support: pip install jax[cuda]"
    fi

    return 0
}

# Check for common GPU process issues
check_gpu_processes() {
    log_info "Checking GPU processes..."

    if ! command -v nvidia-smi &>/dev/null; then
        return 1
    fi

    # Get list of processes using GPU
    local gpu_procs=$(nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv,noheader 2>/dev/null)

    if [[ -n "$gpu_procs" ]]; then
        log_info "Active GPU processes:"
        echo "$gpu_procs" | while IFS=',' read -r pid name mem; do
            log_info "  PID $pid: $name (${mem})"
        done
    else
        log_debug "No active GPU processes"
    fi

    return 0
}

# Generate GPU environment summary
generate_gpu_summary() {
    log_info "Generating GPU environment summary..."

    local summary_file="$REPORTS_DIR/gpu-environment.txt"

    if ! command -v nvidia-smi &>/dev/null; then
        echo "NVIDIA driver not installed" > "$summary_file"
        return 1
    fi

    {
        echo "GPU Environment Summary"
        echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
        nvidia-smi
        echo ""
        echo "=== CUDA Toolkit ==="
        if command -v nvcc &>/dev/null; then
            nvcc --version
        else
            echo "nvcc not found"
        fi
        echo ""
        echo "=== Python GPU Frameworks ==="
        if python3 -c "import torch" 2>/dev/null; then
            echo "PyTorch: $(python3 -c 'import torch; print(torch.__version__)')"
            echo "  CUDA available: $(python3 -c 'import torch; print(torch.cuda.is_available())')"
        fi
        if python3 -c "import tensorflow" 2>/dev/null; then
            echo "TensorFlow: $(python3 -c 'import tensorflow as tf; print(tf.__version__)')"
            echo "  GPU devices: $(python3 -c 'import tensorflow as tf; print(len(tf.config.list_physical_devices(\"GPU\")))')"
        fi
        if python3 -c "import jax" 2>/dev/null; then
            echo "JAX: $(python3 -c 'import jax; print(jax.__version__)')"
            echo "  GPU devices: $(python3 -c 'import jax; print(len(jax.devices(\"gpu\")))')"
        fi
    } > "$summary_file"

    log_info "Summary saved to: $summary_file"
}

# Main execution
main() {
    log_info "==================== GPU ENVIRONMENT CHECK ===================="

    # Check if NVIDIA GPU is present
    if ! check_nvidia_hardware; then
        log_info "No NVIDIA GPU detected - skipping GPU checks"
        log_info "==================== GPU CHECK COMPLETE (NO GPU) ===================="
        return 0
    fi

    # Run all GPU checks
    check_nvidia_driver
    check_gpu_health
    check_cuda_toolkit
    check_pytorch_cuda
    check_tensorflow_cuda
    check_jax_cuda
    check_gpu_processes

    # Generate summary report
    generate_gpu_summary

    log_info "==================== GPU ENVIRONMENT CHECK COMPLETE ===================="
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
