#!/bin/bash
# SPDX-License-Identifier: GPL-3.0

work_dir=$(pwd)
source $work_dir/bin/ddevice/fetchINFO.sh
BASE_REGION=$(cat $work_dir/bin/ddevice/rom_region.txt)
insmod=$(grep "install_mods" $work_dir/config.env | cut -d '=' -f 2)

# Lấy major.minor.patch (VD: 16.0.8.xxx -> 16.0.8)
ROMVERSION_SHORT=$(echo "$ROMVERSION" | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+' | head -1)

if [[ $insmod == "true" && $ANDROID_VER == "16" ]]; then
    case "$ROMVERSION_SHORT" in
        16.0.7)
            bash $work_dir/bin/package/OS167/insmod.sh
            ;;
        16.0.5)
            bash $work_dir/bin/package/OS165/insmod.sh
            ;;
        16.0.0|16.0.1|16.0.2|16.0.3|16.0.4)
            bash $work_dir/bin/package/OS160/insmod.sh
            ;;
        16.0.8|16.0.9)
            bash $work_dir/bin/package/OS168/insmod.sh
            ;;
    esac
elif [[ $insmod == "true" && $ANDROID_VER == "15" && "$ROMVERSION_SHORT" == "15.0.0" ]]; then
    bash $work_dir/bin/package/OS150/insmod.sh
fi

bash $work_dir/bin/package/Universal/insfile.sh
bash $work_dir/bin/package/UpdateFile/insupdate.sh
bash $work_dir/bin/package/FrameworkPatcher/insfw.sh
