#!/bin/bash
#----------
target_img=
parts=
wipe=
reset=
soc=
uboot_file=
efuse_file=
password=
destroy=
update_return=
debug=0
simu=0
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RESET='\033[m'
TOOL_PATH="$(cd $(dirname $0); pwd)"
SYSTEM='linux-x86'
EXE=

# Helper
# ------
show_help()
{
    echo "Usage      : $0 --img=/path/to/aml_upgrade_package.img> --parts=<all|none|bootloader|dtb|logo|recovery|boot|system|..> [--wipe] [--reset=<y|n>] [--soc=<m8|axg|gxl|txlx|g12a>] [efuse-file=/path/to/file/location] [bootloader|dtb|logo|boot|...-file=/path/to/file/partition] [--password=/path/to/password.bin]"
    echo "Version    : 4.9"
    echo "Parameters : --img        => Specify location path to aml_upgrade_package.img"
    echo "             --parts      => Specify which partition to burn"
    echo "             --wipe       => Destroy all partitions"
    echo "             --reset      => Force reset mode at the end of the burning"
    echo "             --soc        => Force soc type (gxl=S905/S912,axg=A113,txlx=T962,g12a=S905X2,m8=S805/A111)"
    echo "             --efuse-file => Force efuse OTP burn, use this option carefully "
    echo "             --*-file     => Force overload of partition files"
    echo "             --password   => Unlock usb mode using password file provided"
    echo "             --destroy    => Erase the bootloader and reset the board"
}

# Check if a given file exists and exit if not
# --------------------------------------------
check_file()
{
    if [[ "$simu" != "1" ]]; then
       if [[ ! -f $1 ]]; then
          echo "$1 not found"
          cleanup
          exit 1
       fi
    fi
}

# Trap called on Ctrl-C
# ---------------------
cleanup()
{
    echo -e $RESET
    print_debug "Cleanup"
    [[ -d $tmp_dir ]] && rm -rf "$tmp_dir"
}
cleanup_trap()
{
    cleanup
    exit 1
}

# Print debug function
# --------------------
print_debug()
{
   if [[ $debug == 1 ]]; then
      echo -e $YELLOW"$1"$RESET
   fi
}

# Wrapper for the Amlogic 'update' command
# ----------------------------------------
run_update_return()
{
    local cmd
    local need_spaces

    cmd="$TOOL_PATH/tools/$SYSTEM/update$EXE 2>/dev/null"
    need_spaces=0
    if [[ "$1" == "bulkcmd" ]] || [[ "$1" == "tplcmd" ]]; then
       need_spaces=1
    fi
    cmd+=" $1"
    shift 1

    for arg in "$@"; do
        if [[ "$arg" =~ ' ' ]]; then
           cmd+=" \"     $arg\""
        else
           if [[ $need_spaces == 1 ]]; then
              cmd+=" \"     $arg\""
           else
              cmd+=" $arg"
           fi
        fi
    done

    update_return=""
    print_debug "\nCommand ->$CYAN $cmd $RESET"
    if [[ "$simu" != "1" ]]; then
       update_return=`eval "$cmd"`
    fi
    print_debug "- Results ---------------------------------------------------"
    print_debug "$RED $update_return $RESET"
    print_debug "-------------------------------------------------------------"
    print_debug ""
    return 0
}

# Wrapper to the Amlogic 'update' command
# ---------------------------------------
run_update()
{
    local cmd
    local ret=0

    run_update_return "$@"

    if `echo $update_return | grep -q "ERR"`; then
       ret=1
    fi

    return $ret
}

# Assert update wrapper
# ---------------------
run_update_assert()
{
    run_update "$@"
    if [[ $? != 0 ]]; then
       echo -e $RED"[KO]"
       cleanup
       exit 1
    fi
}

# Parse options
# -------------
for opt do
    optval="${opt#*=}"
    case "${opt%=*}" in
    --help|-h)
        show_help $(basename $0)
        exit 0
        ;;
    --img)
        target_img="$optval"
        check_file $target_img
        ;;
    --parts)
        parts="$optval"
        ;;
    --wipe)
        wipe=1
        ;;
    --reset)
        reset="$optval"
        ;;
    --efuse-file)
        efuse_file="$optval"
        check_file $efuse_file
        ;;
    --uboot-file)
        uboot_file="$optval"
        check_file $uboot_file
        ;;
    --soc)
        soc="$optval"
        ;;
    --password)
        password="$optval"
        check_file $password
        password_size=`wc -c "$password" | awk '{print $1}'`

	;;
    --destroy)
        destroy=1
        ;;
    --debug)
        debug=1
        ;;
    *)
        if [[ ${opt%=*} == "--"*"-file" ]]; then
           newvar=`echo ${opt%=*} | sed 's/--//' | sed 's/-file/_file/'`
           newvar_type=$newvar"_type"
           declare "${newvar}"="`echo $optval|awk -F',' '{print $1}'`"
           declare "${newvar_type}"="`echo $optval|awk -F',' '{print $2}'`"
           print_debug "$newvar=${!newvar} $newvar_type=${!newvar_type}"
           check_file ${!newvar}
        fi
        ;;
    esac
