#!/bin/bash
# SPDX-License-Identifier: GPL-3.0

work_dir=$(pwd)
source $work_dir/functions.sh
source $work_dir/bin/ddevice/fetchINFO.sh

# Lấy major.minor.patch từ ROMVERSION (VD: V15.0.2 -> 15.0.2)
ROMVERSION_SHORT=$(echo "$ROMVERSION" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)

# Khớp tất cả ColorOS 15.x.x
if [[ "$ANDROID_VER" == "15" ]] && [[ "$ROMVERSION_SHORT" =~ ^15\. ]]; then
    mods "Starting Apply ColorOS 15.x Mods..."
    TARGET_DIR="$work_dir/bin/package/OS150"
    noexecute=("insmod")

    find "$TARGET_DIR" -type f -name "*.sh" | while read -r script; do
        base="$(basename "$script" .sh)"

        skip=false
        for ex in "${noexecute[@]}"; do
            if [[ "$base" == "$ex" ]]; then
                skip=true
                break
            fi
        done

        if [[ $skip == false ]]; then
            bash "$script"
        fi
    done
fi
