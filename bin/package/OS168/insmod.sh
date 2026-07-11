#!/bin/bash
# SPDX-License-Identifier: GPL-3.0

work_dir=$(pwd)
source $work_dir/functions.sh
source $work_dir/bin/ddevice/fetchINFO.sh

# Lấy major.minor.patch từ ROMVERSION (VD: 16.0.8.401 -> 16.0.8)
ROMVERSION_SHORT=$(echo "$ROMVERSION" | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+' | head -1)

# Khớp các phiên bản OS16.8+: 16.0.6+, 16.0.8, 16.0.9, 16.1.x
if [[ "$ANDROID_VER" == "16" ]] && [[ "$ROMVERSION_SHORT" =~ ^16\.(0\.[6-9]|1\.) ]]; then
    mods "Starting Apply ColorOS 16.8+ Mods..."
    TARGET_DIR="$work_dir/bin/package/OS168"
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