done

# Testing host machine
# --------------------
host_os=`uname -a|grep Linux`
host_machine=`uname -a|grep -i "x86"`
if [ ! -z "$host_os" ]; then
   if [ ! -z "$host_machine" ]; then
      SYSTEM='linux-x86'
      EXE=''
   else
     SYSTEM='linux-arm'
     EXE=''
   fi
else
   SYSTEM='windows'
   EXE='.exe'
fi
print_debug "host_os      = $host_os"
print_debug "host_machine = $host_machine"
print_debug "SYSTEM       = $SYSTEM"
print_debug "EXE          = $EXE"

# Check parameters
# ----------------
if [[ -z $destroy ]]; then
   if [[ -z $target_img ]]; then
      echo "Missing --img argument"
      show_help
      exit 1
   fi
   if [[ -z $parts ]]; then
      echo "Missing --parts argument"
      exit 1
   fi
fi
if [[ -z $soc ]]; then
   soc=gxl
fi
if [[ "$soc" != "m8" ]] && [[ "$soc" != "gxl" ]] && [[ "$soc" != "axg" ]] && [[ "$soc" != "txlx" ]] && [[ "$soc" != "g12a" ]]; then
   echo "Soc type is invalid, should be either m8,gxl,axg,txlx,g12a"
   exit 1
fi
run_update_return identify 7
if [[ "$simu" != "1" ]]; then
   if ! `echo $update_return | grep -iq firmware`; then
      echo "Amlogic device not found"
      exit 1
   fi
fi

# Set trap
# --------
trap cleanup_trap SIGHUP SIGINT SIGTERM

# Check if the board is locked with a password
# --------------------------------------------
need_password=0
run_update_return identify 7
if `echo $update_return | grep -iq "Password check NG"`; then
   need_password=1
fi
if [[ $need_password == 1 ]]; then
   if [[ -z $password ]]; then
     echo "The board is locked with a password, please provide a password using --password option !"
     exit 1
   fi
fi

# Unlock usb mode by password
# ---------------------------
if [[ $need_password == 1 ]]; then
   if [[ $password != "" ]]; then
      echo -n "Unlocking usb interface "
      run_update_assert password $password
      run_update_return identify 7
      if `echo $update_return | grep -iq "Password check OK"`; then
         echo -e $GREEN"[OK]"$RESET
      else
         echo -e $RED"[KO]"$RESET
         echo "It seems you provided an incorrect password !"
         exit 1
      fi
   fi
fi

# Create tmp directory
# --------------------
if [[ "$SYSTEM" == "windows" ]]; then
   tmp_dir="C:/tmp/aml-flash-tool"`date +%H%M%S`
   mkdir -p $tmp_dir
else
   tmp_dir=$(mktemp -d /tmp/aml-flash-tool-XXXX)
fi

# Should we destroy the boot ?
# ----------------------------
if [[ "$parts" == "all" ]] || [[ "$parts" == "bootloader" ]] || [[ "$parts" == "" ]] || [[ "$parts" == "none" ]]; then
   run_update bulkcmd "echo 12345"
   #run_update bulkcmd "low_power"
   if [[ $? = 0 ]]; then
      echo -n "Rebooting the board "
      run_update bulkcmd "bootloader_is_old"
      # Actually this command don't really erase the bootloader, it reboot to prepare update
      run_update_assert bulkcmd "erase_bootloader"
      if [[ $destroy == 1 ]]; then
        run_update bulkcmd "store erase boot"
        run_update bulkcmd "amlmmc erase 1"
        run_update bulkcmd "nand erase 0 4096"
      fi
      run_update bulkcmd "reset"
      if [[ $destroy == 1 ]]; then
        echo -e $GREEN"[OK]"$RESET
        cleanup
        exit 0
      fi
      for i in {1..8}
         do
         echo -n "."
         sleep 1
      done
      echo -e $GREEN"[OK]"$RESET
   else
     if [[ $destroy == 1 ]]; then
        echo "Seems board is already in usb mode, nothing to do more..."
        cleanup
        exit 0
     fi
   fi
fi
if [[ $destroy == 1 ]]; then
   cleanup
   exit 0
fi

# Unlock usb mode by password
# ---------------------------
# If we started with usb mode from uboot, the password is already unlocked
# But just after we reset the board, then fall into rom mode
# That's why we need to recheck password lock a second time
need_password=0
run_update_return identify 7
if `echo $update_return | grep -iq "Password check NG"`; then
   need_password=1
fi
if [[ $need_password == 1 ]]; then
   if [[ -z $password ]]; then
      echo "The board is locked with a password, please provide a password using --password option !"
      cleanup
      exit 1
   fi
