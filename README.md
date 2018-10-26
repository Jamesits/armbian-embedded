# Armbian Embedded

A build script that generates full-customizable read-only Armbian image for your embedded, long-running devices. It has the following goals:

* Small (<200MiB footprint on disk with the default changeset, ~30MiB memory after boot)
* Simple (no bloatware that comes with Armbian you won't need for a embedded microcontroller)
* Stable
* No writes to the system disk (so you don't need to worry about sudden power loss)
* Works out of the box
* Fully customizable

## CI Status

The CI runs on a Orange Pi PC with a not very good internet connection, so limited jobs can be run on it, and don't be afraid if it fails.

| Board | OS | Kernel | OS Variant | Armbian version | Arch | Build Type | Status |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| Orange Pi One | Ubuntu Xenial | 3.4.113 | desktop | 5.59 | armv7l | native | [![Build Status](https://dev.azure.com/nekomimiswitch/General/_apis/build/status/Armbian%20Embedded%20Reference%20Image%20(armv7l))](https://dev.azure.com/nekomimiswitch/General/_build/latest?definitionId=18) |

Working example images can be downloaded from the CI pipeline. 

## Usage

You can `unxz` the `armbian-embedded.img.xz` (either from CI download or build it yourself) and write it to an SD card using `dd` (command utility available for \*nix) or [Etcher](https://etcher.io/) (cross-platform Electron based GUI software).

## Building and Customization

### Prerequisites for Building

* Build machine must be of a compatible architecture of the target system (cross-arch building is not supported yet)
* Required packages see [deps.sh](deps.sh) (distros other than Debian/Ubuntu might have different names for a package)
* Root privilege (fakeroot will not be supported, get yourself a container if necessary)
* No spaces and non-ASCII characters in path (won't test against strange paths, but if you found a bug related to this, you are welcomed to contribute)
* ~20GiB free disk space, faster is better
* ~1GiB memory
* Good internet connection for downloading packages
* Patience (a full build requires more than 1 hour on my Allwinner H3 device)

### Customization

#### Golden Image

Golden image is the Armbian reference image of your target machine. Set the correct URL at [build.sh](build.sh#L6). It will be cached once downloaded.

#### Changesets

Changeset is a set of changes that will be applied on the golden image. Changeset is executed in the following sequence:

1. pre_apply_changeset hook
2. packages remove list
3. packages install list
4. rootfs overlay content
5. systemd unit masking
6. post_apply_changeset hook

[src/changeset_common](src/changeset_common) is an example changeset that removes nearly everything except those required for boot. If you are making a headless microcontroller, you can start from here. 

To apply your own changesets, put the changesets in [src/](src/) than edit [src/build.sh](src/build.sh) and add `apply_changeset your_changeset_directory` under `apply_changeset changeset_common`.

#### Image generation

By default the image will be generated at `artifacts/armbian-embedded.img.xz`. 

### Building

#### Building on Your Own Environment

Run `sudo -E build.sh`. 

#### Building with VSTS/Azure DevOps Agent

Set `GOLDEN_IMAGE_URL` variable in the build definition, run `sudo -E deps.sh` then `sudo -E src/build.sh`. Note the image might be downloaded every time.

Example build pipe definition:

```yaml
resources:
- repo: self
  fetchDepth: 1
queue:
  name: OnPrem ARM32
steps:
- bash: |
   #!/bin/bash
   sudo sysctl net.ipv6.conf.all.disable_ipv6=1
  displayName: 'Disable IPv6'
- bash: |
   #!/bin/bash
   sudo -E ${BUILD_SOURCESDIRECTORY}/deps.sh 
  displayName: 'Install Dependencies'
  enabled: false
- bash: |
   #!/bin/bash
   sudo -E ${BUILD_SOURCESDIRECTORY}/src/build.sh 
  displayName: Build
- bash: |
   #!/bin/bash
   cd ${BUILD_ARTIFACTSTAGINGDIRECTORY}
   mv armbian-embedded.img.xz armbian-embedded-opione-${BUILD_BUILDNUMBER}.img.xz
  displayName: 'Rename Artifact'
- task: PublishBuildArtifacts@1
  displayName: 'Publish Artifact'
  inputs:
    ArtifactName: 'armbian-embedded-orangepi-one-ubuntu-xenial-legacy'
  continueOnError: true
```

## Caveats

* Default credential: username `root` password `1234`. Also a user with username `ubuntu` and empty password will [be created by casper on every boot](https://askubuntu.com/questions/448883/change-default-username-in-livecd). 
* It currently does not expand the target filesystem, so if your filesystem during build or the final squashfs is larger than the golden image partition (~1.7GiB), the image generation will fail.
* We use SHA256 as xz checksum, so Bandizip will complain when unarchiving.
* The build script will output over 30000 lines of log. If you are using some log collector or build agent, please make sure it can process this amount of log.

## Notes

If this project is helpful to you, please consider buying me a coffee, or help me get a faster CI machine.

[![Buy Me A Coffee](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://www.buymeacoffee.com/Jamesits) or [PayPal](https://paypal.me/Jamesits)
