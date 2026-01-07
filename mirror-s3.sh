#!/bin/sh
echo "Generating rclone config..."
TMPL="/etc/rclone.conf.tmpl"
if [ -n "$RCLONE_TMPL" ]; then
    echo "== USING CUSTOM TEMPLATE: $RCLONE_TMPL =="
    TMPL="$RCLONE_TMPL"
fi
cat $TMPL | envsubst > /etc/rclone.conf

# GPG encryption setup
if [ -n "$GPG_KEY_ID" ]; then
    echo "== GPG ENCRYPTION ENABLED (Key ID: $GPG_KEY_ID) =="
    
    # Import GPG key from environment if provided
    if [ -n "$GPG_PRIVATE_KEY" ]; then
        echo "=> Importing GPG private key..."
        echo "$GPG_PRIVATE_KEY" | gpg --batch --import
        if [ $? -eq 0 ]; then
            echo "=> GPG private key imported successfully"
        else
            echo "=> ERROR: Failed to import GPG private key"
            exit 1
        fi
    fi
    
    if [ -n "$GPG_PUBLIC_KEY" ]; then
        echo "=> Importing GPG public key..."
        echo "$GPG_PUBLIC_KEY" | gpg --batch --import
        if [ $? -eq 0 ]; then
            echo "=> GPG public key imported successfully"
        else
            echo "=> ERROR: Failed to import GPG public key"
            exit 1
        fi
    fi
    
    # Verify the key exists
    if ! gpg --list-keys "$GPG_KEY_ID" > /dev/null 2>&1; then
        echo "=> ERROR: GPG key $GPG_KEY_ID not found in keyring"
        echo "=> Please import the key or check GPG_KEY_ID"
        exit 1
    fi
    
    # Set up GPG trust (needed for encryption)
    echo "=> Setting up GPG trust for key $GPG_KEY_ID"
    echo "$GPG_KEY_ID:6:" | gpg --batch --import-ownertrust
    
    # Create temporary directory for GPG operations
    GPG_TEMP_DIR="/tmp/gpg_sync"
    mkdir -p "$GPG_TEMP_DIR"
    
    GPG_ENABLED=true
else
    echo "== GPG ENCRYPTION DISABLED (no GPG_KEY_ID set) =="
    GPG_ENABLED=false
fi

# GPG encryption functions
encrypt_and_sync() {
    local source="$1"
    local destination="$2"
    local compare_dest="$3"
    
    echo "=> Syncing with GPG encryption..."
    
    # Create a temporary local directory for encrypted files
    local encrypted_dir="$GPG_TEMP_DIR/encrypted"
    mkdir -p "$encrypted_dir"
    
    # Download files from source
    echo "=> Downloading files from source..."
    rclone --progress $BW_LIMIT --config=/etc/rclone.conf sync "$source" "$GPG_TEMP_DIR/plain"
    
    # Encrypt all files
    echo "=> Encrypting files with GPG..."
    find "$GPG_TEMP_DIR/plain" -type f | while read file; do
        relative_path="${file#$GPG_TEMP_DIR/plain/}"
        encrypted_file="$encrypted_dir/$relative_path.gpg"
        mkdir -p "$(dirname "$encrypted_file")"
        gpg --batch --trust-model always --encrypt --recipient "$GPG_KEY_ID" --output "$encrypted_file" "$file"
    done
    
    # Upload encrypted files to destination
    echo "=> Uploading encrypted files to destination..."
    if [ -n "$compare_dest" ]; then
        rclone --progress $BW_LIMIT --config=/etc/rclone.conf sync "$encrypted_dir" "$destination" --compare-dest="$compare_dest"
    else
        rclone --progress $BW_LIMIT --config=/etc/rclone.conf sync "$encrypted_dir" "$destination"
    fi
    
    # Clean up temporary files
    rm -rf "$GPG_TEMP_DIR/plain" "$encrypted_dir"
}

echo "Running rclone sync..."
DEBUG=""

if [[ "$MINIO_DEBUG" == "1" ]]; then
    echo "== DEBUG ENABLED =="
    DEBUG="--debug"
fi

if [[ "$MINIO_OVERWRITE" == "1" ]]; then
    echo "== OVERWRITE ENABLED =="
    OVERWRITE="--overwrite"
fi

BW_LIMIT=""

if [ -n "$BANDWIDTH_LIMIT" ]; then
  echo "== BANDWIDTH LIMITER ENABLED ($BANDWIDTH_LIMIT) =="
  BW_LIMIT="--bwlimit=$BANDWIDTH_LIMIT"
fi

if [ -n "$DO_ATOMIC" ]; then
  echo "== ATOMIC MODE ENABLED =="
  if [ "$GPG_ENABLED" = true ]; then
    encrypt_and_sync "sync_src:${SOURCE_BUCKET}" "sync_dst:${DESTINATION_TMP_BUCKET}" "sync_dst:${DESTINATION_BUCKET}"
    echo "=> Moving encrypted files..."
    rclone --config=/etc/rclone.conf move sync_dst:${DESTINATION_TMP_BUCKET} sync_dst:${DESTINATION_BUCKET}
  else
    echo "=> Syncing from source..."
    rclone --progress $BW_LIMIT --config=/etc/rclone.conf sync sync_src:${SOURCE_BUCKET} sync_dst:${DESTINATION_TMP_BUCKET} --compare-dest=sync_dst:${DESTINATION_BUCKET}
    echo "=> Moving..."
    rclone --config=/etc/rclone.conf move sync_dst:${DESTINATION_TMP_BUCKET} sync_dst:${DESTINATION_BUCKET}
  fi
else
  echo "=> Syncing from source..."
  if [ "$GPG_ENABLED" = true ]; then
    encrypt_and_sync "sync_src:${SOURCE_BUCKET}" "sync_dst:${DESTINATION_BUCKET}"
  else
    rclone --progress $BW_LIMIT --config=/etc/rclone.conf sync sync_src:${SOURCE_BUCKET} sync_dst:${DESTINATION_BUCKET}
  fi
fi

# Clean up GPG temp directory if it exists
if [ "$GPG_ENABLED" = true ]; then
    rm -rf "$GPG_TEMP_DIR"
fi
curl ${HEALTHCHECK_URL}
