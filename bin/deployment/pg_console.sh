#!/bin/bash

# pg_console.sh
# Usage:
#   ./pg_console.sh                  -> open interactive psql session
#   ./pg_console.sh "SQL_COMMAND"    -> run SQL command non-interactively

set -euo pipefail

SERVER="misc"
POSTGRES_CONTAINER="helix-kit-postgres"

PGURL="postgresql://helix_kit:$(cat config/credentials/deployment/postgres_pw_prod.key)@$POSTGRES_CONTAINER:5432/helix_kit_production"

if [ $# -eq 1 ]; then
    # Non-interactive: run SQL command
    SQL_COMMAND="$1"
    echo "Running on $SERVER ($POSTGRES_CONTAINER): $SQL_COMMAND"
    ssh $SERVER -t "docker exec -i $POSTGRES_CONTAINER psql \"$PGURL\" -c \"$SQL_COMMAND\""
else
    # Interactive mode
    echo "Connecting to $SERVER server, $POSTGRES_CONTAINER container..."
    echo "--------------------------------"
    echo "Handy pgsql commands:"
    echo "\c helix_kit_production -- switch to helix_kit_production database"
    echo "\l -- list all databases"
    echo "\dt -- list all tables"
    echo "\du -- list all users"
    echo "\dn -- list all schemas"
    echo "\di -- list all indexes"
    echo "\di+ -- list all indexes with details"
    echo "\di* -- list all indexes with details and statistics"
    echo "\q -- quit"
    echo "--------------------------------"

    ssh $SERVER -t "docker exec -it $POSTGRES_CONTAINER psql \"$PGURL\""
fi
