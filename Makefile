all: help

.PHONY: docker-build-and-push
# target: docker-build-and-push - Build and push Docker image
docker-build-and-push:
	@docker buildx create --name smsaero_bash --use || docker buildx use smsaero_bash
	@docker buildx build --platform linux/amd64,linux/arm64 -t 'smsaero/smsaero_bash:latest' . -f Dockerfile --push

.PHONY: docker-shell
# target: docker-shell - Run a shell inside the Docker container
docker-shell:
	@docker run -it --rm 'smsaero/smsaero_bash:latest' bash

.PHONY: help
# target: help - Display callable targets
help:
	@egrep "^# target:" [Mm]akefile | sed -e 's/^# target: //g'
