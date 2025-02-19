#!/bin/bash

echo "CRON_SCHEDULE=${CRON_SCHEDULE}"
echo "CRON_COMMAND=${CRON_COMMAND}"
echo "PUID=${PUID}"
echo "PGID=${PGID}"
echo "==========================================="

if pgrep -x cron >/dev/null; then
    echo 'Stopping existing cron process...'
    pkill -x cron
fi

if [[ -z "${CRON_SCHEDULE}" || -z "${CRON_COMMAND}" ]]; then
    echo 'Error: CRON_SCHEDULE or CRON_COMMAND is not set.'
    exit 1
fi

# Check if PUID and PGID are set, otherwise run as root
if [[ -n "${PUID}" && -n "${PGID}" ]]; then
    # Create a group if it doesn't exist
    if ! getent group abc >/dev/null; then
        echo "Creating group with GID=${PGID}"
        groupadd -g "${PGID}" abc
    fi

    # Create a user if it doesn't exist
    if ! id -u abc >/dev/null 2>&1; then
        echo "Creating user with UID=${PUID} and GID=${PGID}"
        useradd -u "${PUID}" -g "${PGID}" -m -s /bin/bash abc
    fi

    # Set up the crontab for the created user
    echo "Configuring cron job for abc..."
    echo "${CRON_SCHEDULE} ${CRON_COMMAND} >/proc/1/fd/1 2>/proc/1/fd/2" | crontab -u abc -
    if [[ $? -ne 0 ]]; then
        echo 'Error: Failed to configure crontab for abc.'
        exit 1
    fi
    echo 'Crontab configured for abc:'
    crontab -u abc -l

else
    # Set up the crontab for root
    echo "No PUID or PGID set. Running as root..."
    echo "${CRON_SCHEDULE} ${CRON_COMMAND} >/proc/1/fd/1 2>/proc/1/fd/2" | crontab -
    if [[ $? -ne 0 ]]; then
        echo 'Error: Failed to configure crontab for root.'
        exit 1
    fi
    echo 'Crontab configured for root:'
    crontab -l
fi

# Start the cron daemon in the foreground
echo 'Starting cron...'
exec cron -f
