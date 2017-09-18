#!/bin/bash

clear

echo "Simple script to automate build of Android Nougat (7.1.x) for VIM2 on linux box"
echo ""
echo "-------------------------------------------------------------------------------------------------------------------"
echo "How to use it:"
echo "1. follow initial documentation on http://docs.khadas.com/develop/DownloadAndroidSourceCode/"
echo "2. download amlogic dev libs from http://openlinux.amlogic.com:8000/deploy/ and install them inside /opt/toolchains"
echo "   by running: "
echo "     (notice - change version numbers to match one downloaded)" 
echo "     sudo tar xvf gcc-linaro-aarch64-linux-gnu-4.9-2014.09_linux.tar -C /opt/toolchains"
echo "     sudo tar xvf gcc-linaro-aarch64-none-elf-4.8-2013.11_linux.tar.bz2 -C /opt/toolchains"
echo "     sudo tar xvf arc-4.8-amlogic-20130904-r2.tar.gz -C /opt/toolchains"
echo "     sudo tar xvf gcc-linaro-arm-linux-gnueabihf.tar.gz -C /opt/toolchains"
echo "     sudo tar xvf CodeSourcery.tar.gz -C /opt/toolchains"
echo "2. put TOOLSENV.sh inside src folder of synced khadas: wget http://openlinux.amlogic.com:8000/deploy/TOOLSENV.sh"
echo "3. update TOOLSENV.sh to match installed versions of libraries"
echo "4. To be uptodate with khadas sources run repo sync before build"
echo "-------------------------------------------------------------------------------------------------------------------"
echo ""

read -p "Press enter key to continue... "

# enter to the root folder of synced sources of khadas
cd ~/khadas

# let's setup toolchain environment variables
source TOOLSENV.sh

# let's build U-BOOT stuff needed by main build
cd ~/khadas/uboot
make CROSS_COMPILE=aarch64-linux-gnu- kvim2_defconfig
make CROSS_COMPILE=aarch64-linux-gnu-


cd ~/khadas

# let's setup build variables
source build/envsetup.sh

# depending of build type you can change here user or eng build, eg. kvim2-user-64
lunch kvim2-userdebug-64

# lets build: N is how many threads your build linux box is gonna use
make -j4 otapackage