v1.28 revision:
1.support to download sparse image and  erase verity info
2.support to erase emmc using erase_lba

v1.3 revision:
1.support gpt download
2.add pl to read partition info from device

v1.31 revision:
1.UL decide to if reset or not after upgrade loader
2.add "rb_check_off"flag in the config.ini.close readback check when set rb_check_off=true

v1.32 revision:
1.DI command add -u -t -re for uboot trust resource
2.DI command chane calling convension of download multi image
3.config.ini place in the $HOME/.config/upgrade_tool/

v1.33 revision:
1.support fixed uuid in the gpt
add one line as following in the parameter:
uuid:partition_name=00000000-0000-0000-0000-000000000000