Installation
------------

This is the long version, nicely commented. You should be using the `glim.sh`
script instead of copy/pasting from here, as these instructions will be out
of sync and obsolete at some point.

Setting up GRUB require you to be root, while the rest doesn't.

Set the `USBMNT` variable so that copy/pasting examples will work
(replace `/mnt` and `sdx` with the appropriate values) :

    export USBMNT=/run/media/${SUDO_USER:-`id -un`}/GLIM
    export USBDEV=sdx

Preliminary steps (usually already completed on a newly purchased USB memory) :

 * Create a single primary MSDOS partition on your USB memory.
 * Format that partition as FAT32 (label 'GLIM' for the above `USBMNT` to work).
 * Mount the filesystem on the `USBMNT` directory.

Next, install GRUB2 to the USB device's MBR, and onto the new filesystem :

    grub2-install --boot-directory=${USBMNT:-/mnt}/boot /dev/${USBDEV}

 -or- (Debian/Ubuntu, for instance)

    grub-install --boot-directory=${USBMNT:-/mnt}/boot /dev/${USBDEV}

For EFI you must add the following to the above command :

    --target=x86_64-efi --efi-directory=${USBMNT:-/mnt} --removable

If you get the following message :

    source_dir doesn't exist. Please specify --target or --directory

Just find your grub2 directory and specify it as asked. Example :

    grub2-install --directory=/usr/lib/grub/i386-pc --boot-directory=${USBMNT:-/mnt}/boot /dev/${USBDEV}

Use --force if your partitions start at 63 instead of more, such as 2048,
though you might want to repartition and reformat.

Next, copy over all the required files (`grub.cfg` and files it includes, theme, font) :

    rsync -avP grub2/ ${USBMNT:-/mnt}/boot/grub2

 -or- (Debian/Ubuntu, for instance)

    rsync -avP grub2/ ${USBMNT:-/mnt}/boot/grub

If you want to avoid keeping unused translations, themes, etc, use this instead :

    rsync -avP --delete --exclude=i386-pc --exclude=x86_64-efi grub2/ ${USBMNT:-/mnt}/boot/grub2

 -or- (Debian/Ubuntu, for instance)

    rsync -avP --delete --exclude=i386-pc --exclude=x86_64-efi grub2/ ${USBMNT:-/mnt}/boot/grub

Now create and populate the `${USBMNT}/boot/iso/` sub-directories you want.
Example :

    mkdir -p ${USBMNT:-/mnt}/boot/iso/ubuntu

