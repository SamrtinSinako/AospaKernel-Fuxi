### AnyKernel3 Ramdisk Mod Script
## osm0sis @ xda-developers

### AnyKernel setup
# begin properties
properties() {'kernel.string=NikoKernelX For 5.15 GKI
do.devicecheck=0
do.modules=0
do.systemless=0
do.cleanup=1
do.cleanuponabort=0
'} # end properties

### AnyKernel install

## boot shell variables
block=boot
is_slot_device=auto
ramdisk_compression=auto
patch_vbmeta_flag=auto

# import functions/variables and setup patching - see for reference (DO NOT REMOVE)
. tools/ak3-core.sh

kernel_version=$(cat /proc/version | awk -F '-' '{print $1}' | awk '{print $3}')
case "$kernel_version" in
5.1*) ksu_supported=true ;;
6.1*) ksu_supported=true ;;
*) ksu_supported=false ;;
esac

ui_print " " "  -> ksu_supported: $ksu_supported"

if [ ! $ksu_supported ]; then
    ui_print " " "  -> Non-GKI device, abort."
    exit 1
fi

# boot install
if [ -L "/dev/block/bootdevice/by-name/init_boot_a" ]; then
    split_boot # for devices with init_boot ramdisk

    flash_boot # for devices with init_boot ramdisk
else
    dump_boot # use split_boot to skip ramdisk unpack, e.g. for devices with init_boot ramdisk

    write_boot # use flash_boot to skip ramdisk repack, e.g. for devices with init_boot ramdisk
fi
## end boot install
