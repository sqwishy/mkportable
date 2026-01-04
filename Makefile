.PHONY: all force clean clean-all help

IMAGE_NAME := pyapp

all: $(IMAGE_NAME).raw

help:
	@echo "make            - build $(IMAGE_NAME).raw (squashfs)"
	@echo "make $(IMAGE_NAME).tar - build OCI tarball"
	@echo "make force      - rebuild from scratch"
	@echo "make clean      - remove build outputs"
	@echo "make clean-all  - remove outputs and cache"

$(IMAGE_NAME).raw: scripts/pyapp.sh scripts/mkportable.sh app/* portable/*
	./scripts/mkportable.sh scripts/pyapp.sh

$(IMAGE_NAME).tar: .mkportable
	@rm -f $@
	@ctr=$$(buildah from scratch) && \
	buildah add $$ctr .mkportable / && \
	buildah config --workingdir /opt/app $$ctr && \
	buildah config --entrypoint '["/opt/app/.venv/bin/python", "manage.py", "runserver", "0.0.0.0:8000"]' $$ctr && \
	buildah commit $$ctr $(IMAGE_NAME):latest && \
	buildah push $(IMAGE_NAME):latest docker-archive:$@ && \
	buildah rm $$ctr
	@echo "Created $@"

force:
	./scripts/mkportable.sh scripts/pyapp.sh --force

clean:
	rm -f $(IMAGE_NAME).raw $(IMAGE_NAME).tar

clean-all: clean
	rm -rf .mkportable .cache
