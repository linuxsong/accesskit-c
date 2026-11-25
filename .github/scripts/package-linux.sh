#!/bin/sh
# Run in the pinned Rust/GNU Linux image from the release workflow.
set -eu

target=$1
archive=$2
output=$3
export CARGO_TARGET_DIR=/tmp/accesskit-target

test "$(rustc -vV | sed -n 's/^host: //p')" = "$target"
cargo build --release --locked --target "$target"

package=$(mktemp -d)
strip --strip-unneeded -o "$package/libaccesskit.so" "$CARGO_TARGET_DIR/$target/release/libaccesskit.so"
cp LICENSE-APACHE LICENSE-MIT LICENSE.chromium "$package/"
printf '%s\n' "$VERSION" > "$package/VERSION"
chmod 644 "$package"/*
tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner -C "$package" \
    -czf "$output/$archive" LICENSE-APACHE LICENSE-MIT LICENSE.chromium VERSION libaccesskit.so

{
    printf 'AccessKit C source: %s\n' "$SOURCE_COMMIT"
    awk '/^name = "accesskit_unix"$/{getline; getline; print "AccessKit Unix source: " $0; exit}' Cargo.lock
    printf 'Cargo.lock SHA-256: %s\n' "$(sha256sum Cargo.lock | cut -d' ' -f1)"
    printf 'Build image: %s\n' "$BUILD_IMAGE"
    printf 'Build command: cargo build --release --locked --target %s\n' "$target"
    rustc -vV
    cargo -V
    getconf GNU_LIBC_VERSION
    strip --version | sed -n '1p'
    printf 'Highest referenced glibc symbol: %s\n' "$(
        readelf --version-info "$package/libaccesskit.so" |
        grep -o 'GLIBC_[0-9.]*' | sort -V | tail -1
    )"
    printf 'libaccesskit.so SHA-256: %s\n' "$(sha256sum "$package/libaccesskit.so" | cut -d' ' -f1)"
} > "$output/build.txt"
