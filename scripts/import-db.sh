#!/bin/bash
# Wordwonk Database Import Script
# This script imports a SQL backup into the PostgreSQL pod.
# Usage: ./scripts/import-db.sh [backup_file.sql]
# If no file is provided, it defaults to reading from STDIN (piped).

NAMESPACE="Wordwonk"
BACKUP_FILE=${1:-/dev/stdin}

echo "🔍 Finding PostgreSQL pod..."
POD_NAME=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/instance=Wordwonk,app.kubernetes.io/name=postgresql -o jsonpath="{.items[0].metadata.name}")

if [ -z "$POD_NAME" ]; then
    echo "❌ Error: Could not find PostgreSQL pod in namespace $NAMESPACE."
    exit 1
fi

echo "🔐 Fetching superuser password..."
POSTGRES_PASSWORD=$(kubectl get secret postgresql -n "$NAMESPACE" -o jsonpath="{.data.postgres-password}" | base64 --decode)

if [ -z "$POSTGRES_PASSWORD" ]; then
    echo "❌ Error: Could not fetch postgres password from secret."
    exit 1
fi

echo "🧹 Dropping and re-creating 'Wordwonk' database..."
kubectl exec -i -n "$NAMESPACE" "$POD_NAME" -- env PGPASSWORD="$POSTGRES_PASSWORD" psql -U postgres -d postgres -c "DROP DATABASE IF EXISTS Wordwonk WITH (FORCE);"
kubectl exec -i -n "$NAMESPACE" "$POD_NAME" -- env PGPASSWORD="$POSTGRES_PASSWORD" psql -U postgres -d postgres -c "CREATE DATABASE Wordwonk OWNER Wordwonk_backend;"

echo "🚀 Importing data into $POD_NAME..."
# Connect to 'Wordwonk' database for the import
# We use the postgres superuser to ensure permissions for role handling etc.
cat "$BACKUP_FILE" | kubectl exec -i -n "$NAMESPACE" "$POD_NAME" -- env PGPASSWORD="$POSTGRES_PASSWORD" psql -U postgres -d Wordwonk

if [ $? -eq 0 ]; then
    echo "✅ Import successful!"
else
    echo "❌ Import failed."
    exit 1
fi

