#!/bin/sh
# ak3-hw-changer.sh — Turn a standard AnyKernel3 into a Huawei/Honor AK3
#
# Author: apk0mix5900 <https://github.com/apk0mix5900/ak3-huawei-changer>
# SPDX-License-Identifier: GPL-2.0
#
# This script converts a standard AnyKernel3 tree (placed in ./ak3/)
# into a version compatible with Huawei/Honor devices that use a
# split-boot (kernel + ramdisk) partition layout.
#
# It performs three actions on ./ak3/:
#   1. Copies hw-hn-flash.sh into the AK3 root
#   2. Rewrites the dump_boot/write_boot call in anykernel.sh
#      into a split-boot aware branch
#   3. Fixes file permissions and packages the result as a zip

set -e

# ---- config ----
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SCRIPT_NAME=$(basename "$0")
AK3_DIR="$SCRIPT_DIR/ak3"
FLASH_HELPER="$SCRIPT_DIR/hw-hn-flash.sh"

# ---- helpers ----
say()  { printf '%s\n' "$*"; }
warn() { printf '[warn] %s\n' "$*" >&2; }
die()  { printf '[error] %s\n' "$*" >&2; exit 1; }

usage_short() {
    say "$SCRIPT_NAME — Turn a standard AnyKernel3 into a Huawei/Honor AK3"
    say ""
    say "Usage:"
    say "  sh $SCRIPT_NAME --help      Show full help"
    say "  sh $SCRIPT_NAME --check     Check ./ak3/ layout"
    say "  sh $SCRIPT_NAME --change    Convert and package"
    say ""
    say "Run --help for details."
}

usage_full() {
    say "$SCRIPT_NAME — Turn a standard AnyKernel3 into a Huawei/Honor AK3"
    say ""
    say "Usage:"
    say "  sh $SCRIPT_NAME [OPTIONS]"
    say ""
    say "Options:"
    say "  --help, -h          Show this help and exit"
    say "  --check             Check whether ak3/anykernel.sh exists"
    say "  --change            Convert ak3/ and package as ak3-<timestamp>-hw-hn.zip"
    say "  --name <filename>   Output filename (only valid with --change)"
    say ""
    say "Layout expected:"
    say "  ./$SCRIPT_NAME"
    say "  ./hw-hn-flash.sh        (in the same directory as this script)"
    say "  ./ak3/                  (extracted standard AnyKernel3)"
    say "  ./ak3/anykernel.sh      (required)"
    say ""
    say "Examples:"
    say "  # 1. Extract a standard AK3 into ./ak3/"
    say "  mkdir ak3 && cd ak3 && unzip ~/AnyKernel3.zip && cd .."
    say ""
    say "  # 2. Check the layout"
    say "  sh $SCRIPT_NAME --check"
    say ""
    say "  # 3. Convert and package"
    say "  sh $SCRIPT_NAME --change"
    say ""
    say "  # 4. Custom output name"
    say "  sh $SCRIPT_NAME --change --name ak3-hw-p9-eva.zip"
    say ""
    say "Author: apk0mix5900 <https://github.com/apk0mix5900/ak3-huawei-changer>"
}

# ---- check: only looks for ak3/anykernel.sh ----
do_check() {
    say "[check] Looking for ak3/anykernel.sh ..."
    if [ -f "$AK3_DIR/anykernel.sh" ]; then
        say "[check] OK"
        say "[check]"
        say "[check] All checks passed."
        say "[check] You can now run: sh $SCRIPT_NAME --change"
        return 0
    fi
    say "[check] NOT FOUND"
    say "[check]"
    say "[check] ERROR: $AK3_DIR/anykernel.sh not found."
    say "[check] Extract a standard AnyKernel3 into ./ak3/ first."
    return 1
}

