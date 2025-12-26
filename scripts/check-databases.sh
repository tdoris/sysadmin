#!/bin/bash
# Database health checks for development environments
# Checks PostgreSQL, MySQL, MongoDB, Redis, InfluxDB, and SQLite

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Check PostgreSQL
check_postgresql() {
    log_info "Checking PostgreSQL..."

    if systemctl list-unit-files | grep -q "postgresql"; then
        if systemctl is-active --quiet postgresql; then
            log_info "✓ PostgreSQL service running"

            # Get PostgreSQL version
            if command -v psql &>/dev/null; then
                local pg_version=$(psql --version 2>/dev/null | awk '{print $3}')
                log_info "✓ PostgreSQL version: $pg_version"
            fi

            # Check connection (requires local authentication)
            if sudo -u postgres psql -c "SELECT version();" &>/dev/null; then
                log_info "✓ PostgreSQL connection successful"
                clear_alert "postgresql-connection-failed"

                # Check database count
                local db_count=$(sudo -u postgres psql -t -c "SELECT count(*) FROM pg_database WHERE datistemplate = false;" 2>/dev/null | tr -d ' ')
                log_info "  Databases: $db_count"

                # Check for long-running queries
                local long_queries=$(sudo -u postgres psql -t -c "SELECT count(*) FROM pg_stat_activity WHERE state = 'active' AND now() - query_start > interval '10 minutes';" 2>/dev/null | tr -d ' ')
                if [[ "$long_queries" -gt 0 ]]; then
                    log_warning "PostgreSQL has $long_queries long-running queries (>10min)"
                    update_alerts "medium" "postgresql-long-queries" \
                        "PostgreSQL Long-Running Queries" \
                        "$long_queries queries running for more than 10 minutes. Check with: sudo -u postgres psql -c \"SELECT * FROM pg_stat_activity WHERE state = 'active';\""
                else
                    clear_alert "postgresql-long-queries"
                fi
            else
                log_warning "Cannot connect to PostgreSQL"
                update_alerts "high" "postgresql-connection-failed" \
                    "PostgreSQL Connection Failed" \
                    "Service is running but cannot establish connection. Check logs: sudo journalctl -u postgresql -n 50"
            fi

            clear_alert "postgresql-service-down"
        else
            log_warning "PostgreSQL installed but not running"
            update_alerts "medium" "postgresql-service-down" \
                "PostgreSQL Service Not Running" \
                "PostgreSQL is installed but not active. Start with: sudo systemctl start postgresql"
        fi
    else
        log_debug "PostgreSQL not installed"
    fi

    return 0
}

# Check MySQL/MariaDB
check_mysql() {
    log_info "Checking MySQL/MariaDB..."

    # Check for MySQL
    if systemctl list-unit-files | grep -qE "mysql|mariadb"; then
        local service_name=""
        if systemctl list-unit-files | grep -q "mysql.service"; then
            service_name="mysql"
        elif systemctl list-unit-files | grep -q "mariadb.service"; then
            service_name="mariadb"
        fi

        if [[ -n "$service_name" ]] && systemctl is-active --quiet "$service_name"; then
            log_info "✓ $service_name service running"

            # Get version
            if command -v mysql &>/dev/null; then
                local mysql_version=$(mysql --version 2>/dev/null | awk '{print $5}' | tr -d ',')
                log_info "✓ MySQL/MariaDB version: $mysql_version"
            fi

            # Check connection (try without password for local root)
            if mysql -u root -e "SELECT 1;" &>/dev/null; then
                log_info "✓ MySQL connection successful"
                clear_alert "mysql-connection-failed"

                # Check database count
                local db_count=$(mysql -u root -s -N -e "SELECT count(*) FROM information_schema.schemata WHERE schema_name NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys');" 2>/dev/null)
                log_info "  Databases: $db_count"

                # Check for long-running queries
                local long_queries=$(mysql -u root -s -N -e "SELECT count(*) FROM information_schema.processlist WHERE command != 'Sleep' AND time > 600;" 2>/dev/null)
                if [[ "$long_queries" -gt 0 ]]; then
                    log_warning "MySQL has $long_queries long-running queries (>10min)"
                    update_alerts "medium" "mysql-long-queries" \
                        "MySQL Long-Running Queries" \
                        "$long_queries queries running for more than 10 minutes. Check with: mysql -u root -e 'SHOW PROCESSLIST;'"
                else
                    clear_alert "mysql-long-queries"
                fi
            else
                log_debug "Cannot connect to MySQL as root without password (may be secured)"
                clear_alert "mysql-connection-failed"
            fi

            clear_alert "mysql-service-down"
        else
            log_warning "$service_name installed but not running"
            update_alerts "medium" "mysql-service-down" \
                "MySQL/MariaDB Service Not Running" \
                "MySQL/MariaDB is installed but not active. Start with: sudo systemctl start $service_name"
        fi
    else
        log_debug "MySQL/MariaDB not installed"
    fi

    return 0
}