fi
if [[ $need_password == 1 ]]; then
   if [[ $password != "" ]]; then
      echo -n "Unlocking usb interface "
      run_update_assert password $password
      run_update_return identify 7
      if `echo $update_return | grep -iq "Password check OK"`; then
         echo -e $GREEN"[OK]"$RESET
      else
         echo -e $RED"[KO]"$RESET
         echo "It seems you provided an incorrect password !"
         cleanup
         exit 1
      fi
   fi
fi

# Read chip id
# ------------
#if [[ "$soc" == "auto" ]]; then
#  echo -n "Identify chipset type "
#  value=`$TOOL_PATH/tools/update chipid|grep ChipID|cut -d ':' -f2|xxd -r -p|cut -c1-6`
#  echo $value
#  if [[ "$value" == "AMLGXL" ]]; then
#     soc=gxl
#  fi
#  if [[ "$value" == "AMLAXG" ]]; then
#     soc=axg
#  fi
#  if [[ "$soc" != "gxl" ]] && [[ "$soc" != "txlx" ]] && [ "$soc" != "g12a" ]] && [[ "$soc" != "axg" ]] && [[ "$soc" != "m8" ]]; then
#     echo -e $RED"[KO]"$RESET
#     echo "Unable to identify chipset, Try by forcing it manually with --soc=<gxl,axg,txlx,g12a,m8>"
#     cleanup
#     exit 1
#  else
#     echo -e $GREEN"["$value"]"$RESET
#  fi
#fi

# Check if board is secure
# ------------------------
secured=0
value=0
# Board secure info is extracted from SEC_AO_SEC_SD_CFG10 register
if [[ "$soc" == "gxl" ]]; then
   run_update_return rreg 4 0xc8100228
   value=0x`echo $update_return|grep -i c8100228|awk -F: '{gsub(/ /,"",$2);print $2}'`
   print_debug "0xc8100228      = $value"
   value=$(($value & 0x10))
   print_debug "Secure boot bit = $value"
fi
if [[ "$soc" == "axg" ]] || [[ $soc == "txlx" ]] || [[ $soc == "g12a" ]]; then
   run_update_return rreg 4 0xff800228
   value=0x`echo $update_return|grep -i ff800228|awk -F: '{gsub(/ /,"",$2);print $2}'`
   print_debug "0xff800228      = $value"
   value=$(($value & 0x10))
   print_debug "Secure boot bit = $value"
fi
if [[ "$soc" == "m8" ]]; then
   run_update_return rreg 4 0xd9018048
   value=0x`echo $update_return|grep -i d9018048|awk -F: '{gsub(/ /,"",$2);print $2}'`
   print_debug "0xd9018048      = $value"
   value=$(($value & 0x80))
   print_debug "Secure boot bit = $value"
fi
if [[ $value != 0 ]]; then
   secured=1
   echo "Board is in secure mode"
fi

# Unpack image if image is given
# ------------------------------
echo -n "Unpacking image "
return_value=`$TOOL_PATH/tools/$SYSTEM/aml_image_v2_packer$EXE -d $target_img $tmp_dir`
print_debug "\n$return_value"
if [[ -z `echo $return_value|grep "Image unpack OK!"` ]]; then
   echo -e $RED"[KO]"$RESET
   cleanup
   exit 1
