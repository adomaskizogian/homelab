#!/bin/bash
set -euo pipefail

VERSION="${VERSION:-13.4.0}"

BUILDER_NAME="makeiso-$$"

docker buildx create --name "$BUILDER_NAME" --use
trap 'docker buildx rm "$BUILDER_NAME"' EXIT

docker buildx build \
    --builder "$BUILDER_NAME" \
    --build-arg VERSION="$VERSION" \
    --output . \
    --target out \
    .