# Check MongoDB
check_mongodb() {
    log_info "Checking MongoDB..."

    if systemctl list-unit-files | grep -q "mongod"; then
        if systemctl is-active --quiet mongod; then
            log_info "✓ MongoDB service running"

            # Get version
            if command -v mongod &>/dev/null; then
                local mongo_version=$(mongod --version 2>/dev/null | grep "db version" | awk '{print $3}')
                log_info "✓ MongoDB version: $mongo_version"
            fi

            # Check connection
            if command -v mongosh &>/dev/null || command -v mongo &>/dev/null; then
                local mongo_cmd=$(command -v mongosh 2>/dev/null || command -v mongo)
                if timeout 5s "$mongo_cmd" --quiet --eval "db.version()" &>/dev/null; then
                    log_info "✓ MongoDB connection successful"
                    clear_alert "mongodb-connection-failed"

                    # Check database count
                    local db_count=$("$mongo_cmd" --quiet --eval "db.adminCommand('listDatabases').databases.length" 2>/dev/null || echo "unknown")
                    log_info "  Databases: $db_count"
                else
                    log_warning "Cannot connect to MongoDB"
                    update_alerts "high" "mongodb-connection-failed" \
                        "MongoDB Connection Failed" \
                        "Service is running but cannot establish connection. Check logs: sudo journalctl -u mongod -n 50"
                fi
            fi

            clear_alert "mongodb-service-down"
        else
            log_warning "MongoDB installed but not running"
            update_alerts "medium" "mongodb-service-down" \
                "MongoDB Service Not Running" \
                "MongoDB is installed but not active. Start with: sudo systemctl start mongod"
        fi
    else
        log_debug "MongoDB not installed"
    fi

    return 0
}

# Check Redis
check_redis() {
    log_info "Checking Redis..."

    if systemctl list-unit-files | grep -q "redis"; then
        local service_name="redis-server"
        if ! systemctl list-unit-files | grep -q "redis-server"; then
            service_name="redis"
        fi

        if systemctl is-active --quiet "$service_name"; then
            log_info "✓ Redis service running"

            # Get version
            if command -v redis-cli &>/dev/null; then
                local redis_version=$(redis-cli --version 2>/dev/null | awk '{print $2}')
                log_info "✓ Redis version: $redis_version"

                # Check connection
                if redis-cli ping &>/dev/null; then
                    log_info "✓ Redis connection successful"
                    clear_alert "redis-connection-failed"

                    # Check memory usage
                    local mem_used=$(redis-cli info memory 2>/dev/null | grep "used_memory_human" | cut -d: -f2 | tr -d '\r')
                    log_info "  Memory used: $mem_used"

                    # Check connected clients
                    local clients=$(redis-cli info clients 2>/dev/null | grep "connected_clients" | cut -d: -f2 | tr -d '\r')
                    log_info "  Connected clients: $clients"
                else
                    log_warning "Cannot connect to Redis"
                    update_alerts "high" "redis-connection-failed" \
                        "Redis Connection Failed" \
                        "Service is running but cannot establish connection. Check logs: sudo journalctl -u $service_name -n 50"
                fi
            fi

            clear_alert "redis-service-down"
        else
            log_warning "Redis installed but not running"
            update_alerts "medium" "redis-service-down" \
                "Redis Service Not Running" \
                "Redis is installed but not active. Start with: sudo systemctl start $service_name"
        fi
    else
        log_debug "Redis not installed"
    fi

    return 0
}

# Check InfluxDB
check_influxdb() {
    log_info "Checking InfluxDB..."

    if systemctl list-unit-files | grep -q "influxdb"; then
        if systemctl is-active --quiet influxdb; then
            log_info "✓ InfluxDB service running"

            # Check if InfluxDB is accessible
            if curl -f -s -m 2 http://localhost:8086/health &>/dev/null; then
                log_info "✓ InfluxDB accessible on port 8086"
                clear_alert "influxdb-connection-failed"
            else
                log_warning "InfluxDB service running but not accessible on port 8086"
                update_alerts "medium" "influxdb-connection-failed" \
                    "InfluxDB Not Accessible" \
                    "Service is running but not responding on port 8086. Check logs: sudo journalctl -u influxdb -n 50"
            fi

            clear_alert "influxdb-service-down"
        else
            log_warning "InfluxDB installed but not running"
            update_alerts "medium" "influxdb-service-down" \
                "InfluxDB Service Not Running" \
                "InfluxDB is installed but not active. Start with: sudo systemctl start influxdb"
        fi
    else
        log_debug "InfluxDB not installed"
    fi

    return 0
}

