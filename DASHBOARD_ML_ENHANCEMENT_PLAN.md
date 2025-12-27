# Dashboard ML Environment Enhancement Plan

## Executive Summary

Enhance the Claude Code Sysadmin Dashboard to provide comprehensive ML/AI development environment visibility, including GPU health, CUDA status, PyTorch/TensorFlow configuration, and Python virtual environment management.

---

## Current State Analysis

### Existing Dashboard Features
- System metrics (disk, memory, load, uptime)
- Active alerts with severity levels
- Pending approval requests
- Recent activity log
- System report viewer
- Monitored applications status

### Data Collection Scripts (✅ Created)
- `scripts/collect-ml-environment.sh` - GPU, CUDA, PyTorch, TensorFlow status
- `scripts/scan-python-venvs.sh` - Python virtual environment scanner

### API Endpoints (✅ Created)
- `/api/ml-environment` - Returns ML environment JSON
- `/api/python-venvs` - Returns venvs list JSON
- `/venvs` - Route for venvs browser page

---

## Design Goals

### 1. Main Dashboard Enhancements
**Goal**: Add ML environment health visibility to the main dashboard

**Components to Add:**
- **GPU Status Card** (in status-cards section)
  - GPU model name
  - Driver version
  - Temperature with color-coded status
  - Memory usage (used/total)
  - Utilization percentage
  - Visual indicators for health (🟢 healthy, 🟡 warning, 🔴 critical)

- **ML Framework Status Section** (new section after status cards)
  - CUDA toolkit status (installed version, driver API version)
  - PyTorch status (version, CUDA availability, compatibility)
  - TensorFlow status (version, GPU availability)
  - Visual status indicators for each framework

**Design Principles:**
- Match existing card styling (dashboard/static/style.css)
- Use color-coded status indicators
- Show concise, actionable information
- Link to detailed venvs page when relevant

### 2. Python Virtual Environments Browser Page
**Goal**: Comprehensive view of all Python venvs on the system

**Page URL**: `/venvs`

**Features:**

#### A. Summary Statistics (Top Section)
- Total venvs found
- Total disk space used
- Most recently modified venv
- Venvs with PyTorch/TensorFlow counts

#### B. Filtering & Search
- Search by path
- Filter by:
  - Has PyTorch
  - Has TensorFlow
  - Has NumPy/Pandas
  - Python version
  - Last modified (today, week, month, older)
  - Size (small <500MB, medium 500MB-2GB, large >2GB)
- Sort by:
  - Last modified (default, descending)
  - Size (ascending/descending)
  - Package count (ascending/descending)
  - Path (alphabetical)

#### C. Virtual Environment Cards
Each venv displayed as a card showing:
- **Header**: Path (shortened if too long)
- **Metadata**:
  - Python version
  - Package count
  - Size (MB/GB)
  - Last modified (relative time)
- **ML Frameworks** (badges):
  - 🔥 PyTorch
  - 🧠 TensorFlow
  - 🔢 NumPy
  - 🐼 Pandas
- **Actions**:
  - Expand/collapse to show package list
  - Copy activation command
  - View full package manifest

#### D. Package List (Expandable)
When expanded, show:
- Table of packages with versions
- Highlight ML/data science packages
- Search within packages
- Link to PyPI for package info

**Design Principles:**
- Responsive grid layout (1-3 columns depending on screen size)
- Fast filtering (client-side JavaScript)
- Collapsible details to avoid overwhelming UI
- Clear visual hierarchy

---

## Implementation Plan

### Phase 1: Main Dashboard ML Status Card (Priority 1)

**Files to Modify:**
1. `dashboard/templates/index.html`
   - Add GPU status card after existing status cards
   - Add ML Framework status section after status cards

2. `dashboard/static/style.css`
   - Styles for GPU card
   - Styles for ML framework status badges
   - Color-coded temperature indicators
   - Framework logos/icons using emojis or CSS

3. `dashboard/static/app.js`
   - Add `fetchMLEnvironment()` function
   - Update `refreshAll()` to include ML data
   - Add `updateMLStatus()` to populate GPU card
   - Add temperature color coding logic

