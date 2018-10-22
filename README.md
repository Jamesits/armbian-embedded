# Armbian Embedded

A build script that generates full-customized read-only Armbian image for your embedded, long-running devices. It has the following goals:

* Small (<200MiB footprint on disk with the default changeset, ~30MiB memory after boot)
* Simple (No bloatware that comes with Armbian you won't need for a embedded microcontroller)
* Stable
* No writes to the system disk (so you don't need to worry about power loss or manually powering off it)
* Works out of the box
* Fully customizable

## Prerequisites

* Build machine must be of a compatible architecture of the target system (cross-arch building is not supported yet)
* Required packages see [deps.sh](deps.sh)
* Root privilege (We are not going to support fakeroot, get yourself a container)
* No spaces and non-ASCII characters in path (we won't test against strange paths, but if you found a bug related to this, you are welcomed to contribute)
* ~20GiB free disk space
* ~1GiB memory
* Patience (A full build requires 2 hours on my Allwinner H3 device)

## Build

### Golden image

Golden image is the Armbian reference image of your target machine. Set the correct URL at [build.sh](build.sh#L6). It will be cached once downloaded.

If building using VSTS/Azure DevOps agent, set `GOLDEN_IMAGE_URL` variable in the build definition. Note the image will be downloaded every time.

### Changesets

Changeset is a set of changes that will be applied on the golden image. Changeset is executed in the following sequence:

1. pre_apply_changeset hook
2. packages remove list
3. packages install list
4. rootfs overlay content
5. systemd unit masking
6. post_apply_changeset hook

[src/changeset_common](src/changeset_common) is an example changeset that removes nearly everything except those required for boot. If you are making a headless microcontroller, you can start from here. 

To apply your own changesets, put the changesets in [src/](src/) than edit [src/build.sh](src/build.sh) and add `apply_changeset your_changeset_directory` under `apply_changeset changeset_common`.

### Image generation

By default the image will be generated at `artifacts/armbian-embedded.img.xz`. You can `unxz` it and write it to an SD card using `dd` (command utility available for \*nix) or [Etcher](https://etcher.io/) (cross-platform Electron based GUI software).

### Building with VSTS/Azure DevOps agent

Set `GOLDEN_IMAGE_URL` variable in the build definition, run `sudo -E deps.sh` then `sudo -E src/build.sh`.

## Known issues

* It currently does not expand filesystem, so if you result in a filesystem this is larger than the golden image (~1.7GiB), the image generation will fail.
* We use SHA256 as xz checksum, so Bandizip will complain when unarchiving.
* We currently only tests Orange Pi One legacy kernel version due to lack of time and money. 

## Notes

If this project is helpful to you, please consider buying me a coffee, or help me get a faster build machine.

[![Buy Me A Coffee](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://www.buymeacoffee.com/Jamesits) or [PayPal](https://paypal.me/Jamesits)
