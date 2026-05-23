#!/bin/bash

BACKUP_DIR="/opt/backups/website"
DATE=$(date +"%Y-%m-%d_%H-%M-%S")

WEB_SERVER="172.17.30.8"
WEB_USER="administrator"
WEB_PATH="/var/www/html"

DB_SERVER="172.17.30.13"
DB_USER="root"
DB_NAME="wordpress"
DB_BACKUP_FILE="database_${DATE}.sql"

BACKUP_FILE="website_backup_${DATE}.tar.gz"

mkdir -p "$BACKUP_DIR"

echo "Starting website backup: $DATE"

ssh ${DB_USER}@${DB_SERVER} "mysqldump ${DB_NAME}" > "${BACKUP_DIR}/${DB_BACKUP_FILE}"

rsync -az ${WEB_USER}@${WEB_SERVER}:${WEB_PATH}/ "${BACKUP_DIR}/web_${DATE}/"

tar -czf "${BACKUP_DIR}/${BACKUP_FILE}" -C "$BACKUP_DIR" "web_${DATE}" "${DB_BACKUP_FILE}"

rm -rf "${BACKUP_DIR}/web_${DATE}"
rm -f "${BACKUP_DIR}/${DB_BACKUP_FILE}"

find "$BACKUP_DIR" -name "website_backup_*.tar.gz" -type f | sort | head -n -5 | xargs -r rm -f

echo "Backup completed: ${BACKUP_DIR}/${BACKUP_FILE}"