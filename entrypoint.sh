#!/bin/bash
set -euo pipefail

echo "CRON_SCHEDULE=${CRON_SCHEDULE:-not set}"
echo "CRON_COMMAND=${CRON_COMMAND:-not set}"
echo "PUID=${PUID:-not set}"
echo "PGID=${PGID:-not set}"
echo "==========================================="

# Stop any running cron process
if pgrep -x cron >/dev/null 2>&1; then
    echo "Stopping existing cron process..."
    pkill -x cron || echo "Warning: Unable to kill cron process"
fi

# Ensure required environment variables are set
if [[ -z "${CRON_SCHEDULE:-}" || -z "${CRON_COMMAND:-}" ]]; then
    echo "Error: CRON_SCHEDULE or CRON_COMMAND is not set. Please provide these env vars."
    exit 1
fi

# Prepare the cron job command with Docker-friendly output redirection
CRON_JOB="${CRON_SCHEDULE} ${CRON_COMMAND} >/proc/1/fd/1 2>/proc/1/fd/2"

# If PUID and PGID are provided, set up a non-root user; otherwise, run as root
if [[ -n "${PUID:-}" && -n "${PGID:-}" ]]; then
    USERNAME="abc"  # Change this name if desired

    # Create group if it doesn't exist
    if ! getent group "${USERNAME}" >/dev/null; then
        echo "Creating group '${USERNAME}' with GID=${PGID}"
        groupadd -g "${PGID}" "${USERNAME}"
    else
        echo "Group '${USERNAME}' already exists."
    fi

    # Create user if it doesn't exist
    if ! id -u "${USERNAME}" >/dev/null 2>&1; then
        echo "Creating user '${USERNAME}' with UID=${PUID} and GID=${PGID}"
        useradd -u "${PUID}" -g "${PGID}" -m -s /bin/bash "${USERNAME}"
    else
        echo "User '${USERNAME}' already exists."
    fi

    # Configure the crontab for the non-root user
    echo "Setting up cron job for user '${USERNAME}'..."
    echo "${CRON_JOB}" | crontab -u "${USERNAME}" -
    echo "Crontab for '${USERNAME}':"
    crontab -u "${USERNAME}" -l
else
    # Configure the crontab for root
    echo "No PUID or PGID provided. Running as root..."
    echo "${CRON_JOB}" | crontab -
    echo "Crontab for root:"
    crontab -l
fi

# Determine which cron daemon is available (cron or crond)
if command -v cron >/dev/null 2>&1; then
    CRON_DAEMON="cron"
elif command -v crond >/dev/null 2>&1; then
    CRON_DAEMON="crond"
else
    echo "Error: Neither cron nor crond is installed."
    exit 1
fi

echo "Starting cron daemon with: ${CRON_DAEMON} -f"
exec "${CRON_DAEMON}" -f
