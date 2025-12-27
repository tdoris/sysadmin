// Sysadmin Dashboard JavaScript

// Auto-refresh interval (30 seconds)
const REFRESH_INTERVAL = 30000;
let refreshTimer = null;

// Initialize dashboard
document.addEventListener('DOMContentLoaded', function() {
    console.log('Dashboard loaded');
    refreshAll();
    startAutoRefresh();
});

// Start auto-refresh
function startAutoRefresh() {
    if (refreshTimer) {
        clearInterval(refreshTimer);
    }
    refreshTimer = setInterval(refreshAll, REFRESH_INTERVAL);
}

// Refresh all data
function refreshAll() {
    console.log('Refreshing dashboard...');
    loadSystemStatus();
    loadMLEnvironment();
    loadPendingApprovals();
    loadAlerts();
    loadActivity();
    loadRecommendations();
    loadApps();
    loadReport();
    updateLastUpdate();
}

// Update last update timestamp
function updateLastUpdate() {
    const now = new Date();
    document.getElementById('last-update').textContent = now.toLocaleTimeString();
}

// Load system status
async function loadSystemStatus() {
    try {
        const response = await fetch('/api/status');
        const data = await response.json();

        // Update metrics
        document.getElementById('disk-usage').textContent = data.disk_usage || '--';
        document.getElementById('memory-usage').textContent = data.memory_usage || '--';
        document.getElementById('load-avg').textContent = data.load_avg.toFixed(2) || '--';
        document.getElementById('uptime').textContent = data.uptime || '--';

        // Update card colors based on thresholds
        updateCardStatus('disk-card', data.disk_usage, 80, 90);
        updateCardStatus('memory-card', data.memory_usage, 80, 90);

    } catch (error) {
        console.error('Error loading system status:', error);
    }
}

// Update card status colors
function updateCardStatus(cardId, value, warningThreshold, dangerThreshold) {
    const card = document.getElementById(cardId);
    card.classList.remove('status-good', 'status-warning', 'status-danger');

    if (value >= dangerThreshold) {
        card.classList.add('status-danger');
    } else if (value >= warningThreshold) {
        card.classList.add('status-warning');
    } else {
        card.classList.add('status-good');
    }
}

// Load alerts
async function loadAlerts() {
    try {
        const response = await fetch('/api/alerts');
        const data = await response.json();

        // Update badge counts
        document.getElementById('critical-count').textContent = `Critical: ${data.critical.length}`;
        document.getElementById('high-count').textContent = `High: ${data.high.length}`;
        document.getElementById('medium-count').textContent = `Medium: ${data.medium.length}`;

        // Render alerts
        const container = document.getElementById('alerts-container');
        container.innerHTML = '';

        if (data.total === 0) {
            container.innerHTML = '<p style="color: var(--text-secondary);">No active alerts - system is healthy! ✓</p>';
            return;
        }

        // Render critical alerts
        data.critical.forEach(alert => renderAlert(container, alert, 'critical'));

        // Render high priority alerts
        data.high.forEach(alert => renderAlert(container, alert, 'high'));

        // Render medium priority alerts
        data.medium.forEach(alert => renderAlert(container, alert, 'medium'));

    } catch (error) {
        console.error('Error loading alerts:', error);
    }
}

// Render a single alert
function renderAlert(container, alert, severity) {
    const div = document.createElement('div');
    div.className = `alert-item ${severity}`;
    div.innerHTML = `
        <h4>${alert.title}</h4>
        <p>${alert.description}</p>
        <div class="alert-meta">
            Detected: ${alert.detected || 'Unknown'} |
            Status: ${alert.status || 'open'} |
            Severity: ${severity.toUpperCase()}
        </div>
    `;
    container.appendChild(div);
}

// Load pending approvals
async function loadPendingApprovals() {
    try {
        const response = await fetch('/api/pending-approvals');
        const data = await response.json();

        const section = document.getElementById('approvals-section');
        const container = document.getElementById('approvals-container');

        if (!data.items || data.items.length === 0) {
            section.style.display = 'none';
            return;
        }

        section.style.display = 'block';
        container.innerHTML = '';

        // Render each pending approval
        data.items.forEach(approval => renderApproval(container, approval));

    } catch (error) {
        console.error('Error loading pending approvals:', error);
    }
}

