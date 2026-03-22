# makeiso

Builds a preseeded Debian netinstall ISO with automated installation settings baked in. amd64 only.

## What it does

1. Downloads the official Debian netinstall ISO
2. Verifies it against the SHA512 checksum, GPG-signed by the Debian CD signing key
3. Injects `preseed.cfg` into the initrd so the installer runs unattended
4. Repacks and outputs `preseed-debian-<VERSION>-amd64-netinst.iso`

The build runs inside Docker so no local dependencies are needed.

## How to run

```sh
./rundocker.sh
```

## Bumping the Debian version

For minor or patch releases, just pass the env var:

```sh
VERSION=13.5.0 ./rundocker.sh
```

For a major release with a new codename:

1. Update the base image in `Dockerfile`: `FROM debian:14`
2. Update suite and codename in `src/preseed.cfg` e.g. trixie -> forky
3. Update the default `VERSION` in `rundocker.sh` and `Dockerfile`
