#!/bin/bash

function prepare_sdk() {
    BASE="$1"
    FILE="$2"
    URL="$3"
    if [[ ! -f ${FILE} ]]; then
        wget "$URL" -O "${FILE}"
    fi
    if [[ ! -f md5sums ]]; then
        MD5SUMS=`dirname "$URL"`/md5sums
        wget "$MD5SUMS" -O - | grep "$FILE" > md5sums
    fi
    # TODO: md5sums for snapshots does not list SDK
    if [[ ! $RELEASE == *"snapshot"* ]]; then
        md5sum -c md5sums || exit 1
    fi
    if [[ ! -d ${BASE} ]]; then
        tar xvjf ${FILE}
    fi
}

function prepare_seed() {
    REPO="$1"
    REPONAME="$2"
    # revert changes to feeds.conf.default
    if ! grep "$REPONAME" feeds.conf.default 2>/dev/null; then
        echo "$REPO" >> feeds.conf.default
    fi
    scripts/feeds update packages
    scripts/feeds update $REPONAME
    scripts/feeds install -p packages -a
    scripts/feeds install -p $REPONAME wifidog 
}


function prepare_makefile() {
    TARGET="feeds/${REPONAME}/net/wifidog/Makefile"
    CURDIR=`pwd`
    # revert changes
    cd `dirname $TARGET`
    git checkout Makefile
    cd $CURDIR
    NOW=`date +%s`
    sed -i -e "s/^PKG_VERSION.*/PKG_VERSION:=$NOW/" $TARGET
    # Now do some magic to get the current master ref so we can set PKG_SOURCE_VERSION
    # and PKG_RELEASE
    # Reasonably mad hack to get the repo URL
    REPO_URL=`grep ^PKG_SOURCE_URL "$TARGET" | sed -e s/PKG_SOURCE_URL:=//`
    # Assumes master branch
    REV=`git ls-remote $REPO_URL | grep master | cut -f 1`
    sed -i -e "s/^PKG_RELEASE.*/PKG_RELEASE:=$REV/" $TARGET
    # Note the use of single quotes to prevent expansion of PKG_RELEASE
    sed -i -e 's/^PKG_SOURCE_VERSION.*/PKG_SOURCE_VERSION:=$(PKG_RELEASE)/' $TARGET
}

function build() {
    PLATFORM=$1
    HOST="downloads.openwrt.org"
    RELEASE="$2"
    # note: newer releases may change GCC or uClibc version
    if [[ $RELEASE == *"snapshot"* ]]; then
        BASE="OpenWrt-SDK-${PLATFORM}-generic_gcc-4.8-linaro_uClibc-0.9.33.2.Linux-x86_64"
    else
        BASE="OpenWrt-SDK-${PLATFORM}-for-linux-x86_64-gcc-4.8-linaro_uClibc-0.9.33.2"
    fi
    EXT="tar.bz2"
    FILE=${BASE}.${EXT}

    URL="http://${HOST}/${RELEASE}/${PLATFORM}/generic/$FILE"

    REPO="src-git wifidog_gateway https://github.com/wifidog/packages.git;wifidog-experimental"
    REPONAME=`echo $REPO | cut -f 2 -d ' '`

    mkdir -p "$RELEASE" && cd "$RELEASE"
    mkdir -p "$PLATFORM" && cd "$PLATFORM"
    # TODO: as trunk is a moving target, we might want to nuke
    # SDK every day or so
    prepare_sdk "$BASE" "$FILE" "$URL"
    cd $BASE
    prepare_seed "$REPO" "$REPONAME"
    prepare_makefile
    make package/wifidog/install V=s
    make package/index
    cd $CURPWD

}

function build_platforms() {
    RELEASE="$1"
    CURPWD=`pwd`
    build ar71xx "$RELEASE"
    cd $CURPWD
#    build x86 "$RELEASE"
#    cd $CURPWD
}

function build_all() {
    build_platforms "barrier_breaker/14.07"
    # trunk SDK is currently broken
    # build_platforms "snapshots/trunk"
}

build_all
