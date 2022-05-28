#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Lỗi：${plain} Cần quyền root để cài đặt!\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}未检测到系统版本，请联系脚本作者！${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="amd64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64"
elif [[ $arch == "s390x" ]]; then
    arch="s390x"
else
    arch="amd64"
    echo -e "${red}检测架构失败，使用默认架构: ${arch}${plain}"
fi

echo "架构: ${arch}"

if [ $(getconf WORD_BIT) != '32' ] && [ $(getconf LONG_BIT) != '64' ]; then
    echo "本软件不支持 32 位系统(x86)，请使用 64 位系统(x86_64)，如果检测有误，请联系作者"
    exit -1
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}请使用 CentOS 7 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}请使用 Ubuntu 16 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}请使用 Debian 8 或更高版本的系统！${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install wget curl tar -y
    else
        apt install wget curl tar -y
    fi
}

#This function will be called when user installed x-ui out of sercurity
config_after_install() {
    echo -e "${yellow}Vì lý do bảo mật, cần buộc phải sửa đổi cổng và mật khẩu tài khoản sau khi cài đặt / cập nhật hoàn tất.${plain}"
    read -p "Xác nhận tiếp tục?[y/n]": config_confirm
    if [[ x"${config_confirm}" == x"y" || x"${config_confirm}" == x"Y" ]]; then
        read -p "Vui lòng đặt tên tài khoản của bạn:" config_account
        echo -e "${yellow}Tên tài khoản của bạn sẽ được đặt thành:${config_account}${plain}"
        read -p "Vui lòng đặt mật khẩu của bạn:" config_password
        echo -e "${yellow}Mật khẩu tài khoản của bạn sẽ được đặt thành:${config_password}${plain}"
        read -p "Vui lòng đặt cổng truy cập bảng điều khiển:" config_port
        echo -e "${yellow}Cổng truy cập bảng điều khiển của bạn sẽ được đặt thành:${config_port}${plain}"
        echo -e "${yellow}Xác nhận cài đặt, cài đặt${plain}"
        /usr/local/x-ui/x-ui setting -username ${config_account} -password ${config_password}
        echo -e "${yellow}Đã hoàn tất cài đặt mật khẩu tài khoản${plain}"
        /usr/local/x-ui/x-ui setting -port ${config_port}
        echo -e "${yellow}Đã hoàn tất cài đặt cổng bảng điều khiển${plain}"
    else
        echo -e "${red}Đã hủy, tất cả các mục cài đặt là cài đặt mặc định, vui lòng sửa đổi kịp thời${plain}"
    fi
}

install_x-ui() {
    systemctl stop x-ui
    cd /usr/local/

    if [ $# == 0 ]; then
        last_version=$(curl -Ls "https://api.github.com/repos/vaxilu/x-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}Không thể phát hiện phiên bản x-ui, có thể đã vượt quá giới hạn API Github, vui lòng thử lại sau hoặc chỉ định phiên bản x-ui để cài đặt theo cách thủ công${plain}"
            exit 1
        fi
        echo -e "Đã phát hiện phiên bản mới nhất của x-ui：${last_version}，bắt đầu cài đặt"
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz https://github.com/aliceaia/4some/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Không tải xuống được x-ui, hãy đảm bảo máy chủ của bạn có thể tải xuống tệp Github${plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/aliceaia/4some/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz"
        echo -e "开始安装 x-ui v$1"
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}không thể tải x-ui v$1，hãy đảm bảo rằng phiên bản này tồn tại${plain}"
            exit 1
        fi
    fi

    if [[ -e /usr/local/x-ui/ ]]; then
        rm /usr/local/x-ui/ -rf
    fi

    tar zxvf x-ui-linux-${arch}.tar.gz
    rm x-ui-linux-${arch}.tar.gz -f
    cd x-ui
    chmod +x x-ui bin/xray-linux-${arch}
    cp -f x-ui.service /etc/systemd/system/
    wget --no-check-certificate -O /usr/bin/x-ui https://raw.githubusercontent.com/aliceaia/4some/main/x-ui.sh
    chmod +x /usr/local/x-ui/x-ui.sh
    chmod +x /usr/bin/x-ui
    config_after_install
    #echo -e "Nếu đó là một cài đặt mới, cổng web mặc định là ${green}54321${plain}，Tên người dùng và mật khẩu đều theo mặc định ${green}admin${plain}"
    #echo -e "Hãy đảm bảo rằng cổng này không bị các chương trình khác chiếm，${yellow}và cổng 54321 được mở${plain}"
    #    echo -e "Nếu bạn muốn sửa đổi 54321 thành một cổng khác, hãy nhập lệnh x-ui để sửa đổi nó và cũng đảm bảo rằng cổng bạn sửa đổi cũng được mở"
    #echo -e ""
    #echo -e "Nếu đó là bảng cập nhật, hãy truy cập bảng như bạn đã làm trước đây"
    #echo -e ""
    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui
    echo -e "${green}x-ui v${last_version}${plain} Quá trình cài đặt hoàn tất, bảng điều khiển được khởi chạy，"
    echo -e ""
    echo -e "x-ui Cách sử dụng tập lệnh quản lý: "
    echo -e "----------------------------------------------"
    echo -e "x-ui              - Mở menu admin (mở rộng)"
    echo -e "x-ui start        - Chạy"
    echo -e "x-ui stop         - Dừng"
    echo -e "x-ui restart      - Khởi động lại"
    echo -e "x-ui status       - Trạng thái"
    echo -e "x-ui enable       - Khởi động cùng hệ thống"
    echo -e "x-ui disable      - Tắt khởi động cùng hệ thống"
    echo -e "x-ui log          - Lịch sử"
    echo -e "x-ui v2-ui        - Di chuyển dữ liệu tài khoản v2-ui của máy này sang x-ui"
    echo -e "x-ui update       - Update x-ui"
    echo -e "x-ui install      - Cài đặt x-ui"
    echo -e "x-ui uninstall    - Gỡ cài đặt x-ui"
    echo -e "----------------------------------------------"
}

echo -e "${green}bắt đầu cài đặt${plain}"
install_base
install_x-ui $1
