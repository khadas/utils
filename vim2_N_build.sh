#!/bin/bash

clear

echo -e "\nSimple script to automate build of Android Nougat (7.1.x) for VIM2 on linux box"
echo -e "\n"
echo -e "\n-------------------------------------------------------------------------------------------------------------------"
echo -e "\nHow to use it:"
echo -e "\n1. follow initial documentation on http://docs.khadas.com/develop/DownloadAndroidSourceCode/"
echo -e "\n2. download amlogic dev libs from http://openlinux.amlogic.com:8000/deploy/ and install them inside /opt/toolchains"
echo -e "\n   by running: "
echo -e "\n     (notice - change version numbers to match one downloaded)" 
echo -e "\n     sudo tar xvf gcc-linaro-aarch64-linux-gnu-4.9-2014.09_linux.tar -C /opt/toolchains"
echo -e "\n     sudo tar xvf gcc-linaro-aarch64-none-elf-4.8-2013.11_linux.tar.bz2 -C /opt/toolchains"
echo -e "\n     sudo tar xvf arc-4.8-amlogic-20130904-r2.tar.gz -C /opt/toolchains"
echo -e "\n     sudo tar xvf gcc-linaro-arm-linux-gnueabihf.tar.gz -C /opt/toolchains"
echo -e "\n     sudo tar xvf CodeSourcery.tar.gz -C /opt/toolchains"
echo -e "\n3. put TOOLSENV.sh inside src folder of synced khadas: wget http://openlinux.amlogic.com:8000/deploy/TOOLSENV.sh"
echo -e "\n4. update TOOLSENV.sh to match installed versions of libraries"
echo -e "\n-------------------------------------------------------------------------------------------------------------------"
echo -e "\n"

read -p "\nPress enter key to continue... "

# enter to the root folder of synced sources of khadas
cd ~/khadas

# frst thing first, sync sources
echo -e "\nrepo sync sources"
repo sync --force-sync -c

# let's setup toolchain environment variables
echo -e "\nSet toolchain variables"
source TOOLSENV.sh

# let's setup build variables
echo -e "\nSet build environment"
source build/envsetup.sh

# option to make installclean before build to cleanup sources
# comment it ut if you don't want to make installclean
echo -e "\nlet's make installclean build"
make installclean

# let's build U-BOOT stuff needed by main build
echo -e "\nbuild U-BOOT stuff for Nougat"
cd ~/khadas/uboot
echo -e "\ncheckout Nougat branch"
git checkout Nougat
echo -e "\nBuild U-BOOT"
make CROSS_COMPILE=aarch64-linux-gnu- kvim2_defconfig
make CROSS_COMPILE=aarch64-linux-gnu-

echo -e "\nEntering kahadas root folder before build"
cd ~/khadas

# depending of build type you can change here user or eng build, eg. kvim2-user-64
echo -e "\nwe are doing kvim2-userdebug-64"
lunch kvim2-userdebug-64

# lets build: N is how many threads your build linux box is gonna use
echo -e "\nStart build!"
make -j4 otapackage

echo -e "\nBuild FINISHED!"

# additional 
# lets build update.img
# 1. create folder images inside khadas root (that's how I did it you can always choose different location)
# 2. git clone https://github.com/khadas/utils into ~/khadas/utils
# 3. create symlink to out/target/product/kvim2/upgrade/ in ~/khadas/upgrade
# 4. uncomment rest of the lines ;-)
#echo -e "\nLet's build update.img"
#./utils/aml_image_v2_packer -r upgrade/aml_upgrade_package.conf upgrade/ images/update.img