# wifidog-openwrt-builder
Build script for Wifidog packages on OpenWRT

Run

    ./build.sh

to build the wifidog package for all configured OpenWrt versions and
platforms.

The resulting packages will be found in:

    $RELEASE/$PLATFORM/OpenWrt-SDK-*/bin/packages/

For the package, Wifidog version is set to the unix timestamp of the build
run. PKG\_RELEASE is set to the git commit.

