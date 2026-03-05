#!/bin/bash
set -e

# -----------------------------------------------------------------------
# Docker-secrets support: resolve <VAR>_FILE → <VAR>
# Follows the convention used by the official PostgreSQL image.
# -----------------------------------------------------------------------
file_env() {
    local var="$1"
    local fileVar="${var}_FILE"
    local def="${2:-}"
    if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
        printf >&2 'error: both %s and %s are set (but are exclusive)\n' "$var" "$fileVar"
        exit 1
    fi
    local val="$def"
    if [ "${!var:-}" ]; then
        val="${!var}"
    elif [ "${!fileVar:-}" ]; then
        val="$(< "${!fileVar}")"
    fi
    export "$var"="$val"
    unset "$fileVar"
}

file_env 'OPEN_TERMINAL_API_KEY'

# Fix permissions of the home directory if the user doesn't own it
# Find out who owns /home/user
OWNER=$(stat -c '%U' /home/user 2>/dev/null || echo "user")

if [ "$OWNER" != "user" ]; then
    # We use sudo because the container runs as 'user' but has passwordless sudo
    sudo chown -R user:user /home/user 2>/dev/null || true
fi

# Auto-install system packages
if [ -n "${OPEN_TERMINAL_PACKAGES:-}" ]; then
    echo "Installing system packages: $OPEN_TERMINAL_PACKAGES"
    sudo apt-get update -qq && sudo apt-get install -y --no-install-recommends $OPEN_TERMINAL_PACKAGES
    sudo rm -rf /var/lib/apt/lists/*
fi

# Auto-install Python packages
if [ -n "${OPEN_TERMINAL_PIP_PACKAGES:-}" ]; then
    echo "Installing pip packages: $OPEN_TERMINAL_PIP_PACKAGES"
    pip install --no-cache-dir $OPEN_TERMINAL_PIP_PACKAGES
fi

exec open-terminal "$@"