**Detailed HTML Structure:**

```html
<!-- GPU Status Card (add to status-cards section) -->
<div class="card gpu-card" id="gpu-card">
    <h3>🎮 GPU</h3>
    <div class="gpu-info">
        <div class="gpu-model" id="gpu-model">--</div>
        <div class="gpu-metrics">
            <div class="gpu-metric">
                <span class="label">Temp:</span>
                <span class="value" id="gpu-temp">--°C</span>
            </div>
            <div class="gpu-metric">
                <span class="label">Memory:</span>
                <span class="value" id="gpu-memory">-- / --</span>
            </div>
            <div class="gpu-metric">
                <span class="label">Util:</span>
                <span class="value" id="gpu-util">--%</span>
            </div>
        </div>
        <div class="gpu-driver" id="gpu-driver">Driver: --</div>
    </div>
</div>

<!-- ML Framework Status Section (new section) -->
<section class="ml-frameworks-section">
    <h2>🤖 ML Environment</h2>
    <div class="frameworks-grid">
        <div class="framework-card" id="cuda-card">
            <div class="framework-icon">⚡</div>
            <div class="framework-info">
                <h4>CUDA</h4>
                <div class="framework-version" id="cuda-version">--</div>
                <div class="framework-status" id="cuda-status">--</div>
            </div>
        </div>
        <div class="framework-card" id="pytorch-card">
            <div class="framework-icon">🔥</div>
            <div class="framework-info">
                <h4>PyTorch</h4>
                <div class="framework-version" id="pytorch-version">--</div>
                <div class="framework-status" id="pytorch-status">--</div>
            </div>
        </div>
        <div class="framework-card" id="tensorflow-card">
            <div class="framework-icon">🧠</div>
            <div class="framework-info">
                <h4>TensorFlow</h4>
                <div class="framework-version" id="tensorflow-version">--</div>
                <div class="framework-status" id="tensorflow-status">--</div>
            </div>
        </div>
    </div>
    <div class="venvs-link">
        <a href="/venvs" class="btn-secondary">📦 Browse Virtual Environments →</a>
    </div>
</section>
```

**JavaScript Functions:**

```javascript
// Fetch ML environment data
async function fetchMLEnvironment() {
    try {
        const response = await fetch('/api/ml-environment');
        const data = await response.json();
        updateMLStatus(data);
    } catch (error) {
        console.error('Error fetching ML environment:', error);
    }
}

// Update ML status displays
function updateMLStatus(data) {
    // GPU Card
    if (data.gpu.present) {
        document.getElementById('gpu-model').textContent = data.gpu.name;
        document.getElementById('gpu-temp').textContent = `${data.gpu.temperature_c}°C`;
        document.getElementById('gpu-memory').textContent =
            `${data.gpu.memory_used_mb}MB / ${data.gpu.memory_total_mb}MB`;
        document.getElementById('gpu-util').textContent = `${data.gpu.utilization_percent}%`;
        document.getElementById('gpu-driver').textContent =
            `Driver: ${data.gpu.driver_version}`;

        // Color code temperature
        const tempCard = document.getElementById('gpu-card');
        if (data.gpu.temperature_c > 85) {
            tempCard.classList.add('warning');
        }
        if (data.gpu.temperature_c > 95) {
            tempCard.classList.add('critical');
        }
    } else {
        document.getElementById('gpu-model').textContent = 'No GPU Detected';
    }

    // CUDA Status
    updateFrameworkCard('cuda', data.cuda);

    // PyTorch Status
    updateFrameworkCard('pytorch', data.pytorch);

    // TensorFlow Status
    updateFrameworkCard('tensorflow', data.tensorflow);
}

function updateFrameworkCard(name, data) {
    const versionEl = document.getElementById(`${name}-version`);
    const statusEl = document.getElementById(`${name}-status`);
    const card = document.getElementById(`${name}-card`);

    if (data.installed) {
        versionEl.textContent = data.version;
        statusEl.textContent = data.status_message;
        statusEl.className = `framework-status status-${data.status}`;
    } else {
        versionEl.textContent = 'Not Installed';
        statusEl.textContent = '';
        card.classList.add('not-installed');
    }
}
```

