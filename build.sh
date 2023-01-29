#!/bin/bash -e
RED_COLOR='\e[1;31m'
GREEN_COLOR='\e[1;32m'
YELLOW_COLOR='\e[1;33m'
BLUE_COLOR='\e[1;34m'
PINK_COLOR='\e[1;35m'
SHAN='\e[1;33;5m'
RES='\e[0m'

#####################################
#  NanoPi R4S OpenWrt Build Script  #
#####################################

# IP Location
ip_info=`curl -s https://ip.cooluc.com`;
export isCN=`echo $ip_info | grep -Po 'country_code\":"\K[^"]+'`;

# init url
if [ "$isCN" = "CN" ]; then
    export mirror=init.cooluc.com
else
    export mirror=init2.cooluc.com
fi
export gitea=git.cooluc.com

# Check root
if [ "$(id -u)" = "0" ]; then
    echo -e "${RED_COLOR}Building with root user is not supported.${RES}"
    exit 1
fi

# Start time
starttime=`date +'%Y-%m-%d %H:%M:%S'`
CURRENT_DATE=$(date +%s)
# Cpus
cores=`expr $(nproc --all) + 1`
# $CURL_BAR
if curl --help | grep progress-bar >/dev/null 2>&1; then
    CURL_BAR="--progress-bar";
fi

# source mirror
if [ "$isCN" = "CN" ]; then
    export github_mirror="https://github.com"
    openwrt_release_mirror="mirrors.pku.edu.cn/openwrt/releases"
else
    export github_mirror="https://github.com"
    openwrt_release_mirror="downloads.openwrt.org/releases"
fi

# Source branch
if [ "$1" = "dev" ]; then
    export branch=openwrt-21.02
    export version=snapshots-21.02
elif [ "$1" = "dev2" ]; then
    export branch=openwrt-22.03
    export version=snapshots-22.03
elif [ "$1" = "stable" ]; then
    latest_release="v$(curl -s https://$mirror/tags/v21)"
    export branch=$latest_release
    export version=releases
elif [ "$1" = "rc" ]; then
    latest_release="v$(curl -s https://$mirror/tags/v22)"
    export branch=$latest_release
    export version=rc
elif [ -z "$1" ]; then
    echo -e "\r\n${RED_COLOR}Building type not specified.${RES}\r\n"
    echo -e "Build 21.02-releases: ${GREEN_COLOR}bash build.sh stable${RES}"
    echo -e "Build 21.02-snapshots: ${GREEN_COLOR}bash build.sh dev${RES}"
    echo -e "Build 22.03-rc: ${GREEN_COLOR}bash build.sh rc${RES}"
    echo -e "Build 22.03-snapshots: ${GREEN_COLOR}bash build.sh dev2${RES}\r\n"
    exit 1
fi

# Soc
export soc=$2
if [ "$soc" = "" ]; then
    export soc=rk3399
fi

echo -e "\r\n${GREEN_COLOR}Building $branch${RES}"
if [ "$soc" = "x86" ]; then
    echo -e "${GREEN_COLOR}Model: x86_64${RES}\r\n"
elif [ "$soc" = "r5s" ]; then
    if [ "$3" = "kmod" ]; then
        echo -e "${GREEN_COLOR}Model: nanopi-r5s - kmod${RES}\r\n"
        curl -s https://$mirror/tags/kernel-6.1 > kernel.txt
        cat kernel.txt | grep HASH | awk -F- '{print $2}' | awk '{print $1}' > kmod_verion.txt
        kmod_hash=$(cat kernel.txt | grep HASH | awk -F- '{print $2}' | awk '{print $1}' | md5sum | awk '{print $1}')
        kmodpkg_name=$(echo $(cat kernel.txt | grep HASH | awk -F- '{print $2}' | awk '{print $1}')-1-$(echo $kmod_hash))
        echo -e "${GREEN_COLOR}kernel version: $kmodpkg_name ${RES}\r\n"
        rm -f kernel.txt
    else
        echo -e "${GREEN_COLOR}Model: nanopi-r5s${RES}\r\n"
        [ "$1" = "rc" ] && model="nanopi-r5s"
    fi
else
    echo -e "${GREEN_COLOR}Model: nanopi-r4s${RES}\r\n"
    [ "$1" = "rc" ] && model="nanopi-r4s"
fi

echo -e "${GREEN_COLOR}$CURRENT_DATE${RES}\r\n"

# get source
if [ -d openwrt ]; then
    rm -rf openwrt master
    mkdir master
fi

# openwrt - releases
git clone --depth=1 $github_mirror/openwrt/openwrt -b $branch

# master
git clone $github_mirror/openwrt/openwrt master/openwrt --depth=1
git clone $github_mirror/openwrt/packages master/packages --depth=1
git clone $github_mirror/openwrt/luci master/luci --depth=1