// Render a single approval request
function renderApproval(container, approval) {
    const div = document.createElement('div');
    div.className = `approval-card ${approval.severity}`;
    div.id = `approval-${approval.id}`;

    const riskBadge = getRiskBadge(approval.risk_level);
    const reversibleBadge = approval.reversible ?
        '<span class="badge badge-success">Reversible</span>' :
        '<span class="badge badge-warning">Not reversible</span>';

    div.innerHTML = `
        <div class="approval-header">
            <h3>${approval.title}</h3>
            <div class="approval-badges">
                <span class="badge badge-${approval.severity}">${approval.severity.toUpperCase()}</span>
                ${riskBadge}
                ${reversibleBadge}
            </div>
        </div>
        <div class="approval-body">
            <p><strong>Description:</strong> ${approval.description}</p>
            ${approval.recommendation ? `<p><strong>Recommendation:</strong> ${approval.recommendation}</p>` : ''}
            <p><strong>Action to be taken:</strong> <code>${approval.action}</code></p>
            ${approval.estimated_impact ? `<p><strong>Expected impact:</strong> ${approval.estimated_impact}</p>` : ''}
            <p class="approval-meta">
                Created: ${new Date(approval.created).toLocaleString()} |
                Category: ${approval.category} |
                Type: ${approval.action_type}
            </p>
        </div>
        <div class="approval-footer">
            <div class="approval-comment">
                <textarea id="comment-${approval.id}" placeholder="Optional: Add instructions or comments for Claude Code..."></textarea>
            </div>
            <div class="approval-actions">
                <button onclick="approveAction('${approval.id}')" class="btn-approve">
                    ✓ Approve
                </button>
                <button onclick="denyAction('${approval.id}')" class="btn-deny">
                    ✗ Deny
                </button>
            </div>
        </div>
    `;

    container.appendChild(div);
}

// Get risk level badge
function getRiskBadge(riskLevel) {
    const colors = {
        'critical': 'danger',
        'high': 'danger',
        'medium': 'warning',
        'low': 'info',
        'minimal': 'success'
    };
    const color = colors[riskLevel] || 'info';
    return `<span class="badge badge-${color}">Risk: ${riskLevel}</span>`;
}

// Approve an action
async function approveAction(approvalId) {
    const commentEl = document.getElementById(`comment-${approvalId}`);
    const comment = commentEl ? commentEl.value.trim() : '';
    const approvalCard = document.getElementById(`approval-${approvalId}`);

    // Show processing state
    approvalCard.classList.add('processing');

    try {
        const response = await fetch(`/api/approve/${approvalId}`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ comment })
        });

        const data = await response.json();

        if (data.success) {
            // Show success message
            approvalCard.innerHTML = `
                <div class="approval-success">
                    <h3>✓ Approved</h3>
                    <p>${data.message}</p>
                    <p class="success-note">Claude Code is executing this action now. Check the Activity tab for progress.</p>
                </div>
            `;

            // Remove after a delay
            setTimeout(() => {
                approvalCard.style.opacity = '0';
                setTimeout(() => {
                    approvalCard.remove();
                    loadPendingApprovals(); // Refresh to check if section should be hidden
                }, 500);
            }, 3000);

            // Refresh activity log
            setTimeout(() => {
                loadActivity();
            }, 2000);

        } else {
            approvalCard.classList.remove('processing');
            alert(`Error: ${data.error}`);
        }

    } catch (error) {
        console.error('Error approving action:', error);
        approvalCard.classList.remove('processing');
        alert(`Error: ${error.message}`);
    }
}

// Deny an action
async function denyAction(approvalId) {
    const commentEl = document.getElementById(`comment-${approvalId}`);
    const comment = commentEl ? commentEl.value.trim() : '';
    const approvalCard = document.getElementById(`approval-${approvalId}`);

    if (!comment) {
        alert('Please provide a reason for denying this action.');
        commentEl.focus();
        return;
    }

    // Show processing state
    approvalCard.classList.add('processing');

    try {
        const response = await fetch(`/api/deny/${approvalId}`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ comment })
        });

        const data = await response.json();

        if (data.success) {
            // Show denied message
            approvalCard.innerHTML = `
                <div class="approval-denied">
                    <h3>✗ Denied</h3>
                    <p>${data.message}</p>
                    <p class="denied-note">Reason: ${comment}</p>
                </div>
            `;

            // Remove after a delay
            setTimeout(() => {
                approvalCard.style.opacity = '0';
                setTimeout(() => {
                    approvalCard.remove();
                    loadPendingApprovals(); // Refresh to check if section should be hidden
                }, 500);
            }, 3000);

        } else {
            approvalCard.classList.remove('processing');
            alert(`Error: ${data.error}`);
        }

    } catch (error) {
        console.error('Error denying action:', error);
        approvalCard.classList.remove('processing');
        alert(`Error: ${error.message}`);
    }
}