**CSS Additions:**

```css
/* GPU Card */
.gpu-card {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    color: white;
}

.gpu-card.warning {
    background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
}

.gpu-card.critical {
    background: linear-gradient(135deg, #ff0844 0%, #ffb199 100%);
}

.gpu-info {
    display: flex;
    flex-direction: column;
    gap: 8px;
}

.gpu-model {
    font-size: 14px;
    font-weight: 600;
    margin-bottom: 8px;
}

.gpu-metrics {
    display: flex;
    gap: 16px;
}

.gpu-metric {
    display: flex;
    gap: 4px;
}

.gpu-driver {
    font-size: 12px;
    opacity: 0.8;
}

/* ML Frameworks Section */
.ml-frameworks-section {
    margin: 32px 0;
    padding: 24px;
    background: white;
    border-radius: 12px;
    box-shadow: 0 2px 8px rgba(0,0,0,0.1);
}

.frameworks-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 16px;
    margin-bottom: 20px;
}

.framework-card {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 16px;
    border: 2px solid #e2e8f0;
    border-radius: 8px;
    transition: all 0.2s;
}

.framework-card:hover {
    border-color: #667eea;
    box-shadow: 0 4px 12px rgba(102, 126, 234, 0.2);
}

.framework-card.not-installed {
    opacity: 0.5;
    border-style: dashed;
}

.framework-icon {
    font-size: 32px;
}

.framework-info h4 {
    margin: 0 0 4px 0;
    font-size: 16px;
}

.framework-version {
    font-size: 14px;
    color: #64748b;
}

.framework-status {
    font-size: 12px;
    margin-top: 4px;
}

.status-healthy {
    color: #22c55e;
}

.status-warning {
    color: #f59e0b;
}

.status-not_installed {
    color: #94a3b8;
}

.venvs-link {
    text-align: center;
    margin-top: 20px;
}

.btn-secondary {
    display: inline-block;
    padding: 12px 24px;
    background: #f1f5f9;
    color: #334155;
    text-decoration: none;
    border-radius: 8px;
    font-weight: 500;
    transition: all 0.2s;
}

.btn-secondary:hover {
    background: #e2e8f0;
}
```

### Phase 2: Virtual Environments Browser Page (Priority 2)

**Files to Create:**
1. `dashboard/templates/venvs.html` - New page template

**Files to Modify:**
1. `dashboard/static/style.css` - Add venvs page styles
2. `dashboard/static/app.js` - Add venvs.js OR create separate file

**Page Structure:**

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Python Virtual Environments - {{ hostname }}</title>
    <link rel="stylesheet" href="{{ url_for('static', filename='style.css') }}">