# ---- fix permissions of scripts and binaries inside ak3/ ----
fix_permissions() {
    say "[change] Fixing file permissions ..."

    # shell scripts anywhere under ak3/
    find "$AK3_DIR" -type f -name '*.sh' -exec chmod 755 {} \; 2>/dev/null || true

    # AK3 tools that must be executable
    [ -d "$AK3_DIR/tools" ] && chmod 755 "$AK3_DIR"/tools/* 2>/dev/null || true

    # update-binary entry point
    [ -f "$AK3_DIR/META-INF/com/google/android/update-binary" ] && \
        chmod 755 "$AK3_DIR/META-INF/com/google/android/update-binary" || true

    # patch.d / patch.d-env
    [ -d "$AK3_DIR/patch.d" ] && chmod 755 "$AK3_DIR"/patch.d/* 2>/dev/null || true
    [ -d "$AK3_DIR/patch.d-env" ] && chmod 755 "$AK3_DIR"/patch.d-env/* 2>/dev/null || true

    say "[change]   done"
}

# ---- copy hw-hn-flash.sh into ak3/ ----
copy_helper() {
    [ -f "$FLASH_HELPER" ] || die "$FLASH_HELPER not found (should be next to $SCRIPT_NAME)"
    say "[change] Copying hw-hn-flash.sh into ak3/ ..."
    cp -f "$FLASH_HELPER" "$AK3_DIR/hw-hn-flash.sh"
    chmod 755 "$AK3_DIR/hw-hn-flash.sh"
    say "[change]   done"
}

# ---- patch anykernel.sh ----
patch_anykernel() {
    AK="$AK3_DIR/anykernel.sh"
    TS=$(date +%Y%m%d-%H%M%S)

    # skip if already converted
    if grep -q 'hw-hn-flash.sh' "$AK" 2>/dev/null; then
        warn "anykernel.sh already references hw-hn-flash.sh — skipping patch"
        return 0
    fi

    # look for the dump_boot / write_boot pair
    if ! grep -q 'dump_boot' "$AK" || ! grep -q 'write_boot' "$AK"; then
        die "Could not find dump_boot / write_boot in anykernel.sh"
    fi

    say "[change] Patching ak3/anykernel.sh ..."

    # backup
    cp -f "$AK" "$AK.orig-$TS"
    say "[change]   Backup: anykernel.sh.orig-$TS"

    # replace the two lines with the split-boot branch using awk
    awk '
    {
        if ($0 ~ /^[[:space:]]*dump_boot[[:space:]]*$/) {
            print "## Huawei / Honor split-boot support"
            print "source $home/hw-hn-flash.sh"
            print ""
            print "## AnyKernel install"
            print "if is_huawei_split_boot; then"
            print "    ui_print \"- Huawei/Honor split-boot architecture detected\""
            print "    huawei_flash_kernel"
            print "else"
            print "    dump_boot"
            next
        }
        if ($0 ~ /^[[:space:]]*write_boot[[:space:]]*$/) {
            print "    write_boot"
            print "fi"
            next
        }
        print
    }
    ' "$AK" > "$AK.new"

    mv -f "$AK.new" "$AK"
    chmod 755 "$AK"
    say "[change]   done"
}

# ---- package as zip ----
package_zip() {
    OUT="$1"
    say "[change] Packaging ..."

    cd "$AK3_DIR"
    rm -f "$SCRIPT_DIR/$OUT"
    zip -r9 "$SCRIPT_DIR/$OUT" . 
    cd "$SCRIPT_DIR"

    say "[change]   Output: $OUT"
}

# ---- main ----
MODE=""
OUTNAME=""

while [ $# -gt 0 ]; do
    case "$1" in
        --help|-h)
            usage_full
            exit 0
            ;;
        --check)
            MODE="check"
            shift
            ;;
        --change)
            MODE="change"
            shift
            ;;
        --name)
            shift
            [ -n "$1" ] || die "--name requires a filename"
            OUTNAME="$1"
            shift
            ;;
        *)
            warn "Unknown option: $1"
            usage_short
            exit 1
            ;;
    esac
done

case "$MODE" in
    "")
        usage_short
        exit 0
        ;;
    "check")
        do_check
        exit $?
        ;;
    "change")
        # pre-flight
        do_check || exit 1

        fix_permissions
        copy_helper
        patch_anykernel

        TS=$(date +%Y%m%d-%H%M%S)
        if [ -z "$OUTNAME" ]; then
            OUTNAME="ak3-${TS}-hw-hn.zip"
        fi
        # ensure .zip suffix
        case "$OUTNAME" in
            *.zip) ;;
            *) OUTNAME="${OUTNAME}.zip" ;;
        esac

        package_zip "$OUTNAME"

        say "[change]"
        say "[change] Done."
        say "[change] To rename:"
        say "[change]   mv $OUTNAME ak3-hw-p9-eva.zip"
        exit 0
        ;;
esac