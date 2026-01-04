# pyapp.sh - Python portable service definition
# Run with: ./mkportable.sh pyapp.sh [--force]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

ALPINE_VERSION="3.23.0"
MOUNTS=(
    "/src=$PROJECT_DIR/app"
    "/portable=$PROJECT_DIR/portable"
)

app_build() {
    BUILD_DEPS="gcc g++ make musl-dev suitesparse-dev openblas-dev"
    RUNTIME_DEPS="suitesparse"

    echo ">>> Copying app source..."
    mkdir -p /opt/app
    cp -a /src/. /opt/app/
    rm -rf /opt/app/.venv /opt/app/.git /opt/app/__pycache__

    echo ">>> Copying portable service files..."
    cp /portable/os-release /usr/lib/os-release
    cp /portable/*.service /usr/lib/systemd/system/
    mkdir -p /var/lib/pyapp

    echo ">>> Installing Alpine packages..."
    apk add --virtual .build-deps $BUILD_DEPS
    apk add $RUNTIME_DEPS

    echo ">>> Installing uv..."
    if [ ! -x /cache/uv ]; then
        wget -qO- https://github.com/astral-sh/uv/releases/latest/download/uv-x86_64-unknown-linux-musl.tar.gz \
            | tar -xz -C /cache --strip-components=1
    fi
    export PATH="/cache:$PATH"

    echo ">>> Building Python app..."
    export UV_PYTHON_INSTALL_DIR=/opt/python UV_CACHE_DIR=/cache UV_LINK_MODE=copy
    export CFLAGS='-I/usr/include/suitesparse/suitesparse'
    export CPPFLAGS='-I/usr/include/suitesparse/suitesparse'
    cd /opt/app
    uv sync --no-dev --compile-bytecode

    echo ">>> Removing build dependencies..."
    apk del .build-deps

    echo ">>> Cleaning up..."
    chmod -R a+rX /opt/app /opt/python
    rm -f /opt/python/*/lib/python*/EXTERNALLY-MANAGED

    echo ">>> Done!"
}