</head>
<body>
    <div class="container venvs-page">
        <header>
            <h1>📦 Python Virtual Environments</h1>
            <div class="header-actions">
                <a href="/" class="btn-secondary">← Back to Dashboard</a>
                <button onclick="refreshVenvs()" class="btn-action">🔄 Refresh</button>
            </div>
        </header>

        <!-- Summary Stats -->
        <section class="venvs-summary">
            <div class="stat-card">
                <div class="stat-value" id="total-venvs">--</div>
                <div class="stat-label">Total Virtual Environments</div>
            </div>
            <div class="stat-card">
                <div class="stat-value" id="total-size">--</div>
                <div class="stat-label">Total Disk Space</div>
            </div>
            <div class="stat-card">
                <div class="stat-value" id="pytorch-count">--</div>
                <div class="stat-label">With PyTorch</div>
            </div>
            <div class="stat-card">
                <div class="stat-value" id="tensorflow-count">--</div>
                <div class="stat-label">With TensorFlow</div>
            </div>
        </section>

        <!-- Filters & Search -->
        <section class="venvs-controls">
            <div class="search-box">
                <input type="text" id="venv-search" placeholder="Search by path..."
                       oninput="filterVenvs()">
            </div>

            <div class="filters">
                <div class="filter-group">
                    <label>Frameworks:</label>
                    <label class="checkbox-label">
                        <input type="checkbox" id="filter-pytorch" onchange="filterVenvs()">
                        🔥 PyTorch
                    </label>
                    <label class="checkbox-label">
                        <input type="checkbox" id="filter-tensorflow" onchange="filterVenvs()">
                        🧠 TensorFlow
                    </label>
                    <label class="checkbox-label">
                        <input type="checkbox" id="filter-numpy" onchange="filterVenvs()">
                        🔢 NumPy
                    </label>
                </div>

                <div class="filter-group">
                    <label>Sort by:</label>
                    <select id="sort-select" onchange="sortVenvs()">
                        <option value="modified-desc">Last Modified (Newest)</option>
                        <option value="modified-asc">Last Modified (Oldest)</option>
                        <option value="size-desc">Size (Largest)</option>
                        <option value="size-asc">Size (Smallest)</option>
                        <option value="packages-desc">Most Packages</option>
                        <option value="packages-asc">Least Packages</option>
                    </select>
                </div>
            </div>
        </section>

        <!-- Virtual Environments Grid -->
        <section class="venvs-grid" id="venvs-grid">
            <!-- Populated by JavaScript -->
        </section>

        <footer>
            <p>Last scanned: <span id="scan-time">--</span></p>
        </footer>
    </div>

    <script src="{{ url_for('static', filename='app.js') }}"></script>
    <script>
        // Venvs-specific JavaScript
        let venvsData = [];

        async function fetchVenvs() {
            try {
                const response = await fetch('/api/python-venvs');
                const data = await response.json();
                venvsData = data.venvs;
                updateSummary(data);
                renderVenvs(venvsData);
            } catch (error) {
                console.error('Error fetching venvs:', error);
            }
        }

        function updateSummary(data) {
            document.getElementById('total-venvs').textContent = data.venvs.length;
            const totalSize = data.venvs.reduce((sum, v) => sum + v.size_mb, 0);
            document.getElementById('total-size').textContent =
                totalSize > 1024 ? `${(totalSize/1024).toFixed(1)} GB` : `${totalSize.toFixed(0)} MB`;
            document.getElementById('pytorch-count').textContent =
                data.venvs.filter(v => v.has_pytorch).length;
            document.getElementById('tensorflow-count').textContent =
                data.venvs.filter(v => v.has_tensorflow).length;
            document.getElementById('scan-time').textContent =
                new Date(data.scanned).toLocaleString();
        }

        function renderVenvs(venvs) {
            const grid = document.getElementById('venvs-grid');
            grid.innerHTML = venvs.map(venv => createVenvCard(venv)).join('');
        }

        function createVenvCard(venv) {
            const frameworks = [];
            if (venv.has_pytorch) frameworks.push('<span class="badge pytorch">🔥 PyTorch</span>');
            if (venv.has_tensorflow) frameworks.push('<span class="badge tensorflow">🧠 TensorFlow</span>');
            if (venv.has_numpy) frameworks.push('<span class="badge numpy">🔢 NumPy</span>');
            if (venv.has_pandas) frameworks.push('<span class="badge pandas">🐼 Pandas</span>');

            const relativeTime = getRelativeTime(new Date(venv.last_modified_date));

            return `
                <div class="venv-card" data-path="${venv.path}">
                    <div class="venv-header">
                        <div class="venv-path" title="${venv.path}">${shortenPath(venv.path)}</div>
                        <button onclick="toggleDetails('${venv.path}')" class="btn-expand">▼</button>
                    </div>
                    <div class="venv-meta">
                        <span>🐍 ${venv.python_version}</span>
                        <span>📦 ${venv.package_count} packages</span>
                        <span>💾 ${venv.size_mb} MB</span>
                        <span>🕒 ${relativeTime}</span>
                    </div>
                    <div class="venv-frameworks">
                        ${frameworks.join(' ')}
                    </div>
                    <div class="venv-actions">
                        <button onclick="copyActivateCommand('${venv.path}')" class="btn-sm">
                            📋 Copy Activate
                        </button>
                    </div>
                    <div class="venv-details" id="details-${btoa(venv.path)}" style="display: none;">
                        <h4>Installed Packages (${venv.package_count})</h4>
                        <div class="packages-list">
                            ${venv.packages.map(pkg =>
                                `<div class="package-item">${pkg.name} <span class="version">${pkg.version}</span></div>`
                            ).join('')}
                        </div>
                    </div>
                </div>
            `;
        }

        function shortenPath(path) {
            const maxLength = 50;
            if (path.length <= maxLength) return path;
            return '...' + path.slice(-(maxLength - 3));
        }

        function getRelativeTime(date) {
            const now = new Date();
            const diff = Math.floor((now - date) / 1000); // seconds

            if (diff < 60) return 'just now';
            if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
            if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
            if (diff < 604800) return `${Math.floor(diff / 86400)}d ago`;
            if (diff < 2592000) return `${Math.floor(diff / 604800)}w ago`;
            return `${Math.floor(diff / 2592000)}mo ago`;
        }

        function toggleDetails(path) {
            const detailsId = 'details-' + btoa(path);
            const details = document.getElementById(detailsId);
            details.style.display = details.style.display === 'none' ? 'block' : 'none';
        }

        function copyActivateCommand(path) {
            const command = `source ${path}/bin/activate`;
            navigator.clipboard.writeText(command).then(() => {
                alert('Activation command copied to clipboard!');
            });
        }

        function filterVenvs() {
            const searchTerm = document.getElementById('venv-search').value.toLowerCase();
            const filterPyTorch = document.getElementById('filter-pytorch').checked;
            const filterTensorFlow = document.getElementById('filter-tensorflow').checked;
            const filterNumPy = document.getElementById('filter-numpy').checked;

            let filtered = venvsData.filter(venv => {
                const matchesSearch = venv.path.toLowerCase().includes(searchTerm);
                const matchesPyTorch = !filterPyTorch || venv.has_pytorch;
                const matchesTensorFlow = !filterTensorFlow || venv.has_tensorflow;
                const matchesNumPy = !filterNumPy || venv.has_numpy;

                return matchesSearch && matchesPyTorch && matchesTensorFlow && matchesNumPy;
            });

            renderVenvs(filtered);
        }

        function sortVenvs() {
            const sortBy = document.getElementById('sort-select').value;
            let sorted = [...venvsData];

            switch(sortBy) {
                case 'modified-desc':
                    sorted.sort((a, b) => b.last_modified - a.last_modified);
                    break;
                case 'modified-asc':
                    sorted.sort((a, b) => a.last_modified - b.last_modified);
                    break;
                case 'size-desc':
                    sorted.sort((a, b) => b.size_mb - a.size_mb);
                    break;
                case 'size-asc':
                    sorted.sort((a, b) => a.size_mb - b.size_mb);
                    break;
                case 'packages-desc':
                    sorted.sort((a, b) => b.package_count - a.package_count);
                    break;
                case 'packages-asc':
                    sorted.sort((a, b) => a.package_count - b.package_count);
                    break;
            }

            renderVenvs(sorted);
        }

        function refreshVenvs() {
            fetchVenvs();
        }

        // Load data on page load
        document.addEventListener('DOMContentLoaded', fetchVenvs);
    </script>