fi
echo -e $GREEN"[OK]"$RESET
print_debug ""
print_debug "Parsing image configuration files"
print_debug "---------------------------------"
source /etc/lsb-release
if linux-version compare $DISTRIB_RELEASE ge 19.10; then
	platform_conf_name=`awk '/sub_type="platform"/{gsub("file=","",$1); gsub(/"/,"",$1); print $1}' $tmp_dir/image.cfg`
	print_debug "platform_conf_name  = $platform_conf_name"
	ddr_filename=`awk '/sub_type="DDR"/{gsub("file=","",$1); gsub(/"/,"",$1); print $1}' $tmp_dir/image.cfg`
	print_debug "ddr_filename        = $ddr_filename"
	uboot_filename=`awk '/sub_type="UBOOT"/{gsub("file=","",$1); gsub(/"/,"",$1); print $1}' $tmp_dir/image.cfg`
	print_debug "uboot_filename      = $uboot_filename"
	uboot_comp_filename=`awk '/sub_type="UBOOT_COMP"/{gsub("file=","",$1); gsub(/"/,"",$1); print $1}' $tmp_dir/image.cfg`
	print_debug "uboot_comp_filename = $uboot_comp_filename"
	dtb_meson_filename=`awk '/sub_type="meson"/{gsub("file=","",$1); gsub(/"/,"",$1); print $1}' $tmp_dir/image.cfg`
	print_debug "dtb_meson_filename  = $dtb_meson_filename"
	dtb_meson1_filename=`awk '/sub_type="meson1"/{gsub("file=","",$1); gsub(/"/,"",$1); print $1}' $tmp_dir/image.cfg`
	print_debug "dtb_meson1_filename = $dtb_meson1_filename"
	dtb_meson1_enc_filename=`awk '/sub_type="meson1_ENC"/{gsub("file=","",$1); gsub(/"/,"",$1); print $1}' $tmp_dir/image.cfg`
	print_debug "dtb_meson1_enc_filename = $dtb_meson1_enc_filename"
	ddr_enc_filename=`awk '/sub_type="DDR_ENC"/{gsub("file=","",$1); gsub(/"/,"",$1); print $1}' $tmp_dir/image.cfg`
	print_debug "ddr_enc_filename    = $ddr_enc_filename"
	uboot_enc_filename=`awk '/sub_type="UBOOT_ENC"/{gsub("file=","",$1); gsub(/"/,"",$1); print $1}' $tmp_dir/image.cfg`
	print_debug "uboot_enc_filename  = $uboot_enc_filename"
	keys_filename=`awk '/sub_type="keys"/{gsub("file=","",$1); gsub(/"/,"",$1); print $1}' $tmp_dir/image.cfg`
	print_debug "keys_filename       = $keys_filename"
	platform=`awk '/Platform:/{gsub("Platform:","",$1); print $1}' $tmp_dir/$platform_conf_name`
	print_debug "platform            = $platform"
	bin_params=`awk '/BinPara:/{gsub("BinPara:","",$1); print $1}' $tmp_dir/$platform_conf_name`
	print_debug "bin_params          = $bin_params"
	ddr_load=`awk '/DDRLoad:/{gsub("DDRLoad:","",$1); print $1}' $tmp_dir/$platform_conf_name`
	print_debug "ddr_load            = $ddr_load"
	ddr_run=`awk '/DDRRun:/{gsub("DDRRun:","",$1); print $1}' $tmp_dir/$platform_conf_name`
	print_debug "ddr_run             = $ddr_run"
	uboot_down=`awk '/Uboot_down:/{gsub("Uboot_down:","",$1); print $1}' $tmp_dir/$platform_conf_name`
	print_debug "uboot_down          = $uboot_down"
	uboot_decomp=`awk '/Uboot_decomp:/{gsub("Uboot_decomp:","",$1); print $1}' $tmp_dir/$platform_conf_name`
	print_debug "uboot_decomp        = $uboot_decomp"
	uboot_enc_down=`awk '/Uboot_enc_down:/{gsub("Uboot_enc_down:","",$1); print $1}' $tmp_dir/$platform_conf_name`
	print_debug "uboot_enc_down      = $uboot_enc_down"
	uboot_enc_run=`awk '/Uboot_enc_run:/{gsub("Uboot_enc_run:","",$1); print $1}' $tmp_dir/$platform_conf_name`
	print_debug "uboot_enc_run       = $uboot_enc_run"
	uboot_load=`awk '/UbootLoad:/{gsub("UbootLoad:","",$1); print $1}' $tmp_dir/$platform_conf_name`
	print_debug "uboot_load          = $uboot_load"
	uboot_run=`awk '/UbootRun:/{gsub("UbootRun:","",$1); print $1}' $tmp_dir/$platform_conf_name`
	print_debug "uboot_run           = $uboot_run"
	bl2_params=`awk '/bl2ParaAddr=/{gsub("bl2ParaAddr=","",$1); print $1}' $tmp_dir/$platform_conf_name`
	print_debug "bl2_params          = $bl2_params"
	nb_partitions=`awk '/main_type="PARTITION"/{print}' $tmp_dir/image.cfg|wc -l`
	print_debug "nb_partitions       = $nb_partitions"
	partitions_file=( `awk '/main_type="PARTITION"/{gsub("file=","",$1); gsub(/"/,"",$1); print $1}' $tmp_dir/image.cfg | xargs` )
	partitions_name=( `awk '/main_type="PARTITION"/{gsub("sub_type=","",$3); gsub(/"/,"",$3); print $3}' $tmp_dir/image.cfg | xargs` )
	partitions_type=( `awk '/main_type="PARTITION"/{gsub("file_type=","",$4); gsub(/"/,"",$4); print $4}' $tmp_dir/image.cfg | xargs` )
