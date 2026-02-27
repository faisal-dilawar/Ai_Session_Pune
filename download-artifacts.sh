#!/bin/bash

# Smart script to download CI artifacts only when they have changed.
# Requirements: GitHub CLI (gh), jq, and curl.

set -e

BACKEND_REPO="faisal-dilawar/shopizer"
ADMIN_REPO="faisal-dilawar/shopizer-admin"
SHOP_REPO="faisal-dilawar/shopizer-shop-reactjs"

echo "===================================================="
echo "SYNCHRONIZING ARTIFACTS"
echo "===================================================="

mkdir -p ./ci-artifacts

# Function to download with Smart Sync
download_smart() {
    local repo=$1
    local name=$2
    local path=$3
    local marker_file="./ci-artifacts/.${name}_id"
    
    echo "--> [ $name ] Checking for updates..."
    
    # 1. Get the latest successful run ID
    RUN_ID=$(gh run list --repo "$repo" --branch ai_session --status success --limit 1 --json databaseId -q '.[0].databaseId')
    
    if [ -z "$RUN_ID" ] || [ "$RUN_ID" == "null" ]; then
        echo "    WARNING: No successful builds found for $name. Skipping."
        return
    fi

    # 2. Check if we already have this version
    if [ -f "$marker_file" ] && [ "$(cat "$marker_file")" == "$RUN_ID" ]; then
        # Double check the file actually exists on disk
        if [ "$name" == "shopizer-backend" ] && [ -f "./ci-artifacts/shopizer.jar" ]; then
            echo "    Already up to date (Run ID: $RUN_ID). Skipping download."
            return
        elif [ -d "./ci-artifacts/$path" ]; then
            echo "    Already up to date (Run ID: $RUN_ID). Skipping download."
            return
        fi
    fi

    # 3. Get Metadata
    ARTIFACT_META=$(gh api "repos/$repo/actions/runs/$RUN_ID/artifacts" --jq ".artifacts[] | select(.name==\"$name\")")
    ARTIFACT_ID=$(echo "$ARTIFACT_META" | jq -r '.id')
    TOTAL_BYTES=$(echo "$ARTIFACT_META" | jq -r '.size_in_bytes')
    TOTAL_MB=$(echo "scale=2; $TOTAL_BYTES / 1024 / 1024" | bc)

    echo "    New version found: $RUN_ID | Size: ${TOTAL_MB}MB"
    
    TOKEN=$(gh auth token)
    local target_zip="./ci-artifacts/${name}_temp.zip"
    
    echo "    Starting download..."
    
    curl -sL --retry 5 --retry-delay 5 --connect-timeout 30 \
         -H "Authorization: Bearer $TOKEN" \
         -H "Accept: application/vnd.github+json" \
         "https://api.github.com/repos/$repo/actions/artifacts/$ARTIFACT_ID/zip" \
         -o "$target_zip" &
    CURL_PID=$!

    # Status monitoring loop
    while kill -0 $CURL_PID 2>/dev/null; do
        if [ -f "$target_zip" ]; then
            CURRENT_BYTES=$(stat -f%z "$target_zip" 2>/dev/null || stat -c%s "$target_zip" 2>/dev/null || echo "0")
            PERCENT=$(echo "scale=0; ($CURRENT_BYTES * 100) / $TOTAL_BYTES" | bc 2>/dev/null || echo "0")
            CURRENT_MB=$(echo "scale=2; $CURRENT_BYTES / 1024 / 1024" | bc)
            echo "    [ Status ] ${CURRENT_MB}MB / ${TOTAL_MB}MB (${PERCENT}%)"
        fi
        sleep 5
    done

    if ! wait $CURL_PID; then
        echo "    ERROR: Download failed."
        exit 1
    fi
    
    # 4. Extract and Clean
    echo "    Extracting..."
    mkdir -p "./ci-artifacts/$path"
    unzip -qo "$target_zip" -d "./ci-artifacts/$path"
    rm "$target_zip"
    
    # Save the Run ID to the marker file
    echo "$RUN_ID" > "$marker_file"
    echo "    Completed $name."
}

# Execute Smart Downloads
download_smart "$BACKEND_REPO" "shopizer-backend" "."
download_smart "$ADMIN_REPO" "shopizer-admin" "shopizer-admin"
download_smart "$SHOP_REPO" "shop-react" "shop-react"

# Final organization for Backend
if [ -f "./ci-artifacts/shopizer-backend/shopizer.jar" ]; then
    mv ./ci-artifacts/shopizer-backend/shopizer.jar ./ci-artifacts/
    rm -rf ./ci-artifacts/shopizer-backend
fi

echo "===================================================="
echo "SYNC COMPLETE"
echo "===================================================="
