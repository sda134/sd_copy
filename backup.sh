#!/bin/sh

echo "=== check and input your device name ==="
echo "check your device name."
lsblk | grep "sd."
echo
echo "input device name.(e.g. /dev/sdc)"
read -p "[input x to exit:]" target
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
min_size=$(cut -d " " -f 7 estimated_size.txt)
rm estimated_size.txt
echo "[ estimated size is:$min_size (blocks) ]"


echo
echo "=== make fs small ==="
new_fs_size=$((($min_size * 4 / 1024) + 100))
echo "[ new fs size is:$new_fs_size M ]"
sudo resize2fs -p $target"2" $new_fs_size"M"


echo
echo "=== check the first sector of target ==="
sudo fdisk -l $target | tail -n 1 | tr -s " " > fdisk_l.txt   # save the result of fdisk -l
st_sector=$(cut -d " " -f 2 fdisk_l.txt )   # 開始位置
rm fdisk_l.txt
echo "[ fist sector:$st_sector ]"


echo
echo "=== resize partition and check the last sector of target ==="
end_sector_g_float=`echo "scale=2; $new_fs_size * 1.1 / 1024" | bc`
sudo parted $target -s rm 2                     # fist:532480   from_last:60751871
sudo parted $target -s mkpart primary $st_sector"s" $end_sector_g_float"G"

sudo fdisk -l $target | tail -n 1 | tr -s " " > fdisk_l.txt   # save the result of fdisk -l
from_last=$(cut -d " " -f 3 fdisk_l.txt )   # 最後から
rm fdisk_l.txt
echo "[ from_last:$from_last ]"


echo
echo "=== check the first and last sector of target ==="
sudo fdisk -l $target | tail -n 1 | tr -s " " > fdisk_l.txt   # save the result of fdisk -l
st_sector=$(cut -d " " -f 2 fdisk_l.txt )                     # first sector
from_last=$(cut -d " " -f 3 fdisk_l.txt )                     # sector from last
rm fdisk_l.txt
echo "[ fist sector:$st_sector ]"
echo "[ from_last:$from_last ]"


echo "=== resize file system and backup with dd ==="
sudo resize2fs $target"2"
echo
bs_count=$(((($from_last + 1) * 512) / (16 * 1024 * 1024) + 1))
img_fn=$(date +%F).img
echo "[ backup with dd   bs=16M count=$bs_count    file name:$img_fn]"
sudo dd if=$target of=./backup.img bs=16M count=$bs_count status=progress
xz -v $img_fn


echo "=== resize file system of target device ==="
sudo parted $target -s rm 2
sudo parted $target -s mkpart primary $st_sector"s" 100%
sudo resize2fs $target"2"

#EOF