else
	platform_conf_name=`awk '/sub_type=\"platform\"/{gsub("file=","",$1); gsub(/"/,"",$1); print $1}' $tmp_dir/image.cfg`
	print_debug "platform_conf_name  = $platform_conf_name"
	ddr_filename=`awk '/sub_type=\"DDR\"/{gsub("file=","",$1); gsub(/"/,"",$1); print $1}' $tmp_dir/image.cfg`
	print_debug "ddr_filename        = $ddr_filename"
	uboot_filename=`awk '/sub_type=\"UBOOT\"/{gsub("file=","",$1); gsub(/"/,"",$1); print $1}' $tmp_dir/image.cfg`
	print_debug "uboot_filename      = $uboot_filename"
	uboot_comp_filename=`awk '/sub_type=\"UBOOT_COMP\"/{gsub("file=","",$1); gsub(/"/,"",$1); print $1}' $tmp_dir/image.cfg`
	print_debug "uboot_comp_filename = $uboot_comp_filename"
	dtb_meson_filename=`awk '/sub_type=\"meson\"/{gsub("file=","",$1); gsub(/"/,"",$1); print $1}' $tmp_dir/image.cfg`
	print_debug "dtb_meson_filename  = $dtb_meson_filename"
	dtb_meson1_filename=`awk '/sub_type=\"meson1\"/{gsub("file=","",$1); gsub(/"/,"",$1); print $1}' $tmp_dir/image.cfg`
	print_debug "dtb_meson1_filename = $dtb_meson1_filename"
	dtb_meson1_enc_filename=`awk '/sub_type=\"meson1_ENC\"/{gsub("file=","",$1); gsub(/"/,"",$1); print $1}' $tmp_dir/image.cfg`
	print_debug "dtb_meson1_enc_filename = $dtb_meson1_enc_filename"
	ddr_enc_filename=`awk '/sub_type=\"DDR_ENC\"/{gsub("file=","",$1); gsub(/"/,"",$1); print $1}' $tmp_dir/image.cfg`
	print_debug "ddr_enc_filename    = $ddr_enc_filename"
	uboot_enc_filename=`awk '/sub_type=\"UBOOT_ENC\"/{gsub("file=","",$1); gsub(/"/,"",$1); print $1}' $tmp_dir/image.cfg`
	print_debug "uboot_enc_filename  = $uboot_enc_filename"
	keys_filename=`awk '/sub_type=\"keys\"/{gsub("file=","",$1); gsub(/"/,"",$1); print $1}' $tmp_dir/image.cfg`
	print_debug "keys_filename       = $keys_filename"
	platform=`awk '/Platform:/{gsub("Platform:","",$1); print $1}' $tmp_dir/$platform_conf_name`
	print_debug "platform            = $platform"
	bin_params=`awk '/BinPara:/{gsub("BinPara:","",$1); print $1}' $tmp_dir/$platform_conf_name`
	print_debug "bin_params          = $bin_params"
	ddr_load=`awk '/DDRLoad:/{gsub("DDRLoad:","",$1); print $1}' $tmp_dir/$platform_conf_name`
	print_debug "ddr_load            = $ddr_load"
	ddr_run=`awk '/DDRRun:/{gsub("DDRRun:","",$1); print $1}' $tmp_dir/$platform_conf_name`
	print_debug "ddr_run             = $ddr_run"
	uboot_down=`awk '/Uboot_down:/{gsub("Uboot_down:","",$1); print $1}' $tmp_dir/$platform_conf_name`
	print_debug "uboot_down          = $uboot_down"
	uboot_decomp=`awk '/Uboot_decomp:/{gsub("Uboot_decomp:","",$1); print $1}' $tmp_dir/$platform_conf_name`
	print_debug "uboot_decomp        = $uboot_decomp"
	uboot_enc_down=`awk '/Uboot_enc_down:/{gsub("Uboot_enc_down:","",$1); print $1}' $tmp_dir/$platform_conf_name`
	print_debug "uboot_enc_down      = $uboot_enc_down"
	uboot_enc_run=`awk '/Uboot_enc_run:/{gsub("Uboot_enc_run:","",$1); print $1}' $tmp_dir/$platform_conf_name`
	print_debug "uboot_enc_run       = $uboot_enc_run"
	uboot_load=`awk '/UbootLoad:/{gsub("UbootLoad:","",$1); print $1}' $tmp_dir/$platform_conf_name`
	print_debug "uboot_load          = $uboot_load"
	uboot_run=`awk '/UbootRun:/{gsub("UbootRun:","",$1); print $1}' $tmp_dir/$platform_conf_name`
	print_debug "uboot_run           = $uboot_run"
	bl2_params=`awk '/bl2ParaAddr=/{gsub("bl2ParaAddr=","",$1); print $1}' $tmp_dir/$platform_conf_name`
	print_debug "bl2_params          = $bl2_params"
	nb_partitions=`awk '/main_type=\"PARTITION\"/{print}' $tmp_dir/image.cfg|wc -l`
	print_debug "nb_partitions       = $nb_partitions"
	partitions_file=( `awk '/main_type=\"PARTITION\"/{gsub("file=","",$1); gsub(/"/,"",$1); print $1}' $tmp_dir/image.cfg | xargs` )
	partitions_name=( `awk '/main_type=\"PARTITION\"/{gsub("sub_type=","",$3); gsub(/"/,"",$3); print $3}' $tmp_dir/image.cfg | xargs` )
	partitions_type=( `awk '/main_type=\"PARTITION\"/{gsub("file_type=","",$4); gsub(/"/,"",$4); print $4}' $tmp_dir/image.cfg | xargs` )
fi

print_debug ""
print_debug "Partition list"
print_debug "--------------"
for i in $(seq 0 `expr $nb_partitions - 1`)
do
  print_debug "$i ${partitions_file[$i]} ${partitions_name[$i]} ${partitions_type[$i]}" 
done
print_debug ""

