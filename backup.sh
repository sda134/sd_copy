#!/bin/sh

echo "=== check and input your device name ==="
echo "check your device name."
lsblk | grep "sd."
echo
read -p "input device name.(e.g. /dev/sdc)input x to exit:" target
if [ "$target" = x ]; then
  exit 0
else
  echo "[ device name is:"$target" ]"
fi


echo
echo "=== check file system ==="
umount $target"2"
sudo e2fsck -p -f -v $target"2"
sudo resize2fs -P $target"2" > estimated_size.txt
min_size_blocks=$(cut -d " " -f 7 estimated_size.txt)
rm estimated_size.txt
echo "[ estimated size is:$min_size_blocks (4k; blocks) ]"


echo
echo "=== make fs small ==="
new_fs_size_m=$((($min_size_blocks * 4 / 1024) + 100))      # used now
new_fs_size_blocks=$((($new_fs_size_m * 1024)/4))           # used later for end sector of new partition.
echo "[ new fs size is:$new_fs_size_m Mb ]"
sudo resize2fs -p $target"2" $new_fs_size_m"M"


echo
echo "=== check the first sector of the target ==="
sudo fdisk -l $target | tail -n 1 | tr -s " " > fdisk_l.txt   # save the result of fdisk -l
st_sector=$(cut -d " " -f 2 fdisk_l.txt )
rm fdisk_l.txt
echo "[ fist sector:$st_sector ]"


echo
echo "=== resize partition and check the last sector of the target ==="
new_fs_size_sector=$(((($new_fs_size_blocks * 4 * 1024) /512) + ((100 * 1024 * 1024)/ 512 ))) # added 100MB
partition_end_sector=$(($new_fs_size_sector + $st_sector))
echo "[ end point of 2nd partition:$partition_end_sector (512b; sectors) ]"

sudo parted $target -s rm 2
sudo parted $target -s mkpart primary $st_sector"s" $partition_end_sector"s"

sudo fdisk -l $target | tail -n 1 | tr -s " " > fdisk_l.txt   # save the result of fdisk -l
from_last=$(cut -d " " -f 3 fdisk_l.txt )                     # sectro from last
rm fdisk_l.txt
echo "[ sector of from-last:$from_last ]"


echo
echo "=== resize file system and backup with dd ==="
sudo resize2fs $target"2"
echo
bs_count=$(((($from_last + 1) * 512) / (16 * 1024 * 1024) + 1))
img_fn=$(date +%F)_backup.img
echo "[ backup with dd   bs=16M count=$bs_count    file name:$img_fn]"
sudo dd if=$target of=./$img_fn bs=16M count=$bs_count status=progress
#xz -v $img_fn                                                 # if you want to


echo
echo "=== resize file system of target device ==="
sudo parted $target -s rm 2
sudo parted $target -s mkpart primary $st_sector"s" 100%
sudo resize2fs $target"2"

#EOF