// Load recent activity
async function loadActivity() {
    try {
        const response = await fetch('/api/activity?lines=100');
        const data = await response.json();

        const container = document.getElementById('activity-log');
        container.innerHTML = '';

        if (!data.activity || data.activity.length === 0) {
            container.innerHTML = '<p style="color: var(--text-secondary);">No recent activity</p>';
            return;
        }

        data.activity.forEach(line => {
            if (line.trim()) {
                const div = document.createElement('div');
                div.className = 'log-line';
                div.textContent = line;

                // Color code log lines
                if (line.includes('CRITICAL') || line.includes('ERROR')) {
                    div.style.color = 'var(--danger)';
                } else if (line.includes('WARNING')) {
                    div.style.color = 'var(--warning)';
                } else if (line.includes('INFO') || line.includes('✓')) {
                    div.style.color = 'var(--success)';
                }

                container.appendChild(div);
            }
        });

        // Scroll to bottom
        container.scrollTop = container.scrollHeight;

    } catch (error) {
        console.error('Error loading activity:', error);
    }
}

// Load recommendations
async function loadRecommendations() {
    try {
        const response = await fetch('/api/recommendations');
        const data = await response.json();

        const container = document.getElementById('recommendations-container');
        container.innerHTML = '';

        const hasRecommendations =
            (data.critical && data.critical.length > 0) ||
            (data.high && data.high.length > 0) ||
            (data.medium && data.medium.length > 0) ||
            (data.optimizations && data.optimizations.length > 0);

        if (!hasRecommendations) {
            container.innerHTML = '<p style="color: var(--text-secondary);">No recommendations yet. Run daily maintenance to generate recommendations.</p>';
            return;
        }

        // Render critical recommendations
        if (data.critical && data.critical.length > 0) {
            const section = document.createElement('div');
            section.innerHTML = '<h4 style="color: var(--critical); margin-bottom: 10px;">Critical</h4>';
            data.critical.forEach(rec => renderRecommendation(section, rec, 'critical'));
            container.appendChild(section);
        }

        // Render high priority recommendations
        if (data.high && data.high.length > 0) {
            const section = document.createElement('div');
            section.innerHTML = '<h4 style="color: var(--high); margin-top: 20px; margin-bottom: 10px;">High Priority</h4>';
            data.high.forEach(rec => renderRecommendation(section, rec, 'high'));
            container.appendChild(section);
        }

        // Render medium priority recommendations
        if (data.medium && data.medium.length > 0) {
            const section = document.createElement('div');
            section.innerHTML = '<h4 style="color: var(--medium); margin-top: 20px; margin-bottom: 10px;">Medium Priority</h4>';
            data.medium.forEach(rec => renderRecommendation(section, rec, 'medium'));
            container.appendChild(section);
        }

        // Render optimizations
        if (data.optimizations && data.optimizations.length > 0) {
            const section = document.createElement('div');
            section.innerHTML = '<h4 style="color: var(--accent); margin-top: 20px; margin-bottom: 10px;">Optimizations</h4>';
            data.optimizations.forEach(rec => renderRecommendation(section, rec, 'medium'));
            container.appendChild(section);
        }

    } catch (error) {
        console.error('Error loading recommendations:', error);
    }
}

// Render a single recommendation
function renderRecommendation(container, rec, severity) {
    const div = document.createElement('div');
    div.className = `recommendation-item ${severity}`;
    div.innerHTML = `
        <h4>${rec.title}</h4>
        <p>${rec.description}</p>
        ${rec.action ? `<div class="action"><strong>Action:</strong> ${rec.action}</div>` : ''}
    `;
    container.appendChild(div);
}

