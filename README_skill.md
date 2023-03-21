# README_skill

本文件记录本人使用玩客云 Armbian+CasaOS 遇到的一些坑和使用技巧。

仅 Armbian 中测试，不一定适用其他系统和架构，请自行甄别。

## 使用技巧

### 一键换源

系统源
```sh
bash <(curl -sSL https://gitee.com/SuperManito/LinuxMirrors/raw/main/ChangeMirrors.sh)
```
Docker源
```sh
bash <(curl -sSL https://gitee.com/SuperManito/LinuxMirrors/raw/main/DockerInstallation.sh)
```

### 登录SSH输出系统信息

`/etc/update-motd.d/` 以下文件设为744权限

- 10-armbian-header
- 30-armbian-sysinfo

### 修改 mac 地址

`/etc/NetworkManager/system-connections/Wired connection 1.nmconnection`

修改 `cloned-mac-address=00:00:00:00:00:00`

### SD卡自动挂载卸载

新建 `/etc/udev/rules.d/11-auto-mount.rules` 内容如下
```
KERNEL!="mmcblk0*", GOTO="media_by_label_auto_mount_end"
ENV{mount_path}="/media"
SUBSYSTEM!="block",GOTO="media_by_label_auto_mount_end"
IMPORT{program}="/sbin/blkid -o udev -p %N"
ENV{ID_FS_TYPE}=="", GOTO="media_by_label_auto_mount_end"
ENV{ID_FS_LABEL}!="", ENV{dir_name}="%E{ID_FS_LABEL}"
ENV{ID_FS_LABEL}=="", ENV{dir_name}="%E{ID_FS_UUID}"
ACTION=="add", ENV{mount_options}="relatime,sync"
ACTION=="add", RUN+="/bin/mkdir -p %E{mount_path}/%E{dir_name}", RUN+="/usr/bin/systemd-mount -o %E{mount_options} --no-block --automount=yes --collect /dev/%k %E{mount_path}/%E{dir_name}"
ACTION=="remove", ENV{dir_name}!="", RUN+="/usr/bin/systemd-mount --umount %E{mount_path}/%E{dir_name}", RUN+="/bin/rmdir %E{mount_path}/%E{dir_name}"
LABEL="media_by_label_auto_mount_end"
```

> 第二行`ENV{mount_path}="/media"`可自定义挂载的目录。  
> CasaOS已提供自动挂载USB磁盘选项，以服务方式监听更佳，这里不做重复设置；否则还可以修改第一句此处`KERNEL!="sd*|mmcblk0*"`，原理是正则匹配设备名，不符合则跳过挂载。

### 系统启动后蓝灯

以下写入 `/etc/rc.local`，可修改可自定义颜色。
```
# 系统启动后蓝灯
echo 1 > /sys/class/leds/onecloud:blue:alive/brightness
echo 0 > /sys/class/leds/onecloud:green:alive/brightness
echo 0 > /sys/class/leds/onecloud:red:alive/brightness
```

### 配置网页终端服务

#### 手动安装

1. [下载 ttyd](https://github.com/tsl0922/ttyd/releases) 相应架构版本，玩客云可用为`ttyd.armhf`，改名`ttyd`，放到`/opt/ttyd`，设置权限777。

2. 新建 `/etc/systemd/system/ttyd.service` 内容如下
```
[Unit]
Description=TTYD
After=syslog.target
After=network.target

[Service]
ExecStart=/opt/ttyd -p 4200 login
Type=simple
Restart=always
User=root
Group=root

[Install]
WantedBy=multi-user.target
```

其中4200为端口号，可自定义。

3. 执行
```
sudo systemctl start ttyd && sudo systemctl enable ttyd
```

#### 一键安装
```bash
bash <(curl -Ls https://github.com/Cp0204/Casaos_Onecloud/raw/main/shell/install_ttyd.sh)
```

### 反向代理 CasaOS

本方案使用 `nginx:mainline-alpine-slim` 镜像做反向代理，相比于 Nginx Proxy Manager 更轻量（12M vs 300M）。

1. 证书放到 `/DATA/AppData/nginx/cert` 目录。

2. 以下内容保存为 `/DATA/AppData/nginx/conf.d/casaos.conf` ，修改你的端口和证书路径等参数。

```conf
server {
    listen 443 ssl;
    server_name yourcasaos.com;
    
    error_page 497 https://$host:$server_port$request_uri;

    ssl_certificate     /cert/yourcasaos.com/yourcasaos.com.crt;
    ssl_certificate_key /cert/yourcasaos.com/yourcasaos.com.key;

    location / {
        proxy_pass http://127.0.0.1:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        
        # WebSocket proxy
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

3. 安装自定义应用-导入-DockerCLI
```bash
docker run -d--name nginxProxy --network host -v /DATA/AppData/nginx/conf.d:/etc/nginx/conf.d -v /DATA/AppData/nginx/cert:/cert nginx:mainline-alpine-slim
```
