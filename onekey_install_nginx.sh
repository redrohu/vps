#!/bin/sh

NGINX_VERSION=nginx-1.18.0         #nginx版本
NGINX_INSTALL_DIR=/usr/local/nginx #nginx安装目录
CONFIG_DIR=/etc/nginx/nginx.conf   #nginx配置文件
SRC_DIR=/usr/local/src/            #解压目录
PID_PATH=/run/nginx.pid            #pid位置
# MODULES="--prefix=${NGINX_INSTALL_DIR} \
#     --user=nginx \
#     --group=nginx \
#     --conf-path=${CONFIG_DIR} \
#     --with-http_ssl_module \
#     --with-http_v2_module \
#     --with-http_realip_module \
#     --with-http_stub_status_module \
#     --with-http_gzip_static_module \
#     --with-pcre \
#     --with-stream \
#     --with-stream_ssl_module \
#     --with-stream_realip_module \
#     --with-ipv6"
# # --with-http_sub_module"
# # --add-module=/git/ngx_http_substitutions_filter_module/"

MODULES=" \
    --prefix=${NGINX_INSTALL_DIR} \
    --conf-path=${CONFIG_DIR} \
    --pid-path=${PID_PATH} \
    --user=nginx \
    --group=nginx \
    --with-http_ssl_module \
    --with-http_stub_status_module \
    --with-http_realip_module \
    --with-http_auth_request_module \
    --with-http_v2_module \
    --with-http_dav_module \
    --with-http_slice_module \
    --with-threads \
    --with-http_addition_module \
    --with-http_geoip_module=dynamic \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_image_filter_module=dynamic \
    --with-http_sub_module \
    --with-http_xslt_module=dynamic \
    --with-stream=dynamic \
    --with-stream_ssl_module \
    --with-mail=dynamic \
    --with-mail_ssl_module \
    --with-ipv6 \
"
TAR=.tar.gz
NGINX_URL=http://nginx.org/download/

rocky_page="
make 
gcc-c++ 
libtool 
pcre 
pcre-devel 
zlib 
zlib-devel 
openssl 
openssl-devel 
perl-ExtUtils-Embed
"

centos_page="
gcc
pcre-devel
openssl-devel
zlib-devel
make
"

ubuntu_page="
libpcre3
libpcre3-dev
openssl
libssl-dev
gcc
g++
make
zlib1g-dev
libxml2 
libxml2-dev 
libxslt-dev 
libgd-dev 
libgeoip-dev
"

color() {
    RES_COL=60
    MOVE_TO_COL="echo -en \\033[${RES_COL}G"
    SETCOLOR_SUCCESS="echo -en \\033[1;32m"
    SETCOLOR_FAILURE="echo -en \\033[1;31m"
    SETCOLOR_WARNING="echo -en \\033[1;33m"
    SETCOLOR_NORMAL="echo -en \E[0m"
    echo -n "$1" && $MOVE_TO_COL
    echo -n "["
    if [ $2 = "success" -o $2 = "0" ]; then
        ${SETCOLOR_SUCCESS}
        echo -n $"  OK  "
    elif [ $2 = "failure" -o $2 = "1" ]; then
        ${SETCOLOR_FAILURE}
        echo -n $"FAILED"
    else
        ${SETCOLOR_WARNING}
        echo -n $"WARNING"
    fi
    ${SETCOLOR_NORMAL}
    echo -n "]"
    echo
}

os_type() {
    awk -F'[ "]' '/^NAME/{print $2}' /etc/os-release
}

os_version() {
    awk -F'"' '/^VERSION_ID/{print $2}' /etc/os-release
}

ok_yn() {
    read -r -p "当前系统:[$1-$(os_version)], Nginx安装版本[$2], 安装目录[${NGINX_INSTALL_DIR}], 配置文件[${CONFIG_DIR}], 确定安装吗? [Y/n] " input
    case $input in
    [yY][eE][sS] | [yY] | "")
        color "安装中..." 0
        ;;
    [nN][oO] | [nN])
        color "取消！" 1
        exit 1
        ;;
    *)
        color "Invalid input..." 1
        exit 1
        ;;
    esac
}

