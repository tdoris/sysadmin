#!/usr/bin/env python3
"""
Sysadmin Dashboard - Web interface for Claude Code sysadmin

Note: This should be run via the venv Python interpreter.
When started by systemd, it will use: ../venv/bin/python
"""

from flask import Flask, render_template, jsonify, request
import os
import json
import yaml
import subprocess
from datetime import datetime
from pathlib import Path
import markdown

app = Flask(__name__)

# Configuration
SYSADMIN_DIR = Path(__file__).parent.parent
HOSTNAME = os.uname().nodename
REPORTS_DIR = SYSADMIN_DIR / 'reports' / HOSTNAME
CONFIG_DIR = SYSADMIN_DIR / 'config'
CLAUDE_ADMIN_DIR = SYSADMIN_DIR / 'claude-admin'


def read_file(filepath, default=''):
    """Safely read a file, return default if not found"""
    try:
        if Path(filepath).exists():
            return Path(filepath).read_text()
    except Exception as e:
        app.logger.error(f"Error reading {filepath}: {e}")
    return default


def read_json(filepath, default=None):
    """Safely read a JSON file"""
    try:
        if Path(filepath).exists():
            with open(filepath) as f:
                return json.load(f)
    except Exception as e:
        app.logger.error(f"Error reading JSON {filepath}: {e}")
    return default or {}


def read_yaml(filepath, default=None):
    """Safely read a YAML file"""
    try:
        if Path(filepath).exists():
            with open(filepath) as f:
                return yaml.safe_load(f)
    except Exception as e:
        app.logger.error(f"Error reading YAML {filepath}: {e}")
    return default or {}


def get_system_status():
    """Get current system status"""
    status = {
        'hostname': HOSTNAME,
        'timestamp': datetime.now().isoformat(),
        'disk_usage': 0,
        'memory_usage': 0,
        'load_avg': 0.0,
        'uptime': 'unknown',
        'firewall': 'unknown',
    }

    try:
        # Disk usage
        df_output = subprocess.check_output(['df', '-h', '/'], text=True)
        for line in df_output.split('\n')[1:]:
            if line:
                parts = line.split()
                status['disk_usage'] = parts[4].rstrip('%')
                break

        # Memory usage
        free_output = subprocess.check_output(['free'], text=True)
        for line in free_output.split('\n'):
            if line.startswith('Mem:'):
                parts = line.split()
                total, used = int(parts[1]), int(parts[2])
                status['memory_usage'] = int((used / total) * 100)
                break

        # Load average
        with open('/proc/loadavg') as f:
            status['load_avg'] = float(f.read().split()[0])

        # Uptime
        uptime_output = subprocess.check_output(['uptime', '-p'], text=True).strip()
        status['uptime'] = uptime_output.replace('up ', '')

        # Firewall
        ufw_output = subprocess.check_output(['sudo', 'ufw', 'status'], text=True)
        status['firewall'] = 'active' if 'Status: active' in ufw_output else 'inactive'

    except Exception as e:
        app.logger.error(f"Error getting system status: {e}")

    return status


def get_alerts():
    """Get current alerts"""
    alerts_file = REPORTS_DIR / 'alerts.json'
    alerts = read_json(alerts_file, {
        'critical': [],
        'high': [],
        'medium': [],
        'info': []
    })

    return {
        'critical': alerts.get('critical', []),
        'high': alerts.get('high', []),
        'medium': alerts.get('medium', []),
        'info': alerts.get('info', []),
        'total': sum(len(alerts.get(k, [])) for k in ['critical', 'high', 'medium'])
    }


def get_recent_activity(lines=50):
    """Get recent activity from log"""
    activity_log = REPORTS_DIR / 'activity.log'
    if not activity_log.exists():
        return []

    try:
        # Read last N lines
        output = subprocess.check_output(['tail', '-n', str(lines), str(activity_log)], text=True)
        return output.split('\n')
    except Exception as e:
        app.logger.error(f"Error reading activity log: {e}")
        return []


def get_recommendations():
    """Get Claude's recommendations"""
    rec_file = REPORTS_DIR / 'recommendations.json'
    return read_json(rec_file, {
        'critical': [],
        'high': [],
        'medium': [],
        'optimizations': []
    })


def get_monitored_apps():
    """Get list of monitored applications"""
    apps_file = CONFIG_DIR / 'monitored-apps.yaml'
    data = read_yaml(apps_file, {})
    return data.get('apps', {})


@app.route('/')
def index():
    """Main dashboard page"""
    return render_template('index.html',
                           hostname=HOSTNAME,
                           claude_command=f"cd ~/sysadmin && claude --dangerously-skip-permissions")


@app.route('/api/status')
def api_status():
    """API endpoint for system status"""
    return jsonify(get_system_status())


@app.route('/api/alerts')
def api_alerts():
    """API endpoint for alerts"""
    return jsonify(get_alerts())


@app.route('/api/activity')
def api_activity():
    """API endpoint for recent activity"""
    lines = request.args.get('lines', 100, type=int)
    return jsonify({'activity': get_recent_activity(lines)})


@app.route('/api/recommendations')
def api_recommendations():
    """API endpoint for recommendations"""
    return jsonify(get_recommendations())


@app.route('/api/apps')
def api_apps():
    """API endpoint for monitored apps"""
    return jsonify(get_monitored_apps())


@app.route('/api/report')
def api_report():
    """API endpoint for latest system report"""
    report_file = REPORTS_DIR / 'latest.md'
    content = read_file(report_file, '# No report available yet\n\nRun daily maintenance to generate a report.')

    # Convert markdown to HTML
    html = markdown.markdown(content, extensions=['extra', 'codehilite', 'fenced_code'])

    return jsonify({
        'markdown': content,
        'html': html,
        'timestamp': datetime.fromtimestamp(report_file.stat().st_mtime).isoformat() if report_file.exists() else None
    })


@app.route('/api/trigger/<job>', methods=['POST'])
def api_trigger_job(job):
    """API endpoint to trigger maintenance jobs"""
    if job not in ['hourly', 'daily']:
        return jsonify({'error': 'Invalid job type'}), 400

    script_path = CLAUDE_ADMIN_DIR / f'run-{job}.sh'
    if not script_path.exists():
        return jsonify({'error': f'Script not found: {script_path}'}), 404

    try:
        # Run in background
        subprocess.Popen(
            [str(script_path)],
            cwd=str(SYSADMIN_DIR),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE
        )

        return jsonify({
            'success': True,
            'message': f'{job.capitalize()} maintenance job started',
            'timestamp': datetime.now().isoformat()
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


@app.route('/api/logs')
def api_logs():
    """API endpoint for log files"""
    log_type = request.args.get('type', 'sysadmin')
    lines = request.args.get('lines', 100, type=int)

    if log_type == 'activity':
        log_file = REPORTS_DIR / 'activity.log'
    else:
        log_file = Path('/var/log/sysadmin/sysadmin.log')

    if not log_file.exists():
        return jsonify({'lines': []})

    try:
        output = subprocess.check_output(['tail', '-n', str(lines), str(log_file)], text=True)
        return jsonify({'lines': output.split('\n')})
    except Exception as e:
        return jsonify({'error': str(e)}), 500


if __name__ == '__main__':
    # Ensure reports directory exists
    REPORTS_DIR.mkdir(parents=True, exist_ok=True)

    # Run on localhost:5050
    app.run(host='127.0.0.1', port=5050, debug=False)
