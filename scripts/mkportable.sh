#!/bin/bash
# mkportable.sh - Build systemd portable services from Alpine Linux
#
# Usage: ./mkportable.sh <app.sh> [--force]
#
# The app file must define:
#   app_build()   - build commands to run in the namespace
# Optional: MOUNTS[] (/inside=./outside), ALPINE_VERSION (3.23.0), BUILD_DIR (.mkportable)
# Output: <app>.raw (e.g., pyapp.sh produces pyapp.raw)
# Built-in mounts: /cache (persistent across builds)
#
# Requires: curl, tar, mksquashfs
# Security: User namespaces only—no root, no daemon, no host modification.

set -euo pipefail

_ALPINE_MIRROR="https://dl-cdn.alpinelinux.org/alpine"

_log() { echo ">>> $*"; }

_init() {
    if [[ -d "$BUILD_DIR/bin" ]] && [[ "${1:-}" != "--force" ]]; then
        _log "Image already initialized (use --force to rebuild)"
        return 0
    fi

    local branch="${ALPINE_VERSION%.*}"  # 3.23.0 -> 3.23
    local tarball="$CACHE_DIR/alpine-minirootfs-${ALPINE_VERSION}-x86_64.tar.gz"
    if [[ ! -f "$tarball" ]]; then
        _log "Downloading Alpine minirootfs ${ALPINE_VERSION}..."
        mkdir -p "$CACHE_DIR"
        curl -fsSL "${_ALPINE_MIRROR}/v${branch}/releases/x86_64/alpine-minirootfs-${ALPINE_VERSION}-x86_64.tar.gz" -o "$tarball"
    fi

    _log "Initializing Alpine rootfs..."
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    tar -xzf "$tarball" -C "$BUILD_DIR"

    mkdir -p "$BUILD_DIR"/{proc,sys,dev,run,tmp,usr/lib/systemd/system,var/cache/apk}
    ln -sf /var/cache/apk "$BUILD_DIR/etc/apk/cache"
    touch "$BUILD_DIR/etc/resolv.conf" "$BUILD_DIR/etc/machine-id"
    _log "Alpine rootfs ready"
}

_run() {
    local command="$1"; shift
    local mount_specs=("${@+"$@"}")
    local image_dir_abs cache_dir_abs
    image_dir_abs="$(realpath "$BUILD_DIR")"
    cache_dir_abs="$(realpath "$CACHE_DIR")"

    _log "Running $command() in namespace..."

    # Commands to run inside the namespace (built as a string, executed via bash -c)
    local setup="set -eu
        # pivot_root requires the new root to be a mount point
        mount --bind '$image_dir_abs' '$image_dir_abs'
        mount --bind /etc/resolv.conf '$image_dir_abs/etc/resolv.conf'
        mkdir -p '$cache_dir_abs/apk' '$image_dir_abs/var/cache/apk'
        mount --bind '$cache_dir_abs/apk' '$image_dir_abs/var/cache/apk'
        mkdir -p '$cache_dir_abs/build' '$image_dir_abs/cache'
        mount --bind '$cache_dir_abs/build' '$image_dir_abs/cache'"

    for spec in "${mount_specs[@]+"${mount_specs[@]}"}"; do
        local inside="${spec%%=*}" outside="${spec#*=}"
        setup+="
        mkdir -p '$image_dir_abs$inside'
        mount --bind '$(realpath "$outside")' '$image_dir_abs$inside'"
    done

    # pivot_root swaps the root filesystem (unlike chroot which just changes path lookup).
    # Old root moves to .pivot_old, then we unmount it - no way back to host filesystem.
    setup+="
        cd '$image_dir_abs'
        mkdir -p .pivot_old
        pivot_root . .pivot_old
        cd /
        /bin/umount -l /.pivot_old 2>/dev/null || true
        /bin/rmdir /.pivot_old 2>/dev/null || true
        export PATH=/bin:/sbin:/usr/bin:/usr/sbin HOME=/tmp TMPDIR=/tmp
        export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
        $command"

    # --user: new user namespace where we appear as root (but aren't on host)
    # --map-root-user: map our UID to 0 inside, so we can mount/pivot_root
    # --mount: private mount namespace, changes don't affect host
    unshare --user --map-root-user --mount bash -c "$setup"
}

_package() {
    local output="$1"
    _log "Packaging portable service..."
    mksquashfs "$BUILD_DIR" "$output" -noappend -all-root -comp xz
    _log "Created: $output ($(du -h "$output" | cut -f1))"
}

_main() {
    if [[ $# -eq 0 || ! -f "${1:-}" ]]; then
        echo "Usage: $0 <app.sh> [--force]" >&2
        echo "App file must define: app_build()" >&2
        exit 1
    fi

    local app_file="$1"; shift
    source "$app_file"

    : "${ALPINE_VERSION:=3.23.0}"
    : "${BUILD_DIR:=.mkportable}"
    : "${CACHE_DIR:=.cache}"

    [[ -v MOUNTS ]] || MOUNTS=()  # Ensure MOUNTS exists (can be empty)
    if ! declare -f app_build >/dev/null; then
        echo "App file must define: app_build()" >&2
        exit 1
    fi

    # Clean up partial builds on failure
    trap 'rm -rf "$BUILD_DIR"' ERR

    local image_name="${app_file%.sh}"
    image_name="${image_name##*/}"

    export -f app_build
    _init "${1:-}"
    for mount in "${MOUNTS[@]+"${MOUNTS[@]}"}"; do mkdir -p "${mount#*=}"; done
    _run app_build "${MOUNTS[@]+"${MOUNTS[@]}"}"
    _package "$image_name.raw"

    trap - ERR
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && _main "$@"