check() {
    [ -e ${NGINX_INSTALL_DIR} ] && {
        color "nginx 已安装,请卸载后再安装[${NGINX_INSTALL_DIR}]" 1
        exit
    }
    cd ${SRC_DIR}
    if [ -e ${NGINX_VERSION}${TAR} ]; then
        color "相关文件已准备好" 0
    else
        color '开始下载 nginx 源码包' 0
        wget ${NGINX_URL}${NGINX_VERSION}${TAR}
        [ $? -ne 0 ] && {
            color "下载 ${NGINX_VERSION}${TAR}文件失败" 1
            exit
        }
    fi
}

install() {

    ok_yn $(os_type) ${NGINX_VERSION}
    check

    color "开始安装 nginx..." 0
    #创建用户
    if
        id nginx 2>&1 >/dev/null
    then
        color "nginx 用户已存在" 1
    else
        color "创建 nginx 用户" 0
        useradd -s /sbin/nologin -r nginx
        [ $? -ne 0 ] && {
            color "创建 nginx 用户文件失败" 1
            exit
        }

    fi

    #判断编译安装的依赖包是否存在，并安装
    if [ $(os_type) == "Rocky" -a $(os_version) == '8.5' ]; then
        NGINX_SERVICE_PATH="/usr/lib/systemd/system/nginx.service"
        for PK in $rocky_page; do
            rpm -q $PK 2>&1 >/dev/null || yum -y -q install "$PK"
        done
    elif [ $(os_type) == "CentOS" -a $(os_version) == '7' ]; then
        NGINX_SERVICE_PATH="/usr/lib/systemd/system/nginx.service"
        for PK in $centos_page; do
            rpm -q $PK 2>&1 >/dev/null || yum -y -q install "$PK"
        done
    else
        NGINX_SERVICE_PATH="/lib/systemd/system/nginx.service"
        for PK in $ubuntu_page; do
            dpkg -s $PK 2>&1 >/dev/null ||
                {
                    echo -e "\033[33m 安装依赖包$PK... \033[0m"
                    apt -y install $PK 2>&1 >/dev/null || exit
                }
        done
    fi

    # 解压安装包
    cd ${SRC_DIR} 2>&1 >/dev/null || exit
    [ -e ${NGINX_VERSION}${TAR} ] && tar xf ${NGINX_VERSION}${TAR}
    #创建安装目并修改权限
    [ -d ${NGINX_INSTALL_DIR} ] || mkdir -p ${NGINX_INSTALL_DIR}
    chown -R nginx.nginx ${NGINX_INSTALL_DIR}

    #编译
    echo -e "\033[33m 正在编译安装,请稍等! \033[0m"
    cd ${NGINX_VERSION} 2>&1 >/dev/null || exit
    ./configure ${MODULES} 2>&1 >/dev/null || exit

    #安装
    # make -j $(lscpu | awk '/^CPU\(s\)/{print $2}') && make install
    make && make install
    [ $? -eq 0 ] && color "nginx 编译安装成功" 0 || {
        color "nginx 编译安装失败,退出!" 1
        exit
    }
    #修改配置文件
    # [ -e ${NGINX_INSTALL_DIR}/conf/nginx.conf ] && sed -i 's@^#pid.*@pid '${NGINX_INSTALL_DIR}'/run/nginx.pid;@' ${NGINX_INSTALL_DIR}/conf/nginx.conf
    [ -e ${CONFIG_DIR} ] && sed -i.bak "/pid/c\pid \\${PID_PATH};" ${CONFIG_DIR}
    echo "export PATH=${NGINX_INSTALL_DIR}/sbin:${PATH}" >/etc/profile.d/nginx.sh
    ln -s ${NGINX_INSTALL_DIR}/sbin/nginx /usr/sbin/

    cat >${NGINX_SERVICE_PATH} <<EOF
[Unit]
Description=The nginx HTTP and reverse proxy server
After=network.target remote-fs.target nss-lookup.target

[Service]
Type=forking
PIDFile=${PID_PATH}
ExecStartPre=/bin/rm -f ${PID_PATH}
ExecStartPre=${NGINX_INSTALL_DIR}/sbin/nginx -t
ExecStop=/bin/kill -s TERM \$MAINPID
ExecStart=${NGINX_INSTALL_DIR}/sbin/nginx
ExecReload=/bin/kill -s HUP \$MAINPID
KillSignal=SIGQUIT
TimeoutStopSec=5
KillMode=process
PrivateTmp=true

[Install]
 WantedBy=multi-user.target
EOF

    #启动服务
    systemctl daemon-reload
    systemctl enable --now nginx 2>&1 >/dev/null && color "nginx启动成功!" 0 || color "nginx启动失败,请检查配置文件!" 1

}

install
