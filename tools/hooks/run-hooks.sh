#!/bin/sh
# Usage: run-hooks.sh <pre-commit|pre-push>
# Runs the repo's pre-commit hooks inside a container.
set -eu

STAGE="${1:?usage: run-hooks.sh <pre-commit|pre-push>}"
IMAGE="encore-hooks"
REPO_ROOT="$(git rev-parse --show-toplevel)"

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    docker build -t "$IMAGE" "$REPO_ROOT/tools/hooks"
fi

# MSYS_NO_PATHCONV stops Git Bash on Windows from rewriting /repo into a Windows path.
if [ "$STAGE" = "pre-push" ]; then
    # Nothing is staged at push time, so check every file.
    set -- run --all-files --hook-stage pre-push
else
    set -- run --hook-stage pre-commit
fi

MSYS_NO_PATHCONV=1 docker run --rm \
    -v "$REPO_ROOT:/repo" \
    -v encore-precommit-cache:/home/hooks/.cache/pre-commit \
    "$IMAGE" "$@"
