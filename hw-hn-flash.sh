#!/sbin/sh
# Huawei / Honor split-boot support for AnyKernel3
# Author: apk0mix5900 <https://github.com/apk0mix5900/ak3-huawei-changer>
# SPDX-License-Identifier: GPL-2.0
#
# Some Huawei/Honor devices use separate "kernel" and "ramdisk" partitions
# instead of a unified "boot" partition. Stock AK3's dump_boot/write_boot
# cannot handle this. This script adds a split-boot branch.

BB=$bin/busybox
MAGISKBOOT=$bin/magiskboot

# Find a partition by name under /dev/block/*/by-name/
hw_hn_find_partition() {
    local name="$1" p
    for p in \
        /dev/block/platform/*/by-name/$name \
        /dev/block/platform/*/*/by-name/$name \
        /dev/block/bootdevice/by-name/$name
    do
        [ -e "$p" ] && { echo "$p"; return 0; }
    done
    return 1
}

# Return 0 if the device has "kernel"+"ramdisk" but no "boot" partition
is_huawei_split_boot() {
    local kernel_part ramdisk_part boot_part

    kernel_part=$(hw_hn_find_partition kernel)
    ramdisk_part=$(hw_hn_find_partition ramdisk)
    boot_part=$(hw_hn_find_partition boot)

    [ -n "$kernel_part" ] && [ -n "$ramdisk_part" ] && [ -z "$boot_part" ]
}

# Flash the new kernel to the kernel partition (dd-out, decompress, repack, dd-back)
huawei_flash_kernel() {
    local KPART KORIG NEWKERNEL

    ui_print " "
    ui_print "=========================================="
    ui_print "  AK3 Flasher - Huawei / Honor Edition"
    ui_print "  by apk0mix5900 @GitHub"
    ui_print "  https://github.com/apk0mix5900/ak3-huawei-changer"
    ui_print "=========================================="
    ui_print " "

    # Locate kernel partition
    KPART=$(hw_hn_find_partition kernel)
    [ -z "$KPART" ] && { ui_print "! Kernel partition not found"; return 1; }
    ui_print "- Using kernel partition: $KPART"

    # Back up the original kernel image
    KORIG=$home/orig-kernel.img
    ui_print "- Backing up original kernel to $KORIG"
    dd if=$KPART of=$KORIG bs=4096 2>/dev/null
    [ ! -s "$KORIG" ] && { ui_print "! Backup failed"; return 1; }

    # Locate the new kernel in the AK3 zip root
    for i in Image.gz-dtb Image.gz Image Image-dtb; do
        [ -f "$home/$i" ] && { NEWKERNEL=$home/$i; break; }
    done
    [ -z "$NEWKERNEL" ] && { ui_print "! New kernel not found"; return 1; }
    ui_print "- New kernel: $NEWKERNEL"

    # Decompress the gzipped Image into a raw kernel
    cd "$home"
    ui_print "- Decompressing kernel"
    $BB gzip -dc "$NEWKERNEL" > kernel || { ui_print "! Decompress failed"; return 1; }

    # Repack using the original image as a template
    ui_print "- Repacking image"
    $MAGISKBOOT repack "$KORIG" "$home/hw-hn-new.img"
    [ ! -f "$home/hw-hn-new.img" ] && { ui_print "! Repack failed"; return 1; }

    # Write the new image back to the kernel partition
    blockdev --setrw "$KPART" 2>/dev/null
    dd if="$home/hw-hn-new.img" of="$KPART" bs=4096
    sync

    if [ $? != 0 ]; then
        ui_print "! Flashing failed"
        return 1
    fi

    ui_print "- Flashed new kernel successfully"
    return 0
}