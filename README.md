# mkportable

Build Python apps as systemd portable services using Linux user namespaces.

The demo builds a Django app with scipy and scikit-sparse (requires gcc, openblas, suitesparse) into a 99MB squashfs image.

## Build

```
make              # build pyapp.raw (squashfs)
make pyapp.tar    # build OCI tarball
make force        # rebuild from scratch
```

## Deploy

```
sudo portablectl attach ./pyapp.raw
sudo systemctl start pyapp
curl http://localhost:8000
```

## Structure

- `scripts/mkportable.sh` - generic build tool (~130 lines)
- `scripts/pyapp.sh` - app-specific build definition
- `portable/` - systemd service files and os-release

## Requirements

Linux with user namespaces, curl, tar, mksquashfs. buildah for OCI output.
