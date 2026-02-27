#!/bin/bash

# Robust script to stop the Shopizer Mini-Cloud environment
set -e

echo "--- Shutting down the Shopizer Mini-Cloud ---"

if colima status >/dev/null 2>&1; then
    echo "Stopping Colima VM (this will gracefully stop all internal services like MySQL and Shopizer)..."
    colima stop
    echo "Done. All services are offline."
else
    echo "Colima is not running. Nothing to stop."
fi

echo ""
echo "---------------------------------------------------"
echo "SHUTDOWN COMPLETE"
echo "---------------------------------------------------"
