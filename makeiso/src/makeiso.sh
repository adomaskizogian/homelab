#!/bin/bash
set -uo pipefail

if [ -z "${WORK_DIR:-}" ]; then
    TEMP_DIR=$(mktemp -d)
    WORK_DIR="$TEMP_DIR"

    cleanup() {
        if [ -d "$TEMP_DIR" ]; then
            echo "Cleaning up temporary directory: $TEMP_DIR"
            rm -rf "$TEMP_DIR"
        fi
    }

    trap cleanup EXIT
else
    WORK_DIR="${WORK_DIR%/}"
    mkdir -p "$WORK_DIR"
fi

VERSION="${VERSION:-13.4.0}"
OUT_DIR="${OUT_DIR:-.}"

ISO_PATH="$WORK_DIR/debian-$VERSION-amd64-netinst.iso"
SHA512_SIGN_PATH="$WORK_DIR/SHA512SUMS.sign"
SHA512_PATH="$WORK_DIR/SHA512SUMS"

download() {
    local filename="$1"
    local out="$2"

    if [ -z "$filename" ]; then
        echo "Error: filename relative to debian download url is required"
        return 1
    fi

    if [ -z "$out" ]; then
        echo "Error: output path is required"
        return 1
    fi

    if [ -f "$out" ]; then
        echo "Skipping download: $out already exists"
        return
    fi

    local url="https://cdimage.debian.org/debian-cd/$VERSION/amd64/iso-cd/$filename"
    echo "Downloading $url"
    
    if ! wget --output-document="$out" --no-verbose "$url"; then
        echo "Error: Failed to download $url"
        return 1
    fi
}

pull() {
    for path in "$ISO_PATH" "$SHA512_SIGN_PATH" "$SHA512_PATH"; do
        local file="${path##*/}"
        if ! download "$file" "$path"; then
            return 1
        fi
    done
}

verify() {
    for path in "$ISO_PATH" "$SHA512_SIGN_PATH" "$SHA512_PATH"; do
        if [ ! -f "$path" ]; then
            echo "Error: $path does not exist"
            return 1
        fi
    done

    echo "Importing Debian CD signing key..."

    local gpg_home
    gpg_home="$WORK_DIR/gpghome"
    mkdir -p "$gpg_home"
    chmod 700 "$gpg_home"

    local debian_key='DF9B9C49EAA9298432589D76DA87E80D6294BE9B'
    if ! GNUPGHOME="$gpg_home" gpg --keyserver hkps://keyring.debian.org:443 \
        --recv-keys "$debian_key" ; then
        echo "Error: Failed to import Debian signing key from keyserver"
        return 1
    fi
    
    echo "Import done"

    echo "Verifying PGP signature of ${SHA512_PATH##*/}..."

    if ! GNUPGHOME="$gpg_home" gpg --verify \
        --trusted-key "$debian_key" \
        "$SHA512_SIGN_PATH" "$SHA512_PATH" \
        2>/dev/null; then
        echo "Error: PGP signature verification failed"
        return 1
    fi
    echo "PGP signature is valid"

    echo "Verifying ISO hash..."

    local expected_hash
    expected_hash=$(grep "${ISO_PATH##*/}" "$SHA512_PATH" | awk '{print $1}')
    if [ -z "$expected_hash" ]; then
        echo "Error: Could not find hash for $ISO_PATH in $SHA512_PATH"
        return 1
    fi

    local actual_hash
    actual_hash=$(sha512sum "$ISO_PATH" | awk '{print $1}')
    echo "ISO sha512: $actual_hash"

    if [ "$expected_hash" = "$actual_hash" ]; then
        echo "ISO hash verification passed"
    else
        echo "Error: ISO hash mismatch"
        return 1
    fi
}

repack() {
    if [ ! -f "$ISO_PATH" ]; then
        echo "Error: $ISO_PATH does not exist"
        return 1
    fi

    for f in preseed.cfg post-install.sh grub.cfg; do
        if [ ! -f "$f" ]; then
            echo "Error: required file $f not found"
            return 1
        fi
    done

    echo "Extracting ISO contents..."

    local extracted_iso_dir="$WORK_DIR/extractediso"
    mkdir -p "$extracted_iso_dir"

    if ! xorriso -report_about NEVER \
            -osirrox on \
            -indev "$ISO_PATH" \
            -extract / \
            "$extracted_iso_dir"; then
        echo "Error: Failed to extract ISO contents"
        return 1
    fi

    chmod +w -R "$extracted_iso_dir/install.amd/"

    echo "Injecting preseed into initrd..."

    if ! gunzip "$extracted_iso_dir/install.amd/initrd.gz"; then
        echo "Error: Failed to gunzip initrd"
        return 1
    fi

    if ! echo preseed.cfg | cpio -H newc -o -A -F "$extracted_iso_dir/install.amd/initrd"; then
        echo "Error: Failed to inject preseed.cfg into initrd"
        return 1
    fi

    if ! gzip "$extracted_iso_dir/install.amd/initrd"; then
        echo "Error: Failed to gzip initrd"
        return 1
    fi

    chmod -w -R "$extracted_iso_dir/install.amd/"

    echo "Copying bootloader configuration files..."

    cp -f preseed.cfg "$extracted_iso_dir/preseed.cfg"
    cp -f post-install.sh "$extracted_iso_dir/post-install.sh"
    cp -f grub.cfg "$extracted_iso_dir/boot/grub/grub.cfg"

    echo "Files copied"

    echo "Updating md5sum.txt..."

    chmod +w "$extracted_iso_dir/md5sum.txt"
    ( cd "$extracted_iso_dir" && find . -type f ! -name md5sum.txt -print0 | xargs -0 md5sum > md5sum.txt.tmp && mv md5sum.txt.tmp md5sum.txt )
    chmod -w "$extracted_iso_dir/md5sum.txt"

    echo "Creating new ISO file..."

    local output_iso_name="preseed-debian-${VERSION}-amd64-netinst.iso"

    if ! xorriso \
        -as mkisofs \
        -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
        -c isolinux/boot.cat \
        -b isolinux/isolinux.bin \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        -eltorito-alt-boot \
        -e boot/grub/efi.img \
        -no-emul-boot \
        -isohybrid-gpt-basdat \
        -o "$OUT_DIR/$output_iso_name" \
        "$extracted_iso_dir"; then

        echo "Error: Failed to create new ISO file"
        return 1
    fi

    echo "New ISO file created: $OUT_DIR/$output_iso_name"
}

pull && verify && repack