</body>
</html>
```

**CSS for Venvs Page:**

```css
/* Venvs Page Styles */
.venvs-page {
    max-width: 1400px;
}

.header-actions {
    display: flex;
    gap: 12px;
    align-items: center;
}

.venvs-summary {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 16px;
    margin: 24px 0;
}

.stat-card {
    background: white;
    padding: 20px;
    border-radius: 12px;
    text-align: center;
    box-shadow: 0 2px 8px rgba(0,0,0,0.1);
}

.stat-value {
    font-size: 32px;
    font-weight: 700;
    color: #667eea;
    margin-bottom: 8px;
}

.stat-label {
    font-size: 14px;
    color: #64748b;
}

.venvs-controls {
    background: white;
    padding: 20px;
    border-radius: 12px;
    margin-bottom: 24px;
    box-shadow: 0 2px 8px rgba(0,0,0,0.1);
}

.search-box {
    margin-bottom: 16px;
}

.search-box input {
    width: 100%;
    padding: 12px;
    border: 2px solid #e2e8f0;
    border-radius: 8px;
    font-size: 16px;
}

.filters {
    display: flex;
    gap: 24px;
    flex-wrap: wrap;
}

.filter-group {
    display: flex;
    gap: 12px;
    align-items: center;
}

.checkbox-label {
    display: flex;
    align-items: center;
    gap: 6px;
    cursor: pointer;
}