// Load monitored apps
async function loadApps() {
    try {
        const response = await fetch('/api/apps');
        const data = await response.json();

        const container = document.getElementById('apps-container');
        container.innerHTML = '';

        if (Object.keys(data).length === 0) {
            container.innerHTML = `
                <p style="color: var(--text-secondary);">
                    No applications configured for monitoring.<br>
                    Edit <code>config/monitored-apps.yaml</code> to add applications.
                </p>
            `;
            return;
        }

        const grid = document.createElement('div');
        grid.className = 'apps-grid';

        for (const [name, config] of Object.entries(data)) {
            const card = document.createElement('div');
            card.className = 'app-card';

            let details = '';
            if (config.type === 'systemd') {
                details = `<div class="app-detail">Service: ${config.service_name}</div>`;
            } else if (config.type === 'docker') {
                details = `<div class="app-detail">Container: ${config.container_name}</div>`;
            } else if (config.type === 'cron') {
                details = `<div class="app-detail">Schedule: ${config.cron_pattern || 'N/A'}</div>`;
            }

            if (config.health_check && config.health_check.url) {
                details += `<div class="app-detail">Health: ${config.health_check.url}</div>`;
            }

            card.innerHTML = `
                <h4>${name}</h4>
                <span class="app-type">${config.type}</span>
                ${details}
                <div class="app-detail">
                    Auto-restart: ${config.auto_restart ? '✓ Yes' : '✗ No'} |
                    Critical: ${config.critical ? '✓ Yes' : '✗ No'}
                </div>
            `;

            grid.appendChild(card);
        }

        container.appendChild(grid);

    } catch (error) {
        console.error('Error loading apps:', error);
    }
}

// Load system report
async function loadReport() {
    try {
        const response = await fetch('/api/report');
        const data = await response.json();

        const container = document.getElementById('report-content');
        const timestamp = document.getElementById('report-timestamp');

        if (data.timestamp) {
            const date = new Date(data.timestamp);
            timestamp.textContent = `Generated: ${date.toLocaleString()}`;
        } else {
            timestamp.textContent = '';
        }

        container.innerHTML = data.html || '<p style="color: var(--text-secondary);">No report available</p>';

    } catch (error) {
        console.error('Error loading report:', error);
    }
}

// Tab switching
function showTab(tabName) {
    // Hide all tabs
    document.querySelectorAll('.tab-content').forEach(tab => {
        tab.classList.remove('active');
    });

    document.querySelectorAll('.tab').forEach(tab => {
        tab.classList.remove('active');
    });

    // Show selected tab
    document.getElementById(`${tabName}-tab`).classList.add('active');
    event.target.classList.add('active');
}

// Trigger maintenance job
async function triggerJob(jobType) {
    const statusEl = document.getElementById('action-status');
    statusEl.className = '';
    statusEl.textContent = `Starting ${jobType} maintenance...`;
    statusEl.classList.add('success');
    statusEl.style.display = 'block';

    try {
        const response = await fetch(`/api/trigger/${jobType}`, {
            method: 'POST'
        });

        const data = await response.json();

        if (data.success) {
            statusEl.textContent = `✓ ${data.message} - Claude Code is processing (may take 1-2 minutes). Check the Activity tab for progress.`;
            statusEl.classList.add('success');

            // Start polling for updates
            let pollCount = 0;
            const pollInterval = setInterval(() => {
                loadActivity();
                pollCount++;

                // Stop polling after 3 minutes
                if (pollCount > 36) {
                    clearInterval(pollInterval);
                    statusEl.textContent = `✓ Job started. Refresh Activity tab to see latest results.`;
                }
            }, 5000); // Poll every 5 seconds

            // Initial refresh after 3 seconds
            setTimeout(() => {
                loadActivity();
            }, 3000);

            // Hide message after 3 minutes
            setTimeout(() => {
                clearInterval(pollInterval);
                statusEl.style.display = 'none';
            }, 180000);

        } else {
            statusEl.textContent = `✗ Error: ${data.error}`;
            statusEl.classList.remove('success');
            statusEl.classList.add('error');

            setTimeout(() => {
                statusEl.style.display = 'none';
            }, 10000);
        }

    } catch (error) {
        console.error('Error triggering job:', error);
        statusEl.textContent = `✗ Error: ${error.message}`;
        statusEl.classList.remove('success');
        statusEl.classList.add('error');

        setTimeout(() => {
            statusEl.style.display = 'none';
        }, 10000);
    }
}

