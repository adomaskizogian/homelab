FROM debian:13.3 AS build

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        wget \
        gnupg \
        xorriso \
        cpio \
        gzip \
        ca-certificates \
        isolinux

WORKDIR /makeiso

COPY src/ ./

ARG VERSION

RUN --mount=type=cache,target=/cache \
    mkdir -p /out && \
    WORK_DIR=/cache OUT_DIR=/out VERSION=$VERSION bash makeiso.sh

FROM scratch AS out
COPY --from=build /out/*.iso .
