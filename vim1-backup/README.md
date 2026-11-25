# VIM1 Pro V1.2 partition backup

These host utilities capture 14 boot and recovery partitions from a Khadas
VIM1 Pro V1.2 with its original Android 9 partition layout and 16 GB eMMC.
They require Bash, ADB authorized over USB, and working `su 0` on the device.
The tools check the board identity, eMMC capacity and size of every partition
before capturing an image. They were developed on macOS.

From this directory, check the board and list the partitions:

```sh
bin/vim1-doctor
bin/vim1-backup-critical --dry-run
```

To start a backup, provide a new output directory on private storage.
Allow at least 231 MiB free. The capture streams each partition over ADB,
checks its size and compares its SHA-256 with a second read on the device.

```sh
bin/vim1-backup-critical --confirm-read-only --output /path/to/new-backup
bin/vim1-verify-backup /path/to/new-backup
```

The second command needs only the saved images and manifest. Add
`--with-device` before the directory to compare with the connected board.
Android can change some partitions after capture. Store the images privately
because boot and security partitions may contain device-specific data.
The backup excludes userdata and the Android system partitions.

`bin/vim1-inventory` writes a metadata-only inventory. Run `tests/test.sh`
for the offline test suite.
