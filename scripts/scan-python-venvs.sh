#!/bin/bash
# Scan for Python virtual environments on the system
# Reports location, last modified time, and installed packages

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

OUTPUT_FILE="$REPORTS_DIR/python-venvs.json"

log_info "Scanning for Python virtual environments..."

# Search paths (add more as needed)
SEARCH_PATHS=(
    "$HOME"
    "/opt"
    "/srv"
)

# Initialize output
cat > "$OUTPUT_FILE" <<'EOF'
{
  "scanned": "",
  "hostname": "",
  "venvs": []
}
EOF

# Update JSON header
python3 <<PYTHON
import json
from datetime import datetime, timezone

with open("$OUTPUT_FILE", 'r') as f:
    data = json.load(f)

data['scanned'] = datetime.now(timezone.utc).isoformat()
data['hostname'] = "$(hostname)"

with open("$OUTPUT_FILE", 'w') as f:
    json.dump(data, f, indent=2)
PYTHON

# Find venvs (look for pyvenv.cfg or bin/activate files)
# Exclude common system paths and .cache directories
VENV_PATHS=()

for search_path in "${SEARCH_PATHS[@]}"; do
    if [[ ! -d "$search_path" ]]; then
        continue
    fi

    log_info "Searching in: $search_path"

    # Find directories with pyvenv.cfg (standard venv marker)
    while IFS= read -r -d '' venv_cfg; do
        venv_dir=$(dirname "$venv_cfg")
        VENV_PATHS+=("$venv_dir")
    done < <(find "$search_path" -name "pyvenv.cfg" -type f \
        -not -path "*/.*" \
        -not -path "*/node_modules/*" \
        -not -path "*/site-packages/*" \
        -print0 2>/dev/null || true)
done

log_info "Found ${#VENV_PATHS[@]} virtual environments"

# Process each venv
for venv_path in "${VENV_PATHS[@]}"; do
    log_info "Processing: $venv_path"

    # Get venv metadata
    PYTHON_BIN="$venv_path/bin/python"
    ACTIVATE_SCRIPT="$venv_path/bin/activate"

    if [[ ! -f "$PYTHON_BIN" ]]; then
        log_warning "Skipping $venv_path - no Python binary found"
        continue
    fi

    # Get last modified time
    LAST_MODIFIED=$(stat -c %Y "$venv_path" 2>/dev/null || echo "0")

    # Get Python version
    PYTHON_VERSION=$("$PYTHON_BIN" --version 2>&1 | awk '{print $2}' || echo "unknown")

    # Get installed packages count
    PACKAGE_COUNT=$("$PYTHON_BIN" -m pip list --format=freeze 2>/dev/null | wc -l || echo "0")

    # Get list of installed packages (with versions)
    PACKAGES_JSON=$("$PYTHON_BIN" -m pip list --format=json 2>/dev/null || echo "[]")

    # Check for key ML packages
    HAS_PYTORCH=$("$PYTHON_BIN" -c "import torch; print('True')" 2>/dev/null || echo "False")
    HAS_TENSORFLOW=$("$PYTHON_BIN" -c "import tensorflow; print('True')" 2>/dev/null || echo "False")
    HAS_NUMPY=$("$PYTHON_BIN" -c "import numpy; print('True')" 2>/dev/null || echo "False")
    HAS_PANDAS=$("$PYTHON_BIN" -c "import pandas; print('True')" 2>/dev/null || echo "False")

    # Get venv size
    VENV_SIZE=$(du -sb "$venv_path" 2>/dev/null | awk '{print $1}' || echo "0")

    # Add to JSON
    python3 <<PYTHON
import json
from datetime import datetime

with open("$OUTPUT_FILE", 'r') as f:
    data = json.load(f)

venv_info = {
    "path": "$venv_path",
    "python_version": "$PYTHON_VERSION",
    "last_modified": $LAST_MODIFIED,
    "last_modified_date": datetime.fromtimestamp($LAST_MODIFIED).isoformat() if $LAST_MODIFIED > 0 else None,
    "package_count": $PACKAGE_COUNT,
    "size_bytes": $VENV_SIZE,
    "size_mb": round($VENV_SIZE / (1024 * 1024), 1),
    "packages": $PACKAGES_JSON,
    "has_pytorch": $HAS_PYTORCH,
    "has_tensorflow": $HAS_TENSORFLOW,
    "has_numpy": $HAS_NUMPY,
    "has_pandas": $HAS_PANDAS
}

data['venvs'].append(venv_info)

# Sort by last_modified (most recent first)
data['venvs'].sort(key=lambda x: x['last_modified'], reverse=True)

with open("$OUTPUT_FILE", 'w') as f:
    json.dump(data, f, indent=2)
PYTHON

    log_info "  → Python $PYTHON_VERSION, $PACKAGE_COUNT packages, $(( VENV_SIZE / 1024 / 1024 ))MB"
done

log_info "✓ Virtual environment data written to: $OUTPUT_FILE"
log_info "  Total venvs: ${#VENV_PATHS[@]}"
