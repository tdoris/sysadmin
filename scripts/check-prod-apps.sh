#!/bin/bash
# Check production applications and services
# Auto-restart if configured

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

DRY_RUN="${DRY_RUN:-0}"
APPS_CONFIG="$CONFIG_DIR/monitored-apps.yaml"

# Check systemd service
check_systemd_app() {
    local app_name="$1"
    local service_name="$2"
    local health_url="$3"
    local auto_restart="$4"
    local critical="$5"

    log_debug "Checking systemd app: $app_name ($service_name)"

    if ! check_service_status "$service_name"; then
        log_error "Service $service_name is not running"

        if [[ "$auto_restart" == "true" && $DRY_RUN -eq 0 ]]; then
            log_info "Auto-restart enabled, attempting to restart $service_name"
            if restart_service_safe "$service_name"; then
                log_info "Successfully restarted $service_name"
                update_alerts "info" "app-${app_name}" \
                    "App Restarted: $app_name" \
                    "Service $service_name was down and has been restarted" \
                    "resolved"
                return 0
            else
                local severity="high"
                [[ "$critical" == "true" ]] && severity="critical"
                update_alerts "$severity" "app-${app_name}" \
                    "App Down: $app_name" \
                    "Service $service_name is down and failed to restart"
                return 1
            fi
        else
            local severity="medium"
            [[ "$critical" == "true" ]] && severity="critical"
            update_alerts "$severity" "app-${app_name}" \
                "App Down: $app_name" \
                "Service $service_name is not running"
            return 1
        fi
    fi

    # Check HTTP health endpoint if provided
    if [[ -n "$health_url" ]]; then
        if ! check_http_endpoint "$health_url"; then
            log_error "Health check failed for $app_name: $health_url"

            if [[ "$auto_restart" == "true" && $DRY_RUN -eq 0 ]]; then
                log_info "Auto-restart enabled, attempting to restart $service_name"
                restart_service_safe "$service_name"
            fi

            local severity="medium"
            [[ "$critical" == "true" ]] && severity="high"
            update_alerts "$severity" "app-${app_name}-health" \
                "App Health Check Failed: $app_name" \
                "HTTP endpoint $health_url is not responding"
            return 1
        fi
    fi

    log_info "✓ App $app_name is healthy"
    clear_alert "app-${app_name}"
    clear_alert "app-${app_name}-health"
    return 0
}

# Check Docker container
check_docker_app() {
    local app_name="$1"
    local container_name="$2"
    local health_url="$3"
    local auto_restart="$4"
    local critical="$5"

    log_debug "Checking Docker app: $app_name ($container_name)"

    if ! command -v docker &>/dev/null; then
        log_warning "Docker not installed, skipping $app_name"
        return 0
    fi

    local status=$(get_docker_container_status "$container_name")

    if [[ "$status" != "running" ]]; then
        log_error "Container $container_name is $status"

        if [[ "$auto_restart" == "true" && $DRY_RUN -eq 0 ]]; then
            log_info "Auto-restart enabled, attempting to start $container_name"
            if docker start "$container_name"; then
                sleep 3
                if [[ $(get_docker_container_status "$container_name") == "running" ]]; then
                    log_info "Successfully started $container_name"
                    clear_alert "app-${app_name}"
                    return 0
                fi
            fi
        fi

        local severity="high"
        [[ "$critical" == "true" ]] && severity="critical"
        update_alerts "$severity" "app-${app_name}" \
            "App Down: $app_name" \
            "Container $container_name is $status"
        return 1
    fi

    # Check HTTP health endpoint if provided
    if [[ -n "$health_url" ]]; then
        if ! check_http_endpoint "$health_url"; then
            log_error "Health check failed for $app_name: $health_url"

            if [[ "$auto_restart" == "true" && $DRY_RUN -eq 0 ]]; then
                log_info "Auto-restart enabled, restarting $container_name"
                docker restart "$container_name"
            fi

            local severity="medium"
            [[ "$critical" == "true" ]] && severity="high"
            update_alerts "$severity" "app-${app_name}-health" \
                "App Health Check Failed: $app_name" \
                "HTTP endpoint $health_url is not responding"
            return 1
        fi
    fi

    log_info "✓ App $app_name is healthy"
    clear_alert "app-${app_name}"
    clear_alert "app-${app_name}-health"
    return 0
}