# Check SQLite
check_sqlite() {
    log_info "Checking SQLite..."

    if command -v sqlite3 &>/dev/null; then
        local sqlite_version=$(sqlite3 --version 2>/dev/null | awk '{print $1}')
        log_info "✓ SQLite: $sqlite_version"

        # Find SQLite databases in common locations
        local db_locations=(
            "$HOME"
            "$HOME/data"
            "$HOME/databases"
            "/var/lib"
        )

        local db_count=0
        for location in "${db_locations[@]}"; do
            if [[ -d "$location" ]]; then
                local found=$(find "$location" -maxdepth 2 -name "*.db" -o -name "*.sqlite" -o -name "*.sqlite3" 2>/dev/null | wc -l)
                db_count=$((db_count + found))
            fi
        done

        if [[ $db_count -gt 0 ]]; then
            log_info "  Found $db_count SQLite database files"
        fi
    else
        log_debug "SQLite not installed"
    fi

    return 0
}

# Check database disk usage
check_database_disk_usage() {
    log_info "Checking database disk usage..."

    local locations=(
        "/var/lib/postgresql"
        "/var/lib/mysql"
        "/var/lib/mongodb"
        "/var/lib/redis"
        "/var/lib/influxdb"
    )

    for location in "${locations[@]}"; do
        if [[ -d "$location" ]]; then
            local size=$(sudo du -sm "$location" 2>/dev/null | awk '{print $1}')
            local db_name=$(basename "$location")
            log_info "  $db_name: ${size}MB"

            if [[ $size -gt 50000 ]]; then
                log_warning "$db_name database is large (${size}MB)"
                update_alerts "info" "${db_name}-large-db" \
                    "Large $db_name Database" \
                    "Database size is ${size}MB. Consider cleanup or archival."
            else
                clear_alert "${db_name}-large-db"
            fi
        fi
    done

    return 0
}

# Generate database report
generate_database_report() {
    log_info "Generating database report..."

    local report_file="$REPORTS_DIR/databases.txt"

    {
        echo "Database Health Report"
        echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
        echo "=== PostgreSQL ==="
        if systemctl is-active --quiet postgresql 2>/dev/null; then
            echo "Status: Running"
            command -v psql &>/dev/null && psql --version
            sudo -u postgres psql -c "SELECT version();" 2>/dev/null | head -3
        else
            echo "Status: Not running or not installed"
        fi
        echo ""
        echo "=== MySQL/MariaDB ==="
        if systemctl is-active --quiet mysql 2>/dev/null || systemctl is-active --quiet mariadb 2>/dev/null; then
            echo "Status: Running"
            command -v mysql &>/dev/null && mysql --version
        else
            echo "Status: Not running or not installed"
        fi
        echo ""
        echo "=== MongoDB ==="
        if systemctl is-active --quiet mongod 2>/dev/null; then
            echo "Status: Running"
            command -v mongod &>/dev/null && mongod --version | head -1
        else
            echo "Status: Not running or not installed"
        fi
        echo ""
        echo "=== Redis ==="
        if systemctl is-active --quiet redis-server 2>/dev/null || systemctl is-active --quiet redis 2>/dev/null; then
            echo "Status: Running"
            command -v redis-cli &>/dev/null && redis-cli --version
        else
            echo "Status: Not running or not installed"
        fi
        echo ""
        echo "=== InfluxDB ==="
        if systemctl is-active --quiet influxdb 2>/dev/null; then
            echo "Status: Running"
        else
            echo "Status: Not running or not installed"
        fi
        echo ""
        echo "=== SQLite ==="
        command -v sqlite3 &>/dev/null && sqlite3 --version || echo "Not installed"
    } > "$report_file"

    log_info "Report saved to: $report_file"
}

# Main execution
main() {
    log_info "==================== DATABASE HEALTH CHECK ===================="

    check_postgresql
    check_mysql
    check_mongodb
    check_redis
    check_influxdb
    check_sqlite
    check_database_disk_usage

    generate_database_report

    log_info "==================== DATABASE HEALTH CHECK COMPLETE ===================="
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