.venvs-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(350px, 1fr));
    gap: 20px;
    margin-bottom: 40px;
}

.venv-card {
    background: white;
    border: 2px solid #e2e8f0;
    border-radius: 12px;
    padding: 20px;
    transition: all 0.2s;
}

.venv-card:hover {
    border-color: #667eea;
    box-shadow: 0 4px 16px rgba(102, 126, 234, 0.2);
}

.venv-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    margin-bottom: 12px;
}

.venv-path {
    font-weight: 600;
    font-size: 14px;
    color: #1e293b;
    word-break: break-all;
    flex: 1;
}

.btn-expand {
    background: none;
    border: none;
    font-size: 16px;
    cursor: pointer;
    padding: 4px;
}

.venv-meta {
    display: flex;
    flex-wrap: wrap;
    gap: 12px;
    font-size: 12px;
    color: #64748b;
    margin-bottom: 12px;
}

.venv-frameworks {
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
    margin-bottom: 12px;
}

.badge {
    display: inline-block;
    padding: 4px 8px;
    border-radius: 4px;
    font-size: 12px;
    font-weight: 500;
}

.badge.pytorch {
    background: #fff5f5;
    color: #c53030;
}

.badge.tensorflow {
    background: #fffaf0;
    color: #dd6b20;
}

.badge.numpy {
    background: #ebf8ff;
    color: #2c5282;
}

.badge.pandas {
    background: #f0fff4;
    color: #276749;
}

.venv-actions {
    display: flex;
    gap: 8px;
}

.btn-sm {
    padding: 6px 12px;
    font-size: 12px;
    background: #f1f5f9;
    border: none;
    border-radius: 6px;
    cursor: pointer;
    transition: all 0.2s;
}

.btn-sm:hover {
    background: #e2e8f0;
}

.venv-details {
    margin-top: 16px;
    padding-top: 16px;
    border-top: 1px solid #e2e8f0;
}

.venv-details h4 {
    margin: 0 0 12px 0;
    font-size: 14px;
    color: #475569;
}

.packages-list {
    max-height: 300px;
    overflow-y: auto;
    background: #f8fafc;
    padding: 12px;
    border-radius: 6px;
}

.package-item {
    display: flex;
    justify-content: space-between;
    padding: 4px 0;
    font-size: 12px;
    font-family: 'Courier New', monospace;
}

.package-item .version {
    color: #64748b;
}
```

### Phase 3: Integration & Automation (Priority 3)

**Files to Modify:**
1. `scripts/hourly-check.sh` or `scripts/daily-maintenance.sh`
   - Add calls to `collect-ml-environment.sh`
   - Add calls to `scan-python-venvs.sh` (daily only, not hourly)

2. `claude-admin/prompts/daily.txt`
   - Update prompt to include ML environment checks

**Integration Points:**

```bash
# In scripts/daily-maintenance.sh (after other checks)

# ML Environment Check
log_info "Checking ML/AI environment..."
if [[ -f "$SCRIPT_DIR/collect-ml-environment.sh" ]]; then
    "$SCRIPT_DIR/collect-ml-environment.sh"
fi

# Scan Python Virtual Environments (skip if recently scanned)
VENVS_FILE="$REPORTS_DIR/python-venvs.json"
if [[ ! -f "$VENVS_FILE" ]] || [[ $(find "$VENVS_FILE" -mmin +360 2>/dev/null) ]]; then
    log_info "Scanning Python virtual environments..."
    if [[ -f "$SCRIPT_DIR/scan-python-venvs.sh" ]]; then
        "$SCRIPT_DIR/scan-python-venvs.sh"
    fi