# Check cron job
check_cron_app() {
    local app_name="$1"
    local check_log="$2"
    local max_failures="$3"
    local critical="$4"

    log_debug "Checking cron job: $app_name"

    if [[ ! -f "$check_log" ]]; then
        log_warning "Log file not found: $check_log"
        update_alerts "medium" "app-${app_name}" \
            "Cron Job Log Missing: $app_name" \
            "Log file $check_log does not exist"
        return 1
    fi

    # Check if log has been updated recently (last 25 hours for daily jobs)
    local log_age_hours=$(( ($(date +%s) - $(stat -c %Y "$check_log")) / 3600 ))

    if [[ $log_age_hours -gt 25 ]]; then
        log_error "Cron job $app_name appears stale (log age: ${log_age_hours}h)"
        local severity="medium"
        [[ "$critical" == "true" ]] && severity="high"
        update_alerts "$severity" "app-${app_name}" \
            "Cron Job Stale: $app_name" \
            "Log file has not been updated in ${log_age_hours} hours"
        return 1
    fi

    # Check for recent errors
    local error_count=$(tail -100 "$check_log" | grep -ci "error\|failed\|exception" || echo "0")

    if [[ $error_count -gt 0 ]]; then
        log_warning "Cron job $app_name has $error_count recent errors"
        update_alerts "medium" "app-${app_name}-errors" \
            "Cron Job Errors: $app_name" \
            "Found $error_count errors in recent log entries"
        return 1
    fi

    log_info "✓ Cron job $app_name is healthy"
    clear_alert "app-${app_name}"
    clear_alert "app-${app_name}-errors"
    return 0
}

# Main execution
main() {
    log_info "Starting production app monitoring"

    if [[ ! -f "$APPS_CONFIG" ]]; then
        log_warning "Apps config not found: $APPS_CONFIG"
        return 0
    fi

    # Parse YAML and check each app
    # Note: This uses Python to parse YAML - could also use yq if available
    local apps_json=$(python3 -c "
import yaml
import json
import sys

try:
    with open('$APPS_CONFIG', 'r') as f:
        data = yaml.safe_load(f)
        print(json.dumps(data.get('apps', {})))
except Exception as e:
    print('{}')
    sys.exit(0)
")

    if [[ "$apps_json" == "{}" ]]; then
        log_info "No apps configured for monitoring"
        return 0
    fi

    local total_apps=0
    local healthy_apps=0
    local unhealthy_apps=0

    # Iterate through apps
    echo "$apps_json" | python3 -c "
import json
import sys

data = json.load(sys.stdin)
for app_name, config in data.items():
    app_type = config.get('type', '')
    print(f'{app_name}|{app_type}|{json.dumps(config)}')
" | while IFS='|' read -r app_name app_type config_json; do
        ((total_apps++)) || true

        case "$app_type" in
            systemd)
                service_name=$(echo "$config_json" | python3 -c "import json,sys; print(json.load(sys.stdin).get('service_name', ''))")
                health_url=$(echo "$config_json" | python3 -c "import json,sys; print(json.load(sys.stdin).get('health_check', {}).get('url', ''))")
                auto_restart=$(echo "$config_json" | python3 -c "import json,sys; print(json.load(sys.stdin).get('auto_restart', 'false'))")
                critical=$(echo "$config_json" | python3 -c "import json,sys; print(json.load(sys.stdin).get('critical', 'false'))")

                if check_systemd_app "$app_name" "$service_name" "$health_url" "$auto_restart" "$critical"; then
                    ((healthy_apps++)) || true
                else
                    ((unhealthy_apps++)) || true
                fi
                ;;
            docker)
                container_name=$(echo "$config_json" | python3 -c "import json,sys; print(json.load(sys.stdin).get('container_name', ''))")
                health_url=$(echo "$config_json" | python3 -c "import json,sys; print(json.load(sys.stdin).get('health_check', {}).get('url', ''))")
                auto_restart=$(echo "$config_json" | python3 -c "import json,sys; print(json.load(sys.stdin).get('auto_restart', 'false'))")
                critical=$(echo "$config_json" | python3 -c "import json,sys; print(json.load(sys.stdin).get('critical', 'false'))")

                if check_docker_app "$app_name" "$container_name" "$health_url" "$auto_restart" "$critical"; then
                    ((healthy_apps++)) || true
                else
                    ((unhealthy_apps++)) || true
                fi
                ;;
            cron)
                check_log=$(echo "$config_json" | python3 -c "import json,sys; print(json.load(sys.stdin).get('check_log', ''))")
                max_failures=$(echo "$config_json" | python3 -c "import json,sys; print(json.load(sys.stdin).get('max_failures', '3'))")
                critical=$(echo "$config_json" | python3 -c "import json,sys; print(json.load(sys.stdin).get('critical', 'false'))")

                if check_cron_app "$app_name" "$check_log" "$max_failures" "$critical"; then
                    ((healthy_apps++)) || true
                else
                    ((unhealthy_apps++)) || true
                fi
                ;;
            *)
                log_warning "Unknown app type: $app_type for $app_name"
                ;;
        esac
    done

    log_info "App monitoring complete: $healthy_apps healthy, $unhealthy_apps unhealthy (total: $total_apps)"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