# Bootloader update
# -----------------
if [[ "$parts" == "all" ]] || [[ "$parts" == "bootloader" ]] || [[ "$parts" == "none" ]]; then
   if [[ $soc == "gxl" ]] || [[ $soc == "axg" ]] || [[ $soc == "txlx" ]]; then
      ddr=$TOOL_PATH/tools/datas/usbbl2runpara_ddrinit.bin
      fip=$TOOL_PATH/tools/datas/usbbl2runpara_runfipimg.bin
      check_file $ddr
      check_file $fip
      fi
   if [[ $soc == "m8" ]]; then
      fip=$TOOL_PATH/tools/datas/decompressPara_4M.dump
      check_file $fip
   fi

   if [[ -z $bootloader_file ]]; then
      for i in $(seq 0 `expr $nb_partitions - 1`)
      do
      if [[ "${partitions_name[$i]}" == "bootloader" ]]; then
         bootloader_file=$tmp_dir/${partitions_file[$i]}
         break
      fi
      done
   fi
   if [[ -z $dtb_file ]]; then
      if [[ $soc == "gxl" ]] || [[ $soc == "axg" ]] || [[ $soc == "txlx" ]] || [[ $soc == "g12a" ]]; then
         for i in $(seq 0 `expr $nb_partitions - 1`)
         do
         if [[ "${partitions_name[$i]}" == "_aml_dtb" ]]; then
            dtb_file=$tmp_dir/${partitions_file[$i]}
            break
         fi
         done
      fi
      if [[ $soc == "m8" ]]; then
         dtb_file=$tmp_dir/$dtb_meson_filename
      fi
   fi

   print_debug "Bootloader/DTB files"
   print_debug "--------------------"
   print_debug "bootloader_file = $bootloader_file"
   print_debug "dtb_file        = $dtb_file"

   check_file "$bootloader_file"
   check_file "$dtb_file"

   if [[ -z $uboot_file ]]; then
      if [[ $secured == 0 ]]; then
         bl2=$tmp_dir/$ddr_filename
         if [[ -z $uboot_comp_filename ]]; then
            tpl=$tmp_dir/$uboot_filename
         else
            tpl=$tmp_dir/$uboot_comp_filename
         fi
      else
         bl2=$tmp_dir/$ddr_enc_filename
         tpl=$tmp_dir/$uboot_enc_filename
         if [[ -z "$ddr_enc_filename" ]] || [[ -z "$uboot_enc_filename" ]]; then
            echo "Your board is secured but the image you want to flash does not contain any signed bootloader !"
            echo "Please check, flashing can't continue..."
            cleanup
            exit 1
         fi
      fi
   else
      print_debug "uboot_file      = $uboot_file"
      if [[ $soc == "gxl" ]] || [[ $soc == "axg" ]] || [[ $soc == "txlx" ]]; then
         print_debug "uboot_file      = $uboot_file"
         bl2=$tmp_dir/uboot_file_bl2.bin
         tpl=$tmp_dir/uboot_file_tpl.bin
         dd &>/dev/null if=$uboot_file of=$bl2 bs=49152 count=1
         dd &>/dev/null if=$uboot_file of=$tpl bs=49152 skip=1
      else
         bl2=$tmp_dir/$ddr_filename
         tpl=$uboot_file
      fi
   fi

   print_debug ""
   if [[ ! -z "$bl2" ]]; then
      check_file "$bl2"
   fi
   if [[ ! -z "$tpl" ]]; then
      check_file "$tpl"
   fi

   echo -n "Initializing ddr "
   if [[ $soc == "gxl" ]] || [[ $soc == "axg" ]] || [[ $soc == "txlx" ]]; then
      run_update_assert cwr   "$bl2" $ddr_load
      run_update_assert write "$ddr" $bl2_params
      run_update_assert run          $ddr_run
      for i in {1..8}
      do
          echo -n "."
          sleep 1
      done
      run_update_return identify 7
      if ! `echo $update_return | grep -iq firmware`; then
         echo -e $RED"[KO]"$RESET
         cleanup
         exit 1
      fi
      usb_protocol=`echo $update_return|awk -F- '{print $4}'`
      # If new usb protocol, init DDR
      if [[ $usb_protocol == "8" ]]; then
         run_update_assert run $bl2_params
      fi
   fi
   if [[ $soc == "g12a" ]]; then
      run_update_assert write "$tpl" $ddr_load 0x10000
      run_update_assert run $ddr_load
      for i in {1..8}
      do
          echo -n "."
          sleep 1
      done
   fi
   if [[ $soc == "m8" ]]; then
      for i in {1..6}
      do
          echo -n "."
          sleep 1
      done
      run_update_assert cwr "$bl2" $ddr_load
      run_update_assert run        $ddr_run
      for i in {1..8}
      do
          echo -n "."
          sleep 1
      done
   fi
   echo -e $GREEN"[OK]"$RESET

   echo -n "Running u-boot "
   if [[ $soc == "gxl" ]] || [[ $soc == "axg" ]] || [[ $soc == "txlx" ]]; then
      run_update_assert write "$bl2" $ddr_load
      run_update_assert write "$fip" $bl2_params # tell bl2 to jump to tpl, aka u-boot
      run_update_assert write "$tpl" $uboot_load
      if [[ $usb_protocol == "8" ]]; then
         run_update_assert run $bl2_params
      else
         run_update_assert run $uboot_run
      fi
   fi
   if [[ $soc == "g12a" ]]; then
      run_update_assert bl2_boot "$tpl"
   fi
   if [[ $soc == "m8" ]]; then
      run_update_assert write "$fip" $bin_params
      if [[ $secured == 0 ]]; then
         run_update_assert write "$tpl" 0x00400000
         run_update_assert run          $uboot_decomp
         for i in {1..13}
         do
            echo -n "."
            sleep 1
         done
         value=`echo "obase=16;$(($bin_params + 0x18))"|bc`
         run_update_return rreg 4 0x$value
         jump_addr=0x`echo $update_return|awk -F: '{gsub(/ /,"",$2);print $2}'`
         print_debug "Jumping to $jump_addr"
         run_update_assert run  $jump_addr
      else
         run_update_assert write "$tpl" $uboot_enc_down
         run_update_assert run          $uboot_enc_run
         for i in {1..8}
         do
            echo -n "."
            sleep 1
         done
      fi
   fi
   for i in {1..8}
   do
       echo -n "."
       sleep 1
   done
   echo -e $GREEN"[OK]"$RESET

   # Need this command to avoid to loose 4 bytes of commands after reset
   run_update bulkcmd "echo 12345"
   #run_update bulkcmd "low_power"

   if [[ $soc == "gxl" ]] || [[ $soc == "axg" ]] || [[ $soc == "txlx" ]] || [[ $soc == "g12a" ]]; then
      if [[ $secured == 1 ]]; then
         check_file "$tmp_dir/$dtb_meson1_enc_filename"
         run_update_assert mwrite "$tmp_dir/$dtb_meson1_enc_filename" mem dtb normal
      else
         check_file "$tmp_dir/$dtb_meson1_filename"
         run_update_assert mwrite "$tmp_dir/$dtb_meson1_filename" mem dtb normal
      fi
      if [[ "$parts" != "none" ]]; then
         echo -n "Create partitions "
         if [[ $wipe == 1 ]]; then
            run_update_assert bulkcmd "disk_initial 1"
          else
            run_update_assert bulkcmd "disk_initial 0"
          fi
          echo -e $GREEN"[OK]"$RESET

          echo -n "Writing device tree "
          run_update_assert partition _aml_dtb "$dtb_file"
          echo -e $GREEN"[OK]"$RESET

          echo -n "Writing bootloader "
          run_update_assert partition bootloader "$bootloader_file"
          #run_update_assert bulkcmd "env default -a"
          #run_update_assert bulkcmd "saveenv"
          echo -e $GREEN"[OK]"$RESET
      fi
   else
      if [[ "$parts" != "none" ]]; then
         echo -n "Creating partitions "
         if [[ $wipe == 1 ]]; then
            run_update bulkcmd "disk_initial 3"
            run_update_assert bulkcmd "disk_initial 2"
         else
            run_update_assert bulkcmd "disk_initial 0"
         fi
         echo -e $GREEN"[OK]"$RESET

         echo -n "Writing bootloader "
         run_update_assert partition bootloader "$bootloader_file"
         echo -e $GREEN"[OK]"$RESET

         echo -n "Writing device tree "
         run_update_assert mwrite $dtb_file mem dtb normal
         echo -e $GREEN"[OK]"$RESET
      fi
   fi
   if [[ "$parts" != "none" ]]; then
      run_update bulkcmd "setenv upgrade_step 1"
      run_update bulkcmd "save"
   fi
   if [[ "$soc" == "m8" ]]; then
      run_update bulkcmd "save_setting"
   fi
