#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

#Add some basic function here
function LOGD() {
    echo -e "${yellow}[DEG] $* ${plain}"
}

function LOGE() {
    echo -e "${red}[ERR] $* ${plain}"
}

function LOGI() {
    echo -e "${green}[INF] $* ${plain}"
}
# check root
[[ $EUID -ne 0 ]] && LOGE "Lỗi:  Cần quyền root để cài đặt!\n" && exit 1

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
    LOGE "Hệ điều hành không được hỗ trợ！\n" && exit 1
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
        LOGE "Vui lòng sử dụng CentOS 7 trở lên！\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        LOGE "Vui lòng sử dụng Ubuntu 16 trở lên！\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        LOGE "Vui lòng sử dụng Debian 8 trở lên！\n" && exit 1
    fi
fi

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -p "$1 [mặc định$2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -p "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

confirm_restart() {
    confirm "Khởi động lại，xray cũng sẽ khởi động lại" "y"
    if [[ $? == 0 ]]; then
        restart
    else
        show_menu
    fi
}

before_show_menu() {
    echo && echo -n -e "${yellow}Nhấn enter để quay lại menu chính: ${plain}" && read temp
    show_menu
}

install() {
    bash <(curl -Ls https://raw.githubusercontent.com/aliceaia/4some/main/install.sh)
    if [[ $? == 0 ]]; then
        if [[ $# == 0 ]]; then
            start
        else
            start 0
        fi
    fi
}

update() {
    confirm "Cập nhật phiên bản mới nhất?" "n"
    if [[ $? != 0 ]]; then
        LOGE "Đã hủy"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 0
    fi
    bash <(curl -Ls https://raw.githubusercontent.com/aliceaia/4some/main/install.sh)
    if [[ $? == 0 ]]; then
        LOGI "Cập nhật hoàn tất, bảng điều khiển đã được tự động khởi động lại "
        exit 0
    fi
}

uninstall() {
    confirm "Bạn có chắc chắn muốn gỡ cài đặt bảng điều khiển không, xray cũng sẽ gỡ cài đặt?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    systemctl stop x-ui
    systemctl disable x-ui
    rm /etc/systemd/system/x-ui.service -f
    systemctl daemon-reload
    systemctl reset-failed
    rm /etc/x-ui/ -rf
    rm /usr/local/x-ui/ -rf

    echo ""
    echo -e "Gỡ cài đặt thành công, nếu bạn muốn xóa tập lệnh này, hãy chạy sau khi thoát tập lệnh ${green}rm /usr/bin/x-ui -f${plain} xóa"
    echo ""

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

reset_user() {
    confirm "Bạn có chắc chắn muốn đặt lại tên người dùng và mật khẩu cho quản trị viên không?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    /usr/local/x-ui/x-ui setting -username admin -password admin
    echo -e "Tên người dùng và mật khẩu đã được đặt lại thành ${green}admin${plain}，Vui lòng khởi động lại bảng điều khiển ngay bây giờ"
    confirm_restart
}

reset_config() {
    confirm "Bạn có chắc chắn muốn đặt lại tất cả cài đặt bảng điều khiển" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    /usr/local/x-ui/x-ui setting -reset
    echo -e "Tất cả cài đặt bảng điều khiển đã được đặt lại về mặc định, vui lòng khởi động lại bảng điều khiển ngay bây giờ và sử dụng cài đặt mặc định ${green}54321${plain} Cổng truy cập"
    confirm_restart
}

check_config() {
    info=$(/usr/local/x-ui/x-ui setting -show true)
    if [[ $? != 0 ]]; then
        LOGE "get current settings error,please check logs"
        show_menu
    fi
    LOGI "${info}"
}

set_port() {
    echo && echo -n -e "Nhập số cổng[1-65535]: " && read port
    if [[ -z "${port}" ]]; then
        LOGD "Đã hủy"
        before_show_menu
    else
        /usr/local/x-ui/x-ui setting -port ${port}
        echo -e "Sau khi thiết lập cổng, vui lòng khởi động lại bảng điều khiển và sử dụng cổng mới đặt ${green}${port}${plain} bảng điều khiển truy cập"
        confirm_restart
    fi
}

start() {
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        LOGI "Bảng đã chạy rồi, không cần khởi động lại, nếu muốn khởi động lại, vui lòng chọn khởi động lại"
    else
        systemctl start x-ui
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            LOGI "x-ui Đã bắt đầu thành công"
        else
            LOGE "Bảng điều khiển không khởi động được, có thể do thời gian khởi động vượt quá hai giây, vui lòng kiểm tra thông tin nhật ký sau"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

stop() {
    check_status
    if [[ $? == 1 ]]; then
        echo ""
        LOGI "Bảng điều khiển đã dừng, không cần dừng lại"
    else
        systemctl stop x-ui
        sleep 2
        check_status
        if [[ $? == 1 ]]; then
            LOGI "x-ui và xray đã dừng"
        else
            LOGE "Bảng điều khiển không dừng được, có thể do thời gian dừng vượt quá hai giây, vui lòng kiểm tra thông tin nhật ký sau"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

restart() {
    systemctl restart x-ui
    sleep 2
    check_status
    if [[ $? == 0 ]]; then
        LOGI "x-ui và xray đã khởi động lại"
    else
        LOGE "Bảng điều khiển không thể khởi động lại, có thể do thời gian khởi động vượt quá hai giây, vui lòng kiểm tra thông tin nhật ký sau"
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

status() {
    systemctl status x-ui -l
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

enable() {
    systemctl enable x-ui
    if [[ $? == 0 ]]; then
        LOGI "x-ui Khởi động cùng hệ thống thành công"
    else
        LOGE "x-ui Khởi động cùng hệ thống thất bại"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

disable() {
    systemctl disable x-ui
    if [[ $? == 0 ]]; then
        LOGI "x-ui huỷ khởi động cùng hệ thống thành công"
    else
        LOGE "x-ui huỷ khởi động cùng hệ thống thất bại"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_log() {
    journalctl -u x-ui.service -e --no-pager -f
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

migrate_v2_ui() {
    /usr/local/x-ui/x-ui v2-ui

    before_show_menu
}

install_bbr() {
    # temporary workaround for installing bbr
    bash <(curl -L -s https://raw.githubusercontent.com/teddysun/across/master/bbr.sh)
    echo ""
    before_show_menu
}

update_shell() {
    wget -O /usr/bin/x-ui -N --no-check-certificate https://github.com/aliceaia/4some/raw/main/x-ui.sh
    if [[ $? != 0 ]]; then
        echo ""
        LOGE "Tải xuống không thành công"
        before_show_menu
    else
        chmod +x /usr/bin/x-ui
        LOGI "Tập lệnh nâng cấp thành công, vui lòng chạy lại tập lệnh" && exit 0
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/x-ui.service ]]; then
        return 2
    fi
    temp=$(systemctl status x-ui | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

check_enabled() {
    temp=$(systemctl is-enabled x-ui)
    if [[ x"${temp}" == x"enabled" ]]; then
        return 0
    else
        return 1
    fi
}

check_uninstall() {
    check_status
    if [[ $? != 2 ]]; then
        echo ""
        LOGE "Bảng điều khiển đã được cài đặt, vui lòng không cài đặt lại"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

check_install() {
    check_status
    if [[ $? == 2 ]]; then
        echo ""
        LOGE "Vui lòng cài đặt bảng điều khiển trước"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

show_status() {
    check_status
    case $? in
    0)
        echo -e "Tình trạng: ${green}Đã chạy${plain}"
        show_enable_status
        ;;
    1)
        echo -e "Tình trạng: ${yellow}Không chạy${plain}"
        show_enable_status
        ;;
    2)
        echo -e "Tình trạng: ${red}Chưa cài đặt${plain}"
        ;;
    esac
    show_xray_status
}

show_enable_status() {
    check_enabled
    if [[ $? == 0 ]]; then
        echo -e "Có tự động bắt đầu không: ${green}có${plain}"
    else
        echo -e "Có tự động bắt đầu không: ${red}không${plain}"
    fi
}

check_xray_status() {
    count=$(ps -ef | grep "xray-linux" | grep -v "grep" | wc -l)
    if [[ count -ne 0 ]]; then
        return 0
    else
        return 1
    fi
}

show_xray_status() {
    check_xray_status
    if [[ $? == 0 ]]; then
        echo -e "xray trạng thái: ${green}đang chạy${plain}"
    else
        echo -e "xray trạng thái: ${red}đã dừng${plain}"
    fi
}

ssl_cert_issue() {
    echo -E ""
    LOGD "******使用说明******"
    LOGI "该脚本将使用Acme脚本申请证书,使用时需保证:"
    LOGI "1.知晓Cloudflare 注册邮箱"
    LOGI "2.知晓Cloudflare Global API Key"
    LOGI "3.域名已通过Cloudflare进行解析到当前服务器"
    LOGI "4.该脚本申请证书默认安装路径为/root/cert目录"
    confirm "我已确认以上内容[y/n]" "y"
    if [ $? -eq 0 ]; then
        cd ~
        LOGI "安装Acme脚本"
        curl https://get.acme.sh | sh
        if [ $? -ne 0 ]; then
            LOGE "安装acme脚本失败"
            exit 1
        fi
        CF_Domain=""
        CF_GlobalKey=""
        CF_AccountEmail=""
        certPath=/root/cert
        if [ ! -d "$certPath" ]; then
            mkdir $certPath
        else
            rm -rf $certPath
            mkdir $certPath
        fi
        LOGD "请设置域名:"
        read -p "Input your domain here:" CF_Domain
        LOGD "你的域名设置为:${CF_Domain}"
        LOGD "请设置API密钥:"
        read -p "Input your key here:" CF_GlobalKey
        LOGD "你的API密钥为:${CF_GlobalKey}"
        LOGD "请设置注册邮箱:"
        read -p "Input your email here:" CF_AccountEmail
        LOGD "你的注册邮箱为:${CF_AccountEmail}"
        ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
        if [ $? -ne 0 ]; then
            LOGE "修改默认CA为Lets'Encrypt失败,脚本退出"
            exit 1
        fi
        export CF_Key="${CF_GlobalKey}"
        export CF_Email=${CF_AccountEmail}
        ~/.acme.sh/acme.sh --issue --dns dns_cf -d ${CF_Domain} -d *.${CF_Domain} --log
        if [ $? -ne 0 ]; then
            LOGE "证书签发失败,脚本退出"
            exit 1
        else
            LOGI "证书签发成功,安装中..."
        fi
        ~/.acme.sh/acme.sh --installcert -d ${CF_Domain} -d *.${CF_Domain} --ca-file /root/cert/ca.cer \
        --cert-file /root/cert/${CF_Domain}.cer --key-file /root/cert/${CF_Domain}.key \
        --fullchain-file /root/cert/fullchain.cer
        if [ $? -ne 0 ]; then
            LOGE "证书安装失败,脚本退出"
            exit 1
        else
            LOGI "Chứng chỉ được cài đặt thành công, cho phép cập nhật tự động..."
        fi
        ~/.acme.sh/acme.sh --upgrade --auto-upgrade
        if [ $? -ne 0 ]; then
            LOGE "Cài đặt cập nhật tự động không thành công, tập lệnh đã thoát"
            ls -lah cert
            chmod 755 $certPath
            exit 1
        else
            LOGI "Chứng chỉ đã được cài đặt và cập nhật tự động đã được bật, thông tin chi tiết như sau"
            ls -lah cert
            chmod 755 $certPath
        fi
    else
        show_menu
    fi
}

show_usage() {
    echo "x-ui Cách sử dụng tập lệnh quản lý: "
    echo "------------------------------------------"
    echo "x-ui              - Mở menu admin (mở rộng)"
    echo "x-ui start        - Chạy"
    echo "x-ui stop         - Dừng"
    echo "x-ui restart      - Khởi động lại"
    echo "x-ui status       - Trạng thái"
    echo "x-ui enable       - Khởi động cùng hệ thống"
    echo "x-ui disable      - Tắt khởi động cùng hệ thống"
    echo "x-ui log          - Lịch sử"
    echo "x-ui v2-ui        - Di chuyển dữ liệu tài khoản v2-ui của máy này sang x-ui"
    echo "x-ui update       - Update x-ui"
    echo "x-ui install      - Cài đặt x-ui"
    echo "x-ui uninstall    - Gỡ cài đặt x-ui"
    echo "------------------------------------------"
}

show_menu() {
    echo -e "
  ${green}x-ui Quản lí${plain}
  ${green}0.${plain} Thoát
————————————————
  ${green}1.${plain} Cài đặt x-ui
  ${green}2.${plain} Cập nhật x-ui
  ${green}3.${plain} Gỡ cài đặt x-ui
————————————————
  ${green}4.${plain} Đặt lại user và pass
  ${green}5.${plain} Đặt lại settings
  ${green}6.${plain} Thiết lập port cho web
  ${green}7.${plain} Xem cài đặt
————————————————
  ${green}8.${plain} Start x-ui
  ${green}9.${plain} Stop x-ui
  ${green}10.${plain} Restart x-ui
  ${green}11.${plain} Trạng thái x-ui
  ${green}12.${plain} Nhật kí
————————————————
  ${green}13.${plain} Chạy khi khởi động
  ${green}14.${plain} Không chạy khi khởi động
————————————————
  ${green}15.${plain} Cài đặt bbr (mới nhất)
  ${green}16.${plain} Cài đặt SSL (acme)
 "
    show_status
    echo && read -p "Vui lòng nhập một lựa chọn [0-16]: " num

    case "${num}" in
    0)
        exit 0
        ;;
    1)
        check_uninstall && install
        ;;
    2)
        check_install && update
        ;;
    3)
        check_install && uninstall
        ;;
    4)
        check_install && reset_user
        ;;
    5)
        check_install && reset_config
        ;;
    6)
        check_install && set_port
        ;;
    7)
        check_install && check_config
        ;;
    8)
        check_install && start
        ;;
    9)
        check_install && stop
        ;;
    10)
        check_install && restart
        ;;
    11)
        check_install && status
        ;;
    12)
        check_install && show_log
        ;;
    13)
        check_install && enable
        ;;
    14)
        check_install && disable
        ;;
    15)
        install_bbr
        ;;
    16)
        ssl_cert_issue
        ;;
    *)
        LOGE "Vui lòng nhập số chính xác [0-16]"
        ;;
    esac
}

if [[ $# > 0 ]]; then
    case $1 in
    "start")
        check_install 0 && start 0
        ;;
    "stop")
        check_install 0 && stop 0
        ;;
    "restart")
        check_install 0 && restart 0
        ;;
    "status")
        check_install 0 && status 0
        ;;
    "enable")
        check_install 0 && enable 0
        ;;
    "disable")
        check_install 0 && disable 0
        ;;
    "log")
        check_install 0 && show_log 0
        ;;
    "v2-ui")
        check_install 0 && migrate_v2_ui 0
        ;;
    "update")
        check_install 0 && update 0
        ;;
    "install")
        check_uninstall 0 && install 0
        ;;
    "uninstall")
        check_install 0 && uninstall 0
        ;;
    *) show_usage ;;
    esac
else
    show_menu
fi
