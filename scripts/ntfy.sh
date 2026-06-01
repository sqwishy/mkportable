# ntfy.sh - Python portable service definition
# Run with: ./mkportable.sh ntfy.sh [--force]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

ALPINE_VERSION="3.23.0"
MOUNTS=()

app_build() {
    NTFY_VERSION="2.23.0"
    NTFY_FULLNAME="ntfy_${NTFY_VERSION}_linux_amd64"

    echo ">>> Downloading ntfy..."
    if [ ! -x "/cache/${NTFY_FULLNAME}/ntfy" ]; then
        wget -qO- "https://github.com/binwiederhier/ntfy/releases/download/v${NTFY_VERSION}/${NTFY_FULLNAME}.tar.gz" \
            | tar -xz -C /cache
    fi

    echo ">>> Installing files..."
    install "/cache/${NTFY_FULLNAME}/ntfy" /usr/bin/
    mkdir -p /etc/systemd/system
    cp "/cache/${NTFY_FULLNAME}/client/ntfy-client.service" /etc/systemd/system/
    cp "/cache/${NTFY_FULLNAME}/server/ntfy.service" /etc/systemd/system/

    # Portable service mount targets
    mkdir -p /var/lib/ntfy /etc/ntfy
    touch /etc/localtime

    cat > /etc/os-release <<EOF
NAME="ntfy"
ID=ntfy
VERSION_ID=${NTFY_VERSION}
PRETTY_NAME="ntfy UnifiedPush distributor"
PORTABLE_PREFIXES=ntfy
EOF

    echo ">>> Done!"
}
