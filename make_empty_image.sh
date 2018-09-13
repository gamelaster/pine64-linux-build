#!/bin/sh

set -x 
set -e

IMAGE_NAME="$1"
IMAGE_SIZE=6144M
PART_POSITION=20480 # K
FAT_SIZE=100 #M
SWAP_SIZE=2048 # M

if [ -z "$IMAGE_NAME" ]; then
	echo "Usage: $0 <image name>"
	exit 1
fi

fallocate -l $IMAGE_SIZE $IMAGE_NAME

cat << EOF | fdisk $IMAGE_NAME
o
n
p
1
$((PART_POSITION*2))
+${FAT_SIZE}M
t
c
n
p
2
$((PART_POSITION*2+FAT_SIZE*1024*2))
+${SWAP_SIZE}M
t
2
82
n
p
3
$((PART_POSITION*2+FAT_SIZE*1024*2+SWAP_SIZE*1024*2))

t
3
83
a
3
w
EOF