if [ -d openwrt ]; then
    cd openwrt
    curl -Os https://$mirror/openwrt/patch/key.tar.gz && tar zxf key.tar.gz && rm -f key.tar.gz
else
    echo -e "${RED_COLOR}Failed to download source code${RES}"
    exit 1
fi

# tags
if [ "$1" = "stable" ] || [ "$1" = "rc" ]; then
    git describe --abbrev=0 --tags > version.txt
else
    git branch | awk '{print $2}' > version.txt
fi

# kenrel vermagic - https://downloads.openwrt.org/
if [ "$1" = "stable" ]; then
    latest_version="$(curl -s https://$mirror/tags/v21)"
    if [ "$soc" = "rk3399" ]; then
        kenrel_vermagic=`curl -s https://$openwrt_release_mirror/"$latest_version"/targets/rockchip/armv8/packages/Packages | awk -F'[- =)]+' '/^Depends: kernel/{for(i=3;i<=NF;i++){if(length($i)==32){print $i;exit}}}'`
    else
        kenrel_vermagic=`curl -s https://$openwrt_release_mirror/"$latest_version"/targets/x86/64/packages/Packages | awk -F'[- =)]+' '/^Depends: kernel/{for(i=3;i<=NF;i++){if(length($i)==32){print $i;exit}}}'`
    fi
elif [ "$1" = "dev" ]; then
    if [ "$soc" = "rk3399" ]; then
        kenrel_vermagic=`curl -s https://$openwrt_release_mirror/21.02-SNAPSHOT/targets/rockchip/armv8/packages/Packages | awk -F'[- =)]+' '/^Depends: kernel/{for(i=3;i<=NF;i++){if(length($i)==32){print $i;exit}}}'`
    else
        kenrel_vermagic=`curl -s https://$openwrt_release_mirror/21.02-SNAPSHOT/targets/x86/64/packages/Packages | awk -F'[- =)]+' '/^Depends: kernel/{for(i=3;i<=NF;i++){if(length($i)==32){print $i;exit}}}'`
    fi
elif [ "$1" = "dev2" ]; then
    [ "$soc" = "x86" ] && kenrel_vermagic=`curl -s https://$openwrt_release_mirror/22.03-SNAPSHOT/targets/x86/64/packages/Packages | awk -F'[- =)]+' '/^Depends: kernel/{for(i=3;i<=NF;i++){if(length($i)==32){print $i;exit}}}'`
elif [ "$1" = "rc" ]; then
    latest_version="$(curl -s https://$mirror/tags/v22)"
    [ "$soc" = "x86" ] && kenrel_vermagic=`curl -s https://$openwrt_release_mirror/"$latest_version"/targets/x86/64/packages/Packages | awk -F'[- =)]+' '/^Depends: kernel/{for(i=3;i<=NF;i++){if(length($i)==32){print $i;exit}}}'`
fi
echo $kenrel_vermagic > .vermagic
sed -ie 's/^\(.\).*vermagic$/\1cp $(TOPDIR)\/.vermagic $(LINUX_DIR)\/.vermagic/' include/kernel-defaults.mk

# feeds mirror
if [[ "$1" = "stable" ]] || [[ "$1" = "rc" ]]; then
    packages="^$(cat feeds.conf.default | grep packages | awk -F^ '{print $2}')"
    luci="^$(cat feeds.conf.default | grep luci | awk -F^ '{print $2}')"
    routing="^$(cat feeds.conf.default | grep routing | awk -F^ '{print $2}')"
    telephony="^$(cat feeds.conf.default | grep telephony | awk -F^ '{print $2}')"
else
    packages=";$branch"
    luci=";$branch"
    routing=";$branch"
    telephony=";$branch"
fi
cat > feeds.conf <<EOF
src-git packages $github_mirror/openwrt/packages.git$packages
src-git luci $github_mirror/openwrt/luci.git$luci
src-git routing $github_mirror/openwrt/routing.git$routing
src-git telephony $github_mirror/openwrt/telephony.git$telephony
EOF

# Init feeds
./scripts/feeds update -a
./scripts/feeds install -a

# loader dl
if [ -f ../dl.gz ]; then
    tar xf ../dl.gz -C .
fi

###############################################

echo -e "\r\n${GREEN_COLOR}Patching ...${RES}\r\n"

