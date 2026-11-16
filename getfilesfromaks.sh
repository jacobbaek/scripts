#!/usr/bin/env bash
set -euo pipefail

# ===== Dependency Check =====
if ! command -v kubectl >/dev/null 2>&1; then
    echo "[ERROR] kubectl command not found." >&2
    echo "[ERROR] Please install kubectl and make sure it is available in PATH." >&2
    exit 1
fi

echo "[INFO] kubectl found: $(command -v kubectl)"
echo

# ===== User Input =====

read -r -p "Enter AKS node name: " NODE_NAME

if [[ -z "$NODE_NAME" ]]; then
    echo "[ERROR] Node name cannot be empty." >&2
    exit 1
fi

read -r -p "Enter source directory on the node (e.g. /var/log): " SOURCE_DIR

if [[ -z "$SOURCE_DIR" ]]; then
    echo "[ERROR] Source directory cannot be empty." >&2
    exit 1
fi

# Require an absolute path
if [[ "$SOURCE_DIR" != /* ]]; then
    echo "[ERROR] Source directory must be an absolute path." >&2
    echo "[ERROR] Example: /var/log/azure" >&2
    exit 1
fi

# Remove trailing slash except for /
if [[ "$SOURCE_DIR" != "/" ]]; then
    SOURCE_DIR="${SOURCE_DIR%/}"
fi

# ===== Configuration =====

OUTPUT_DIR="./aks-node-files"
DEBUG_IMAGE="ubuntu:22.04"

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
ARCHIVE_NAME="${NODE_NAME}_${TIMESTAMP}.tar.gz"

mkdir -p "$OUTPUT_DIR"

echo
echo "=========================================="
echo " AKS Node File Collection"
echo "=========================================="
echo "[INFO] Node        : $NODE_NAME"
echo "[INFO] Source      : $SOURCE_DIR"
echo "[INFO] Local output: $OUTPUT_DIR/$ARCHIVE_NAME"
echo "=========================================="
echo

DEBUG_POD=""

cleanup() {
    if [[ -n "$DEBUG_POD" ]]; then
        echo "[INFO] Cleaning up debug pod: $DEBUG_POD"

        kubectl delete pod "$DEBUG_POD" \
            --ignore-not-found \
            --wait=false >/dev/null 2>&1 || true
    fi
}

trap cleanup EXIT


# ===== Validate Node =====

echo "[INFO] Checking node: $NODE_NAME"

if ! kubectl get node "$NODE_NAME" >/dev/null 2>&1; then
    echo "[ERROR] Node not found: $NODE_NAME" >&2
    exit 1
fi


# ===== Create Debug Pod =====

# AKS node filesystem is mounted under /host
HOST_SOURCE_DIR="/host${SOURCE_DIR}"

echo "[INFO] Creating debug pod..."

kubectl debug "node/${NODE_NAME}" \
    --image="$DEBUG_IMAGE" \
    --profile=sysadmin \
    --container=node-copy \
    -- \
    sleep 3600 >/dev/null


# ===== Find Debug Pod =====

DEBUG_POD=$(
    kubectl get pods \
        --field-selector="spec.nodeName=${NODE_NAME}" \
        -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.creationTimestamp}{"\n"}{end}' |
    grep '^node-debugger-' |
    sort -k2 |
    tail -1 |
    cut -f1
)

if [[ -z "$DEBUG_POD" ]]; then
    echo "[ERROR] Could not find debug pod." >&2
    exit 1
fi

echo "[INFO] Debug pod: $DEBUG_POD"

kubectl wait \
    --for=condition=Ready \
    "pod/${DEBUG_POD}" \
    --timeout=120s


# ===== Validate Source Directory =====

echo "[INFO] Checking source directory: $SOURCE_DIR"

if ! kubectl exec "$DEBUG_POD" -c node-copy -- \
    test -d "$HOST_SOURCE_DIR"; then

    echo "[ERROR] Directory does not exist on node: $SOURCE_DIR" >&2
    exit 1
fi


# ===== Collect Node Information =====

echo "[INFO] Collecting node information..."

kubectl exec "$DEBUG_POD" -c node-copy -- sh -c '
    rm -rf /tmp/node-info
    mkdir -p /tmp/node-info

    #
    # OS release information
    #
    if [ -f /host/etc/os-release ]; then
        cp /host/etc/os-release /tmp/node-info/os-release.txt
    else
        echo "os-release not found" \
            > /tmp/node-info/os-release.txt
    fi


    #
    # Kernel information
    #
    uname -a > /tmp/node-info/kernel-info.txt
    uname -r > /tmp/node-info/kernel-version.txt

    #
    # aznfs package information
    #
    if [ -x /host/usr/bin/dpkg ]; then

        chroot /host /usr/bin/dpkg -s aznfs \
            > /tmp/node-info/aznfs-package.txt 2>&1 || {

            echo "aznfs package is not installed or dpkg could not find it." \
                > /tmp/node-info/aznfs-package.txt
        }

    else
        echo "dpkg not found on the node." \
            > /tmp/node-info/aznfs-package.txt
    fi
'


# ===== Create Archive =====

echo "[INFO] Creating collection..."

kubectl exec "$DEBUG_POD" -c node-copy -- sh -c "
    rm -rf /tmp/collection
    mkdir -p /tmp/collection/data

    #
    # Copy source directory recursively.
    # Includes all files and subdirectories.
    #
    cp -a \"${HOST_SOURCE_DIR}/.\" /tmp/collection/data/

    #
    # Add node diagnostic information.
    #
    cp -a /tmp/node-info /tmp/collection/

    #
    # Create tar.gz
    #
    tar -C /tmp/collection \
        -czf \"/tmp/${ARCHIVE_NAME}\" .
"


# ===== Copy Archive to Local =====

echo "[INFO] Copying archive to local machine..."

kubectl cp \
    "${DEBUG_POD}:/tmp/${ARCHIVE_NAME}" \
    "${OUTPUT_DIR}/${ARCHIVE_NAME}" \
    -c node-copy


# ===== Completed =====

echo
echo "=========================================="
echo "[SUCCESS] Collection completed"
echo "=========================================="
echo "Node   : $NODE_NAME"
echo "Source : $SOURCE_DIR"
echo "Archive: ${OUTPUT_DIR}/${ARCHIVE_NAME}"
echo "=========================================="