fi
```

---

## Testing Plan

### Unit Testing
1. **Data Collection Scripts**
   - ✅ Verify `collect-ml-environment.sh` produces valid JSON
   - ✅ Verify `scan-python-venvs.sh` finds all venvs
   - Test error handling (missing nvidia-smi, broken venvs)

2. **API Endpoints**
   - Test `/api/ml-environment` returns correct data
   - Test `/api/python-venvs` returns correct data
   - Test error handling for missing files

### Integration Testing
1. **Dashboard Main Page**
   - Verify GPU card displays correctly
   - Verify ML framework status shows correctly
   - Test with/without GPU present
   - Test temperature color coding

2. **Venvs Page**
   - Verify all venvs load and display
   - Test search functionality
   - Test filtering (PyTorch, TensorFlow, NumPy)
   - Test sorting (all options)
   - Test expand/collapse details
   - Test copy activation command

3. **Cross-browser Testing**
   - Chrome/Chromium
   - Firefox
   - Safari (if available)

### Performance Testing
- Verify venv scanning completes in reasonable time (<2 minutes for ~20 venvs)
- Verify dashboard loads quickly with ML data
- Verify venvs page handles 50+ venvs without lag

---

## Deployment Steps

1. **Backup Current Dashboard**
   ```bash
   cp -r dashboard/ dashboard-backup-$(date +%Y%m%d)
   ```

2. **Deploy Code Changes**
   - Update templates (index.html, create venvs.html)
   - Update static files (app.js, style.css)
   - Update app.py (already done)

3. **Run Initial Data Collection**
   ```bash
   ./scripts/collect-ml-environment.sh
   ./scripts/scan-python-venvs.sh
   ```

4. **Restart Dashboard Service**
   ```bash
   sudo systemctl restart sysadmin-dashboard.service
   ```

5. **Verify Deployment**
   - Check http://localhost:5050 loads
   - Check GPU card displays
   - Check ML frameworks show
   - Navigate to /venvs page
   - Verify all functionality works

6. **Integrate into Maintenance Schedule**
   - Update daily-maintenance.sh to call scripts
   - Test scheduled execution

---

## Success Metrics

- ✅ GPU status visible on main dashboard
- ✅ ML framework status (CUDA, PyTorch, TensorFlow) visible
- ✅ Link to venvs page from main dashboard
- ✅ Venvs page lists all virtual environments
- ✅ Search and filtering work correctly
- ✅ Package lists expandable and readable
- ✅ Data collection integrated into maintenance scripts
- ✅ Dashboard loads in <2 seconds
- ✅ No errors in browser console
- ✅ Mobile responsive design maintained

---

## Future Enhancements (Out of Scope)

- Venv cleanup recommendations (unused/old venvs)
- Package vulnerability scanning integration
- Conda environment support
- Docker container Python environment detection
- PyPI package version comparison
- Venv dependency graph visualization
- One-click venv cleanup actions
- Jupyter kernel detection and management

---

## Timeline Estimate

- Phase 1 (Main Dashboard): 60-90 minutes
- Phase 2 (Venvs Page): 90-120 minutes
- Phase 3 (Integration): 20-30 minutes
- Testing & Debugging: 30-60 minutes

**Total: ~3-5 hours** for comprehensive implementation

---

## Risk Mitigation

- **Backup before changes**: Copy dashboard directory before modifications
- **Incremental deployment**: Deploy Phase 1, test, then Phase 2
- **Rollback plan**: Keep dashboard-backup directory, easy to revert
- **Service monitoring**: Check systemctl status after restart
- **Error handling**: All JavaScript wrapped in try/catch blocks
- **Graceful degradation**: Dashboard still works if ML data missing

---

This plan provides a clear roadmap for enhancing the dashboard with comprehensive ML environment visibility while maintaining code quality, user experience, and system stability.