fi

# Check chip version
# ------------------
# Chip version is extracted from SEC_AO_SEC_SD_CFG8 register
# if [[ "$soc" == "gxl" ]]; then
#    sleep 5
#    run_update_return rreg 4 0xda100220
#    value=0x`echo $update_return|awk -F: '{gsub(/ /,"",$2);print $2}'`
#   print_debug "0xda100220 = $value"
#   chip_misc=$(($value & 0xff))
#   value=$(($value >> 8))
#   chip_minor=$(($value & 0xff))
#   value=$(($value >> 8))
#   chip_pack=$(($value & 0xf0))
#   value=$(($value >> 8))
#   chip_major=$(($value & 0xff))
#   printf "Chipset version $GREEN[%X:%X - %X:%X]$RESET\n" $chip_major $chip_minor $chip_pack $chip_misc
#fi
#if [[ "$soc" == "axg" ]] || [[ $soc == "txlx" ]] || [[ $soc == "g12a" ]]; then
#   run_update_return rreg 4 0xff800220
#   value=0x`echo $update_return|awk -F: '{gsub(/ /,"",$2);print $2}'`
#   print_debug "0xff800220 = $value"
#   chip_misc=$(($value & 0xff))
#   value=$(($value >> 8))
#   chip_minor=$(($value & 0xff))
#   value=$(($value >> 8))
#   chip_pack=$(($value & 0xf0))
#   value=$(($value >> 8))
#   chip_major=$(($value & 0xff))
#   printf "Chipset version $GREEN[%X:%X - %X:%X]$RESET\n" $chip_major $chip_minor $chip_pack $chip_misc
#fi