# scripts
curl -sO https://$mirror/openwrt/scripts/00-prepare_base.sh
curl -sO https://$mirror/openwrt/scripts/01-prepare_base-mainline.sh
curl -sO https://$mirror/openwrt/scripts/02-prepare_package.sh
curl -sO https://$mirror/openwrt/scripts/03-convert_translation.sh
curl -sO https://$mirror/openwrt/scripts/04-fix_kmod.sh
curl -sO https://$mirror/openwrt/scripts/99_clean_build_cache.sh
chmod 0755 *sh
bash 00-prepare_base.sh
bash 02-prepare_package.sh
bash 03-convert_translation.sh
if [ "$version" = "rc" ] || [ "$version" = "snapshots-22.03" ] && [ "$soc" = "r5s" ] || [ "$soc" = "rk3399" ] && [ "$1" != "stable" ] && [ "$1" != "dev" ]; then
    bash 01-prepare_base-mainline.sh
    bash 04-fix_kmod.sh
fi
rm -f 0*-*.sh
rm -rf ../master

# Load devices Config
if [ "$version" = "rc" ] || [ "$version" = "snapshots-22.03" ]; then
    if [ "$soc" = "x86" ]; then
        curl -s https://$mirror/openwrt/22-config-musl-x86 > .config
        ALL_KMODS=y
    elif [ "$soc" = "r5s" ] && [ "$3" != "kmod" ]; then
        curl -s https://$mirror/openwrt/22-config-musl-r5s > .config
        [ "$version" = "rc" ] && echo 'CONFIG_PACKAGE_luci-app-ota=y' >> .config
        [ "$USE_GLIBC" = "y" ] && curl -s https://$mirror/openwrt/config-glibc >> .config
    elif [ "$soc" = "r5s" ] && [ "$3" = "kmod" ]; then
        ALL_KMODS=n
    else
        curl -s https://$mirror/openwrt/22-config-musl-r4s > .config
        [ "$version" = "rc" ] && echo 'CONFIG_PACKAGE_luci-app-ota=y' >> .config
        [ "$USE_GLIBC" = "y" ] && curl -s https://$mirror/openwrt/config-glibc >> .config
    fi
else
    if [ "$soc" = "x86" ]; then
        curl -s https://$mirror/openwrt/21-config-musl-x86 > .config
    else
        curl -s https://$mirror/openwrt/21-config-musl-r4s > .config
    fi
fi

# init openwrt config
make defconfig

