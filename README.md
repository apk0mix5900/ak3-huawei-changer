![License](https://img.shields.io/badge/license-GPL--2.0-orange)
![Platform](https://img.shields.io/badge/platform-Huawei%20%2F%20Honor-red)
![Type](https://img.shields.io/badge/type-AK3%20converter-blue)

# ak3-huawei-changer
Turn any standard AnyKernel3 into a Huawei/Honor split-boot compatible AK3

Turn a standard AnyKernel3 into a Huawei / Honor AK3 — with support for split-boot (kernel + ramdisk) partition layouts.

## What is this

This is a **converter**.

It takes a **standard AnyKernel3 (AK3)** and turns it into a **Huawei / Honor specific AK3**.

Applies to:

- Huawei devices
- Honor devices
- Any device that uses a **split kernel + ramdisk** partition layout

## Why this project exists

Huawei's engineers had their own ideas very early on.

They didn't just copy Android's standard architecture — they **actively changed it** to give themselves more room to maneuver.

The most notable change is in the **partition layout** — a standard Android device uses **a single unified `boot` partition**, while Huawei **split the kernel and ramdisk into two separate partitions**. This design is similar to the **boot + init_boot** layout that Google would later push.

**The benefit of this design is modularity:**

- To update **just the kernel**, there's no need to repack the whole boot image
- If the **ramdisk breaks**, only the ramdisk partition needs to be updated
- The boot-related partitions end up clearer and easier to maintain

Looking back, Huawei was already laying groundwork for their own OS back then. In later public interviews, they admitted that the idea of a self-developed system had been on the table at that stage — so the unconventional approach is not surprising.

**But this also creates problems:**

The vast majority of AK3 flashable zips on the internet are **designed for a standard `boot` partition** — on Huawei devices, they either fail to flash, or the phone won't boot after flashing.

**Another complication is "special customization":**

Early Huawei devices were heavily customized at the hardware level — screens, flash storage, each variant could differ.

At least on the Huawei P9, the situation looks like this:

> **Different carrier-customized variants package their kernels differently, but the kernel source itself is fully interchangeable.**

For example, a fully unlocked (all-carrier) kernel image flashed onto a China Unicom variant of the same model may result in:

- Failure to boot
- Stuck on the unlock warning screen
- Boot loops

**This is not a kernel problem** — it's a difference in **packaging method** and **partition layout**.

**The goal of this project:**

> Provide a general-purpose conversion script that turns any standard AK3 into one compatible with **all Huawei / Honor split-boot devices**, **removing the need for per-carrier, per-model builds**.

Whether you're on all-carrier, China Unicom, China Mobile, or China Telecom — **the same AK3 works for all of them**.

## How it works

On a Huawei split-boot device, the flashing flow becomes:

1. `dd` out the original kernel partition
2. `busybox gzip -dc Image.gz-dtb > kernel` — decompress the new kernel
3. `magiskboot repack <original> <new>` — repack using the original as a template
4. `dd` the new image back to the kernel partition

The **ramdisk partition is never touched** — so the OEM ramdisk, carrier customizations, and SELinux policy are all preserved.

## Usage

### Directory layout

```

your-build-dir/
├── ak3-hw-changer.sh          ← this script
├── hw-hn-flash.sh             ← Huawei flashing logic (same dir as this script)
└── ak3/                        ← the extracted standard AnyKernel3
├── anykernel.sh
├── Image.gz-dtb
├── tools/
└── ...

```

### Steps

**1. Extract a standard AK3 into `ak3/`**

```sh
mkdir ak3
cd ak3
unzip ~/Downloads/AnyKernel3.zip
cd ..
```

2. Check the layout

```sh
sh ak3-hw-changer.sh --check
```

3. Convert and package

```sh
sh ak3-hw-changer.sh --change
```

This produces a timestamped zip:

```
ak3-20261004-101530-hw-hn.zip
```

4. Rename (optional)

```sh
mv ak3-20261004-101530-hw-hn.zip ak3-hw-p9-eva.zip
```

Command-line options

Option Purpose
--help / -h Show help
--check Check whether ak3/anykernel.sh exists
--change Convert and package
--name <filename> Custom output filename (only valid with --change)

Custom output name

```sh
sh ak3-hw-changer.sh --change --name ak3-hw-p9-eva.zip
```

Requirements

· Any standard AnyKernel3 tree (32-bit or 64-bit — both work)
· Any Linux environment with a POSIX shell
· No architecture-specific tooling required — you can even patch an AK3 from Termux on Android

Tested devices

· Huawei P9 (EVA family) — Kirin 955

Should theoretically also work on other Kirin-based Huawei / Honor devices using the same split-boot layout (P10, Mate 9, Honor 8/9/V series, etc.).

Contributing your AK3

If you've compiled a Huawei kernel and want to share a ready-to-flash AK3, we'd be happy to host it in a dedicated branch.

Branch naming convention:

```
ak3-<vendor>-<model>-<codename>
```

Examples:

```
ak3-hw-p9-eva          Huawei P9 (codename eva)
ak3-hw-p10p-victoria   Huawei P10 Plus (codename victoria)
ak3-hn-frd             Honor 8 (codename frd)
```

· ak3 — standard prefix, indicates this is a ready-to-flash AK3
· <vendor> — hw for Huawei, hn for Honor, other short codes for vendor families with similar split-boot layouts
· <model> — the common marketing name
· <codename> — the internal device codename

Credits

· osm0sis — author of AnyKernel3. This project does not fork the AK3 core; it works on top of it as a patch tool. Thanks to him for making AK3 so extensible.
· AnyKernel3 project — https://github.com/osm0sis/AnyKernel3

License

GPL-2.0 — inherits from AnyKernel3.

Author

apk0mix5900 — https://github.com/apk0mix5900