# Data and cache partitions wiping
# --------------------------------
if [[ $wipe == 1 ]]; then
   run_update bulkcmd "setenv firstboot 1"
   run_update bulkcmd "save"
   run_update bulkcmd "rpmb_reset"
fi
if [[ $soc != "m8" ]]; then
   if [[ $wipe == 1 ]]; then
      echo -n "Wiping  data partition "
      run_update bulkcmd "amlmmc erase data"
      run_update bulkcmd "nand erase.part data"
      echo -e $GREEN"[OK]"$RESET

      echo -n "Wiping  cache partition "
      run_update bulkcmd "amlmmc erase cache"
      run_update bulkcmd "nand erase.part cache"
      echo -e $GREEN"[OK]"$RESET
    fi
fi

# Program all the partitions
# --------------------------
for i in $(seq 0 `expr $nb_partitions - 1`)
do
if [[ "$parts" == "all" ]] || [[ "$parts" == "${partitions_name[$i]}" ]] || [[ "$parts" == "dtb" && "${partitions_name[$i]}" == "_aml_dtb" ]]; then
   if [[ ${partitions_name[$i]} == "bootloader" ]] || [[ ${partitions_name[$i]} == "_aml_dtb" && "$parts" != "dtb" ]]; then
      continue
   fi
   if [[ ${partitions_name[$i]} == "_aml_dtb" ]]; then
     newvar=dtb_file
     newvar_type=dtb_file_type
   else
     newvar=${partitions_name[$i]}_file
     newvar_type=${partitions_name[$i]}_file_type
   fi
   if [[ "${!newvar}" == "" ]]; then
     partition_file=$tmp_dir/${partitions_file[$i]}
   else
     partition_file=${!newvar}
   fi
   if [[ "${!newvar_type}" == "" ]]; then
     partition_type=${partitions_type[$i]}
   else
     partition_type=${!newvar_type}
   fi
   check_file $partition_file
   if [[ $"$parts" == "dtb" ]]; then
      echo -n "Writing dtb partition "
   else
      echo -n "Writing ${partitions_name[$i]} partition "
   fi
   run_update_assert partition ${partitions_name[$i]} $partition_file $partition_type
   echo -e $GREEN"[OK]"$RESET
fi
done

# Terminate burning tool
# ----------------------
#echo -n "Terminate update of the board "
#run_update_assert bulkcmd save_setting
#echo -e $GREEN"[OK]"$RESET

# eFuse update
# ------------
if [[ $efuse_file != "" ]]; then
   check_file "$efuse_file"
   echo -n "Programming efuses "
   run_update_assert write $efuse_file 0x03000000
   if [[ $soc == "m8" ]]; then
      run_update_assert bulkcmd "efuse secure_boot_set 0x03000000"
   else
      run_update_assert bulkcmd "efuse amlogic_set 0x03000000"
   fi
   echo -e $GREEN"[OK]"$RESET
   #run_update bulkcmd "low_power"
fi

# Cleanup
# -------
[[ -d $tmp_dir ]] && rm -rf "$tmp_dir"

# Resetting board ? 
# -----------------
if [[ "$parts" != "none" ]]; then
   if [[ -z "$reset" ]]; then
      while true; do
         read -p "Do you want to reset the board? y/n [n]? " reset
         if [[ $reset =~ [yYnN] ]]; then
            break
         fi
      done
   fi
   if [[ $reset =~ [yY] ]]; then
      echo -n "Resetting board "
      run_update bulkcmd "burn_complete 1"
      echo -e $GREEN"[OK]"$RESET
   fi
else
   echo "Uboot is now loaded into your board !"
   echo "You can use $TOOL_PATH/tools/update bulkcmd \"any uboot command\" to control uboot"
   echo "Examples :"
   echo "   - Select eMMC device :"
   echo "   update bulkcmd \"mmc dev 1\""
   echo "   - Read first block of eMMC at address 0x03000000"
   echo "   update bulkcmd \"mmc read 0x03000000 0 1\""
   echo "   - Save 512 bytes from address to 0x03000000 to host pc in file emmc.bin"
   echo "   update mread mem 0x03000000 normal 512 emmc.bin"
   echo "   - Write a file from host PC to address 0x03000000"
   echo "   update mwrite file.bin mem 0x03000000 normal"
   echo "   - Write to eMMC first block from address 0x03000000"
   echo "   update bulkcmd \"mmc write 0x03000000 0 1\""
   echo "   - Booting a kernel"
   echo "   update bulkcmd \"disk_initial 0\""
   echo "   update bulkcmd \"env default -a\""
   echo "   update bulkcmd \"run storeargs\""
   echo "   update bulkcmd \"run bootcmd\""
fi
