# tuwunel.sh
# Run with: ./mkportable.sh tuwunel.sh [--force]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

ALPINE_VERSION="3.23.0"
MOUNTS=()

app_build() {
    TUWUNEL_VERSION="1.7.0-r0"

    echo ">>> Writing /etc/os-release"
    cat > /etc/os-release <<EOF
NAME="tuwunel"
ID=tuwunel
VERSION_ID=${TUWUNEL_VERSION}
PRETTY_NAME="Tuwunel Matrix homeserver"
PORTABLE_PREFIXES=tuwunel
EOF

    echo ">>> Installing tuwunel..."
    apk add --repository http://dl-cdn.alpinelinux.org/alpine/edge/testing \
        "tuwunel=${TUWUNEL_VERSION}"
    apk purge cache

    echo ">>> Downloading tuwunel.service file..."
    mkdir -p /etc/systemd/system
    wget -q "https://raw.githubusercontent.com/matrix-construct/tuwunel/refs/tags/v${TUWUNEL_VERSION%-*}/rpm/tuwunel.service" \
        -O /etc/systemd/system/tuwunel.service
    # tuwunel.service expects /usr/sbin/tuwunel
    ln -fs /usr/bin/tuwunel /usr/sbin/tuwunel

    # to mount into from host
    mkdir -p /var/lib/tuwunel

    echo ">>> Done!"
}
