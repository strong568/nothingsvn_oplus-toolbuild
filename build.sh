#!/bin/bash
# SPDX-License-Identifier: GPL-3.0

baserom="$1"
localbuild="$2"
repo_name="$3"
prefix_id="$4"
builder_name="$5"
builder_id="$6"
work_dir=$(pwd)
tools_dir=${work_dir}/bin/$(uname)/$(uname -m)
export PATH=${tools_dir}:$PATH
chmod 777 ${work_dir}/bin/*
chmod 777 ${work_dir}/bin/Linux/x86_64/*
source $work_dir/functions.sh
check unzip aria2c curl 7z zip java zipalign python3 zstd bc xmlstarlet aapt
if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHANNEL_ID" ]; then
    python3 $work_dir/notify.py download "$repo_name" "$baserom" "$prefix_id" "$builder_name" "$builder_id"
fi
BLOB="$work_dir/bin/package/UpdateFile/OOSExtenstionUni"
super_list="system system_ext product vendor odm my_product my_engineering my_stock my_carrier my_region my_bigball my_heytap my_manifest vendor_dlkm system_dlkm odm_dlkm system_ext_dlkm product_dlkm"

if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHANNEL_ID" ]; then
    python3 $work_dir/notify.py unpack "$repo_name" "$baserom" "$prefix_id" "$builder_name" "$builder_id"
fi
if [[ -d "$baserom" ]]; then
    baserom_type="images_dir"
    images_source=$(cd "$baserom" && pwd)
    echo "[UNPACK] - Partition image folder detected: $images_source"
    if ! find "$images_source" -maxdepth 1 -type f -name "*.img" | grep -q .; then
        error "[UNPACK] - No partition .img files found in folder."
        exit 1
    fi
else
    source "$work_dir/bin/ddevice/getROM.sh" "$baserom"
    if unzip -l "$baserom" | grep -q "payload.bin"; then
        baserom_type="payload"
        echo "[UNPACK] - This is payload.bin ROM!Vaildation..."
        echo "[UNPACK] - ROM validation passed."
    else
        echo "[UNPACK] - Unpack failed"
        exit 1
    fi
fi

rm -rf app
rm -rf tmp
rm -rf config
rm -rf build/baserom/
rm -rf build/baserom/
find . -type d -name 'miui_*' | xargs rm -rf

echo "[SYSTEM] - Files cleaned up."
mkdir -p build/baserom/images/

if [[ "$baserom_type" == "payload" ]]; then
    echo "[UNPACK] - Extracting files from BASEROM [payload.bin]"
    unzip "$baserom" payload.bin -d build/baserom >/dev/null 2>&1 || error "Extracting [payload.bin] error"
    echo "[UNPACK] - [payload.bin] extracted."
    echo "[UNPACK] - Unpacking BASEROM [payload.bin]"
    payload-extract extract -o build/baserom/images/ build/baserom/payload.bin >/dev/null 2>&1 || error "Unpacking [payload.bin] failed"
elif [[ "$baserom_type" == "images_dir" ]]; then
    echo "[UNPACK] - Copying partition images from folder"
    find "$images_source" -maxdepth 1 -type f -name "*.img" -exec cp -f {} "$work_dir/build/baserom/images/" \;
fi

for part in system system_ext product vendor odm my_product my_engineering my_stock my_carrier my_region my_bigball my_heytap my_manifest ;do
    extract_partition $work_dir/build/baserom/images/${part}.img $work_dir/build/baserom/images
    PACK_TYPE=$(cat $work_dir/bin/ddevice/fstype.txt)
done

echo "[INFO] - Gathering Devices Infomations"
source $work_dir/bin/ddevice/fetchINFO.sh
bash $work_dir/bin/ddevice/modifyINFO.sh
main

# Gửi thông báo đang Build với đầy đủ Codename và Version
if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHANNEL_ID" ]; then
    python3 $work_dir/notify.py build "$repo_name" "$baserom" "$prefix_id" "$builder_name" "$builder_id"
fi

rm -rf config
if [ -f $work_dir/${baserom}.zip ]; then
    rm -rf ${baserom}.zip
fi
rm -rf build/baserom/payload.bin
bash $work_dir/bin/package/install.sh
MY_STOCK="$work_dir/build/baserom/images/my_stock"

remove_fsv "$work_dir/build/baserom/images/system/system/framework"
remove_fsv "$work_dir/build/baserom/images/system_ext"

cp -rf $BLOB/feature_com.hma.otablock.xml $MY_STOCK/etc/extension

echo "[REPACK] - Packing partitions in parallel (max 4 jobs)..."
REPACK_LOG_DIR=$(mktemp -d)

repack_one() {
    local pname=$1
    local work_dir=$2
    local PACK_TYPE=$3
    local log_dir=$4

    thisSize=$(du -sb $work_dir/build/baserom/images/${pname} 2>/dev/null | awk '{print $1}')
    [ -z "$thisSize" ] && { echo "FAIL" > "$log_dir/${pname}"; return; }
    case $pname in
        odm) addSize=134217728 ;;
        system) addSize=154217728 ;;
        vendor) addSize=154217728 ;;
        system_ext) addSize=154217728 ;;
        product) addSize=204217728 ;;
        *) addSize=8554432 ;;
    esac
    thisSize=$(echo "$thisSize + $addSize" | bc)

    if [[ "$PACK_TYPE" == "EXT" ]]; then
        echo "[REPACK] - Packing [${pname}.img]:[${PACK_TYPE}] with size [${thisSize}]"
        python3 $work_dir/bin/fspatch.py $work_dir/build/baserom/images/${pname} $work_dir/build/baserom/images/config/${pname}_fs_config >/dev/null 2>&1
        python3 $work_dir/bin/contextpatch.py $work_dir/build/baserom/images/${pname} $work_dir/build/baserom/images/config/${pname}_file_contexts >/dev/null 2>&1
        make_ext4fs -J -T $(date +%s) -S $work_dir/build/baserom/images/config/${pname}_file_contexts -l $thisSize -C $work_dir/build/baserom/images/config/${pname}_fs_config -L ${pname} -a ${pname} $work_dir/build/baserom/images/${pname}.img $work_dir/build/baserom/images/${pname} >/dev/null 2>&1
    elif [[ "$PACK_TYPE" == "EROFS" ]]; then
        echo "[REPACK] - Packing [${pname}.img]:[${PACK_TYPE}] with size [${thisSize}]"
        python3 $work_dir/bin/fspatch.py $work_dir/build/baserom/images/${pname} $work_dir/build/baserom/images/config/${pname}_fs_config >/dev/null 2>&1
        python3 $work_dir/bin/contextpatch.py $work_dir/build/baserom/images/${pname} $work_dir/build/baserom/images/config/${pname}_file_contexts >/dev/null 2>&1
        mkfs.erofs --quiet -zlz4hc,9 --mount-point ${pname} --fs-config-file=$work_dir/build/baserom/images/config/${pname}_fs_config --file-contexts=$work_dir/build/baserom/images/config/${pname}_file_contexts $work_dir/build/baserom/images/${pname}.img $work_dir/build/baserom/images/${pname} >/dev/null 2>&1
    else
        echo "SKIP" > "$log_dir/${pname}"
        return
    fi

    if [ -f "$work_dir/build/baserom/images/${pname}.img" ]; then
        echo "OK" > "$log_dir/${pname}"
    else
        echo "FAIL" > "$log_dir/${pname}"
    fi
}

MAX_JOBS=4
running=0
for pname in ${super_list}; do
    if [ -d "$work_dir/build/baserom/images/$pname" ]; then
        repack_one "$pname" "$work_dir" "$PACK_TYPE" "$REPACK_LOG_DIR" &
        running=$((running + 1))
        if [ $running -ge $MAX_JOBS ]; then
            wait -n 2>/dev/null || true
            running=$((running - 1))
        fi
    fi
done
wait

REPACK_FAILED=0
for pname in ${super_list}; do
    if [ -d "$work_dir/build/baserom/images/$pname" ]; then
        result=$(cat "$REPACK_LOG_DIR/${pname}" 2>/dev/null)
        if [ "$result" = "OK" ]; then
            echo "[REPACK] - [${pname}.img] Success"
        else
            error "[REPACK] - [${pname}.img] Failed"
            REPACK_FAILED=1
        fi
    fi
done
rm -rf "$REPACK_LOG_DIR"

if [ $REPACK_FAILED -eq 1 ]; then
    error "[REPACK] - One or more partitions failed to repack, exit."
    exit 1
fi


if [[ $localbuild = "y" ]]; then
    bash $work_dir/packROM.sh y
    cp -rf $work_dir/bin/default/script/* $work_dir/bin/script2flash/META-INF/Data/
    cp -rf $work_dir/bin/default/device/* $work_dir/bin/ddevice/
fi