# Compile
if [ "$ALL_KMODS" = y ]; then
    echo -e "\r\n${GREEN_COLOR}Building OpenWrt ...${RES}\r\n"
    curl -s https://$mirror/openwrt/22-config-musl-x86 > .config
    sed -i '/samba4/d;/qbittorrent/d;/mosdns/d;/alist/d;/netdata/d;/vim/d;/ttyd/d;/coreutils/d;/procps-ng/d;/PACKAGE_shadow/d;/coremark/d;/aria2/d' .config
    make defconfig
    make -j$cores
    [ $? -eq 0 ] && bash 99_clean_build_cache.sh || true
    echo -e "\r\n${GREEN_COLOR}Building OpenWrt With All Kmods ...${RES}\r\n"
    rm -f package/libs/mbedtls/patches/100-Implements-AES-and-GCM-with-ARMv8-Crypto-Extensions.patch
    git checkout package/libs/mbedtls/Makefile
    make defconfig
    make -j$cores
    if [ $? -eq 0 ]; then
        # Compile time
        endtime=`date +'%Y-%m-%d %H:%M:%S'`
        start_seconds=$(date --date="$starttime" +%s);
        end_seconds=$(date --date="$endtime" +%s);
        SEC=$((end_seconds-start_seconds));
        echo "$kmodpkg_name"
        mkdir $kmodpkg_name
        echo "yayayya"
        cp -a bin/targets/x86/64/packages $kmodpkg_name
        \cp -a kmod/*.ipk $kmodpkg_name/ || true
        rm -f $kmodpkg_name/Packages*
        # driver firmware
        cp -a bin/packages/x86_64_generic/base/*firmware*.ipk $kmodpkg_name/
        cp -a bin/packages/x86_64_generic/base/hostapd-common*.ipk $kmodpkg_name/
        cp -a bin/packages/x86_64_generic/base/*iw*.ipk $kmodpkg_name/
        cp -a bin/packages/x86_64_generic/base/wireless-regdb*.ipk $kmodpkg_name/
        cp -a $kmodpkg_name/ /openwrt/kmod-build
        tar zcf kmod-packages.tar.gz $kmodpkg_name
        echo $kmodpkg_name > hash.txt
        echo -e "${GREEN_COLOR} Build success! ${RES}"
        echo -e " Build time: ${GREEN_COLOR}$(( SEC / 3600 ))h,$(( (SEC % 3600) / 60 ))m,$(( (SEC % 3600) % 60 ))s${RES}"
        exit 0
    else
        # Compile time
        endtime=`date +'%Y-%m-%d %H:%M:%S'`
        start_seconds=$(date --date="$starttime" +%s);
        end_seconds=$(date --date="$endtime" +%s);
        SEC=$((end_seconds-start_seconds));
        echo -e "${RED_COLOR} Build error... ${RES}"
        echo -e " Build time: ${RED_COLOR}$(( SEC / 3600 ))h,$(( (SEC % 3600) / 60 ))m,$(( (SEC % 3600) % 60 ))s${RES}"
        exit 1
    fi
else
    echo -e "\r\n${GREEN_COLOR}Building OpenWrt ...${RES}\r\n"
    sed -i "/BUILD_DATE/d" package/base-files/files/usr/lib/os-release
    sed -i "/BUILD_ID/aBUILD_DATE=\"$CURRENT_DATE\"" package/base-files/files/usr/lib/os-release
    make -j$cores
fi

# Compile time
endtime=`date +'%Y-%m-%d %H:%M:%S'`
start_seconds=$(date --date="$starttime" +%s);
end_seconds=$(date --date="$endtime" +%s);
SEC=$((end_seconds-start_seconds));

if [ "$soc" = "x86" ]; then
    if [ -f bin/targets/x86/64/*-ext4-combined-efi.img.gz ]; then
        echo -e "${GREEN_COLOR} Build success! ${RES}"
        echo -e " Build time: $(( SEC / 3600 ))h,$(( (SEC % 3600) / 60 ))m,$(( (SEC % 3600) % 60 ))s"
        # Backup download cache
        if [ "$isCN" = "CN" ] && [ "$1" = "stable" ] || [ "$1" = "rc" ]; then
            rm -rf dl/xray* dl/trojan* dl/v2ray* dl/adguardhome* dl/alist* dl/qbittorrent* dl/geo* dl/go-mod-cache
            tar cf ../dl.gz dl
        fi
        exit 0
    else
        echo -e "${RED_COLOR} Build error... ${RES}"
        echo -e " Build time: $(( SEC / 3600 ))h,$(( (SEC % 3600) / 60 ))m,$(( (SEC % 3600) % 60 ))s"
        echo
        if [ ! "$isCN" = "CN" ]; then
            make -j1 V=s
        fi
        exit 1
    fi
else
    if [ -f bin/targets/rockchip/armv8/*-ext4-sysupgrade.img.gz ]; then
        echo -e "${GREEN_COLOR} Build success! ${RES}"
        echo -e " Build time: ${GREEN_COLOR}$(( SEC / 3600 ))h,$(( (SEC % 3600) / 60 ))m,$(( (SEC % 3600) % 60 ))s${RES}"
        # OTA json
        if [ "$1" = "rc" ]; then
            curl -Lso ota.json https://github.com/sbwml/builder/releases/latest/download/fw.json || exit 0
            VERSION=$(cat version.txt | sed 's/v//g')
            SHA256=$(sha256sum bin/targets/rockchip/armv8/*-squashfs-sysupgrade.img.gz | awk '{print $1}')
            if [ "$model" = "nanopi-r4s" ]; then
                jq ".\"friendlyarm,nanopi-r4s\"[0].build_date=\"$CURRENT_DATE\"|.\"friendlyarm,nanopi-r4s\"[0].sha256sum=\"$SHA256\"|.\"friendlyarm,nanopi-r4s\"[0].url=\"https://r4s.cooluc.com/releases/openwrt-22.03/v$VERSION/openwrt-$VERSION-rockchip-armv8-friendlyarm_nanopi-r4s-squashfs-sysupgrade.img.gz\"" ota.json > fw.json
            elif [ "$model" = "nanopi-r5s" ]; then
                jq ".\"friendlyarm,nanopi-r5s\"[0].build_date=\"$CURRENT_DATE\"|.\"friendlyarm,nanopi-r5s\"[0].sha256sum=\"$SHA256\"|.\"friendlyarm,nanopi-r5s\"[0].url=\"https://r5s.cooluc.com/releases/openwrt-22.03/v$VERSION/openwrt-$VERSION-rockchip-armv8-friendlyarm_nanopi-r5s-squashfs-sysupgrade.img.gz\"" ota.json > fw.json
            fi
        fi
        # Backup download cache
        if [ "$isCN" = "CN" ] && [ "$1" = "stable" ] || [ "$1" = "rc" ]; then
            rm -rf dl/xray* dl/trojan* dl/v2ray* dl/adguardhome* dl/alist* dl/qbittorrent* dl/geo* dl/go-mod-cache
            tar cf ../dl.gz dl
        fi
        exit 0
    else
        echo -e "${RED_COLOR} Build error... ${RES}"
        echo -e " Build time: ${RED_COLOR}$(( SEC / 3600 ))h,$(( (SEC % 3600) / 60 ))m,$(( (SEC % 3600) % 60 ))s${RES}"
        echo
        if [ ! "$isCN" = "CN" ]; then
            make -j1 V=s
        fi
        exit 1
    fi
fi

# 很少有人会告诉你为什么要这样做，而是会要求你必须要这样做。