// Copy command to clipboard
function copyCommand() {
    const command = document.getElementById('claude-command').textContent;
    navigator.clipboard.writeText(command).then(() => {
        const btn = event.target;
        const originalText = btn.textContent;
        btn.textContent = 'Copied!';
        setTimeout(() => {
            btn.textContent = originalText;
        }, 2000);
    }).catch(err => {
        console.error('Failed to copy:', err);
    });
}

// ========================================
// ML Environment Functions
// ========================================

// Load ML environment data
async function loadMLEnvironment() {
    try {
        const response = await fetch('/api/ml-environment');
        const data = await response.json();
        updateMLStatus(data);
    } catch (error) {
        console.error('Error fetching ML environment:', error);
        // Set unavailable state
        setMLUnavailable();
    }
}

// Update ML status displays
function updateMLStatus(data) {
    // Update GPU Card
    const gpuCard = document.getElementById('gpu-card');

    if (data.gpu && data.gpu.present) {
        // GPU is present and working
        document.getElementById('gpu-model').textContent = data.gpu.name || 'Unknown GPU';
        document.getElementById('gpu-temp').textContent = `${data.gpu.temperature_c}°C`;
        document.getElementById('gpu-memory').textContent =
            `${data.gpu.memory_used_mb}MB / ${data.gpu.memory_total_mb}MB`;
        document.getElementById('gpu-util').textContent = `${data.gpu.utilization_percent}%`;
        document.getElementById('gpu-driver').textContent = `Driver: ${data.gpu.driver_version}`;

        // Remove all status classes first
        gpuCard.classList.remove('warning', 'critical', 'unavailable');

        // Add temperature-based status class
        const temp = parseInt(data.gpu.temperature_c);
        if (temp > 95) {
            gpuCard.classList.add('critical');
        } else if (temp > 85) {
            gpuCard.classList.add('warning');
        }
    } else {
        // No GPU detected
        document.getElementById('gpu-model').textContent = 'No GPU Detected';
        document.getElementById('gpu-temp').textContent = '--';
        document.getElementById('gpu-memory').textContent = '--';
        document.getElementById('gpu-util').textContent = '--';
        document.getElementById('gpu-driver').textContent = 'Driver: --';
        gpuCard.classList.add('unavailable');
    }

    // Update CUDA Status
    if (data.cuda) {
        updateFrameworkCard('cuda', {
            installed: data.cuda.toolkit_installed,
            version: data.cuda.toolkit_version || data.cuda.driver_version,
            status: data.cuda.toolkit_installed ? 'healthy' : 'not_installed',
            status_message: data.cuda.toolkit_installed
                ? `Toolkit ${data.cuda.toolkit_version}`
                : 'Not installed'
        });
    }

    // Update PyTorch Status
    if (data.pytorch) {
        updateFrameworkCard('pytorch', data.pytorch);
    }

    // Update TensorFlow Status
    if (data.tensorflow) {
        updateFrameworkCard('tensorflow', data.tensorflow);
    }
}

// Update individual framework card
function updateFrameworkCard(name, data) {
    const versionEl = document.getElementById(`${name}-version`);
    const statusEl = document.getElementById(`${name}-status`);
    const card = document.getElementById(`${name}-card`);

    if (!versionEl || !statusEl || !card) {
        console.warn(`Framework card elements not found for: ${name}`);
        return;
    }

    // Reset classes
    card.classList.remove('not-installed');
    statusEl.className = 'framework-status';

    if (data.installed) {
        versionEl.textContent = data.version || 'Unknown';
        statusEl.textContent = data.status_message || '';
        statusEl.classList.add(`status-${data.status || 'healthy'}`);
    } else {
        versionEl.textContent = 'Not Installed';
        statusEl.textContent = '';
        card.classList.add('not-installed');
    }
}

// Set ML environment to unavailable state
function setMLUnavailable() {
    const gpuCard = document.getElementById('gpu-card');
    gpuCard.classList.add('unavailable');

    document.getElementById('gpu-model').textContent = 'Data Unavailable';
    document.getElementById('gpu-temp').textContent = '--';
    document.getElementById('gpu-memory').textContent = '--';
    document.getElementById('gpu-util').textContent = '--';
    document.getElementById('gpu-driver').textContent = 'Driver: --';

    // Set frameworks to unavailable
    ['cuda', 'pytorch', 'tensorflow'].forEach(name => {
        updateFrameworkCard(name, {
            installed: false,
            status: 'unavailable',
            status_message: ''
        });
    });
}
