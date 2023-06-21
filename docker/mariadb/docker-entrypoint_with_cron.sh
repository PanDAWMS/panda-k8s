#!/bin/bash

declare -p | grep -Ev 'BASHOPTS|BASH_VERSINFO|EUID|PPID|SHELLOPTS|UID' > /tmp/container_env.sh

RUN crontab -l | { cat; echo "18 * * * * bash /usr/local/bin/backup_mysql_cron.sh"; } | crontab -
cron -f &
docker-entrypoint.sh "$@"
