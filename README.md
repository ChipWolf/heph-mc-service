# Heph's Minecraft Service

## Assumptions

- No Java options are required _(there is a VAR for them in [srvctrl](home/minecraft/srvctrl.sh) if needed)_
- `JAVA_HOME` is located in `/usr/bin/java` _(there is also a VAR to change the path to your Java installation)_
- `rdiff-backup` and `screen` are installed as prerequisites

## Instructions

- Maintain the directory structure _(unless `VARS` in [srvctrl](home/minecraft/srvctrl.sh) are edited accordingly)_
- Copy lines from [crontab](crontab) to the crontab for user `minecraft` _(if this user does not yet exist, use the following command to create it)

```bash
sudo useradd -m -d /home/minecraft minecraft
```

## Notes

- [home/minecraft/backup](home/minecraft/backup) is the directory for the backup function
- [home/minecrafy/crashdb](home/minecraft/crashdb) is the directory where crash reports are dumped
- [home/minecraft/minecraft](home/minecraft/minecraft) is where server files should be placed
