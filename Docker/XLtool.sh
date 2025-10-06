#!/bin/bash
# 脚本名称：XLtool.sh（全功能服务器管理工具箱）
# 功能：整合Docker/LDNMP/SSL/防火墙/IPv6/Swap/监控/Fail2ban等核心功能
sh_v="3.8.8"

# ============== 核心变量定义 ==============
# 颜色变量
gl_hui='\e[37m'
gl_hong='\033[31m'
gl_lv='\033[32m'
gl_huang='\033[33m'
gl_lan='\033[34m'
gl_bai='\033[0m'
gl_zi='\033[35m'
gl_XLtool='\033[96m'  # 主色调

# 全局配置变量
canshu="CN"               # 地区标识（CN/V6）
permission_granted="false" # 许可协议状态
ENABLE_STATS="true"        # 统计开关
gh_proxy="https://gh.kejilion.pro/"  # GitHub代理
yuming=""                  # 域名（SSL/站点用）
docker_name=""             # Docker应用名
docker_port=""             # Docker端口
docker_img=""              # Docker镜像
app_size=1                 # 应用所需磁盘(GB)
webname=""                 # 站点名称
duankou=""                 # 反向代理端口
xxx=""                     # Fail2ban规则变量
panelname=""               # 面板名称
panelurl=""                # 面板官网
lujing=false               # 面板路径判断
docker_describe=""         # Docker应用描述
docker_url=""              # Docker应用官网
app_name=""                # 扩展应用名
app_text=""                # 扩展应用描述
app_url=""                 # 扩展应用官网
update_status=""           # 更新状态
CFmessage=""               # Cloudflare模式状态
waf_status=""              # WAF状态
SESSION_NAME="XLtool-session"  # tmux会话名
tmuxd=""                   # tmux后台命令

# ============== 基础依赖函数 ==============
# root权限检查
root_use() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${gl_hong}错误：该操作需要 root 权限，请使用 sudo 运行或切换到 root 用户！${gl_bai}"
        exit 1
    fi
}

# 命令执行控制（1=不执行，0=执行）
run_command() {
    if [ "$zhushi" -eq 0 ]; then
        "$@"
    fi
}

# 全局配置初始化（含GitHub代理）
quanju_canshu() {
    if [ "$canshu" = "CN" ]; then
        zhushi=0
        gh_proxy="https://gh.kejilion.pro/"
    elif [ "$canshu" = "V6" ]; then
        zhushi=1
        gh_proxy="https://gh.kejilion.pro/"
    else
        zhushi=1
        gh_proxy="https://"
    fi
}
quanju_canshu  # 初始化

# 统计埋点函数
send_stats() {
    if [ "$ENABLE_STATS" == "false" ]; then
        return
    fi
    local country=$(curl -s ipinfo.io/country 2>/dev/null)
    local os_info=$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d '=' -f2 | tr -d '"')
    local cpu_arch=$(uname -m)
    curl -s -X POST "https://api.58881314.xyz/api/log" \
         -H "Content-Type: application/json" \
         -d "{\"action\":\"$1\",\"timestamp\":\"$(date -u '+%Y-%m-%d %H:%M:%S')\",\"country\":\"$country\",\"os_info\":\"$os_info\",\"cpu_arch\":\"$cpu_arch\",\"version\":\"$sh_v\"}" &>/dev/null &
}

# 隐私设置（关闭统计）
yinsiyuanquan2() {
    if grep -q '^ENABLE_STATS="false"' /usr/local/bin/k > /dev/null 2>&1; then
        sed -i 's/^ENABLE_STATS="true"/ENABLE_STATS="false"/' ~/XLtool.sh
    fi
}

# V6模式配置同步
canshu_v6() {
    if grep -q '^canshu="V6"' /usr/local/bin/k > /dev/null 2>&1; then
        sed -i 's/^canshu="default"/canshu="V6"/' ~/XLtool.sh
    fi
}

# 权限状态同步（true）
CheckFirstRun_true() {
    if grep -q '^permission_granted="true"' /usr/local/bin/k > /dev/null 2>&1; then
        sed -i 's/^permission_granted="false"/permission_granted="true"/' ~/XLtool.sh
    fi
}

# 许可协议检查（首次运行触发）
CheckFirstRun_false() {
    if [ "$permission_granted" = "false" ]; then
        UserLicenseAgreement
    fi
}

# 用户许可协议
UserLicenseAgreement() {
    clear
    echo -e "${gl_XLtool}欢迎使用 XLtool 脚本工具箱（v$sh_v）${gl_bai}"
    echo "首次使用脚本，请先阅读并同意用户许可协议。"
    echo "用户许可协议: https://blog.5881314.xyz/user-license-agreement/"
    echo -e "----------------------"
    read -r -p "是否同意以上条款？(y/n): " user_input

    if [ "$user_input" = "y" ] || [ "$user_input" = "Y" ]; then
        send_stats "许可同意"
        sed -i 's/^permission_granted="false"/permission_granted="true"/' ~/XLtool.sh
        sed -i 's/^permission_granted="false"/permission_granted="true"/' /usr/local/bin/k 2>/dev/null
    else
        send_stats "许可拒绝"
        clear
        exit
    fi
}

# IP地址获取（IPv4+IPv6）
ip_address() {
    ipv4_address=$(curl -s https://ipinfo.io/ip && echo)
    ipv6_address=$(curl -s --max-time 1 https://v6.ipinfo.io/ip && echo)
}

# 通用软件安装（多包管理器适配）
install() {
    if [ $# -eq 0 ]; then
        echo -e "${gl_hong}未提供软件包参数${gl_bai}"
        return 1
    fi

    for package in "$@"; do
        if ! command -v "$package" &>/dev/null; then
            echo -e "${gl_huang}正在安装 $package...${gl_bai}"
            if command -v dnf &>/dev/null; then
                dnf -y update
                dnf install -y epel-release
                dnf install -y "$package"
            elif command -v yum &>/dev/null; then
                yum -y update
                yum install -y epel-release
                yum install -y "$package"
            elif command -v apt &>/dev/null; then
                apt update -y
                apt install -y "$package"
            elif command -v apk &>/dev/null; then
                apk update
                apk add "$package"
            elif command -v pacman &>/dev/null; then
                pacman -Syu --noconfirm
                pacman -S --noconfirm "$package"
            elif command -v zypper &>/dev/null; then
                zypper refresh
                zypper install -y "$package"
            elif command -v opkg &>/dev/null; then
                opkg update
                opkg install "$package"
            elif command -v pkg &>/dev/null; then
                pkg update
                pkg install -y "$package"
            else
                echo -e "${gl_hong}未知的包管理器，无法安装 $package${gl_bai}"
                return 1
            fi
            send_stats "安装软件包:$package"
        fi
    done
}

# 磁盘空间检查（参数：所需GB）
check_disk_space() {
    required_gb=$1
    required_space_mb=$((required_gb * 1024))
    available_space_mb=$(df -m / | awk 'NR==2 {print $4}')

    if [ $available_space_mb -lt $required_space_mb ]; then
        echo -e "${gl_huang}提示: ${gl_bai}磁盘空间不足！"
        echo "当前可用空间: $((available_space_mb/1024))G"
        echo "最小需求空间: ${required_gb}G"
        echo "无法继续安装，请清理磁盘空间后重试。"
        send_stats "磁盘空间不足"
        break_end
        XLtool  # 返回到主菜单
    fi
}

# 基础依赖安装（通用）
install_dependency() {
    install wget unzip tar jq curl gnupg lsb-release nano goaccess tmux
}

# 通用卸载函数
remove() {
    if [ $# -eq 0 ]; then
        echo -e "${gl_hong}未提供软件包参数${gl_bai}"
        return 1
    fi

    for package in "$@"; do
        echo -e "${gl_huang}正在卸载 $package...${gl_bai}"
        if command -v dnf &>/dev/null; then
            dnf remove -y "$package"
        elif command -v yum &>/dev/null; then
            yum remove -y "$package"
        elif command -v apt &>/dev/null; then
            apt purge -y "$package"
        elif command -v apk &>/dev/null; then
            apk del "$package"
        elif command -v pacman &>/dev/null; then
            pacman -Rns --noconfirm "$package"
        elif command -v zypper &>/dev/null; then
            zypper remove -y "$package"
        elif command -v opkg &>/dev/null; then
            opkg remove "$package"
        elif command -v pkg &>/dev/null; then
            pkg delete -y "$package"
        else
            echo -e "${gl_hong}未知的包管理器，无法卸载 $package${gl_bai}"
            return 1
        fi
        send_stats "卸载软件包:$package"
    done
}

# 通用服务管理（兼容各发行版）
systemctl() {
    local COMMAND="$1"
    local SERVICE_NAME="$2"

    if command -v apk &>/dev/null; then
        service "$SERVICE_NAME" "$COMMAND"
    else
        /bin/systemctl "$COMMAND" "$SERVICE_NAME"
    fi
}

# 重启服务
restart() {
    systemctl restart "$1"
    if [ $? -eq 0 ]; then
        echo -e "${gl_lv}$1 服务已重启${gl_bai}"
        send_stats "重启服务:$1"
    else
        echo -e "${gl_hong}错误：重启 $1 服务失败${gl_bai}"
        send_stats "重启服务失败:$1"
    fi
}

# 启动服务
start() {
    systemctl start "$1"
    if [ $? -eq 0 ]; then
        echo -e "${gl_lv}$1 服务已启动${gl_bai}"
        send_stats "启动服务:$1"
    else
        echo -e "${gl_hong}错误：启动 $1 服务失败${gl_bai}"
        send_stats "启动服务失败:$1"
    fi
}

# 停止服务
stop() {
    systemctl stop "$1"
    if [ $? -eq 0 ]; then
        echo -e "${gl_lv}$1 服务已停止${gl_bai}"
        send_stats "停止服务:$1"
    else
        echo -e "${gl_hong}错误：停止 $1 服务失败${gl_bai}"
        send_stats "停止服务失败:$1"
    fi
}

# 查看服务状态
status() {
    systemctl status "$1"
    if [ $? -eq 0 ]; then
        echo -e "${gl_lv}$1 服务状态已显示${gl_bai}"
    else
        echo -e "${gl_hong}错误：无法显示 $1 服务状态${gl_bai}"
        send_stats "查看服务状态失败:$1"
    fi
}

# 服务开机自启
enable() {
    local SERVICE_NAME="$1"
    if command -v apk &>/dev/null; then
        rc-update add "$SERVICE_NAME" default
    else
       /bin/systemctl enable "$SERVICE_NAME"
    fi
    echo -e "${gl_lv}$SERVICE_NAME 已设置为开机自启${gl_bai}"
    send_stats "设置开机自启:$1"
}

# 操作完成暂停提示
break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo "按任意键继续..."
    read -n 1 -s -r -p ""
    echo ""
    clear
}

# 端口冲突处理（停止80/443占用）
check_port() {
    root_use
    install lsof

    stop_containers_or_kill_process() {
        local port=$1
        local containers=$(docker ps --filter "publish=$port" --format "{{.ID}}" 2>/dev/null)

        if [ -n "$containers" ]; then
            docker stop $containers
            echo -e "${gl_lv}已停止占用端口 $port 的容器: $containers${gl_bai}"
            send_stats "停止占用端口$port的容器:$containers"
        else
            local pids=$(lsof -t -i:$port 2>/dev/null)
            if [ -n "$pids" ]; then
                for pid in $pids; do
                    kill -9 $pid
                done
                echo -e "${gl_lv}已杀死占用端口 $port 的进程: $pids${gl_bai}"
                send_stats "杀死占用端口$port的进程:$pids"
            else
                echo -e "${gl_huang}端口 $port 未被占用${gl_bai}"
            fi
        fi
    }

    stop_containers_or_kill_process 80
    stop_containers_or_kill_process 443
}

# ============== Crontab 相关函数 ==============
# 检查crontab是否安装
check_crontab_installed() {
    if ! command -v crontab >/dev/null 2>&1; then
        install_crontab
    fi
}

# 安装crontab（多系统适配）
install_crontab() {
    root_use
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            ubuntu|debian|kali)
                apt update -y
                apt install -y cron
                systemctl enable cron
                systemctl start cron
                ;;
            centos|rhel|almalinux|rocky|fedora)
                yum install -y cronie
                systemctl enable crond
                systemctl start crond
                ;;
            alpine)
                apk add --no-cache cronie
                rc-update add crond
                rc-service crond start
                ;;
            arch|manjaro)
                pacman -Syu --noconfirm
                pacman -S --noconfirm cronie
                systemctl enable cronie
                systemctl start cronie
                ;;
            opensuse|suse|opensuse-tumbleweed)
                zypper install -y cron
                systemctl enable cron
                systemctl start cron
                ;;
            iStoreOS|openwrt|ImmortalWrt|lede)
                opkg update
                opkg install cron
                /etc/init.d/cron enable
                /etc/init.d/cron start
                ;;
            FreeBSD)
                pkg install -y cronie
                sysrc cron_enable="YES"
                service cron start
                ;;
            *)
                echo -e "${gl_hong}不支持的发行版: $ID${gl_bai}"
                return
                ;;
        esac
    else
        echo -e "${gl_hong}无法确定操作系统${gl_bai}"
        return
    fi
    echo -e "${gl_lv}crontab 已安装且 cron 服务正在运行${gl_bai}"
    send_stats "安装crontab"
}

# ============== 防火墙（iptables）相关函数 ==============
# 保存iptables规则（并添加开机自启）
save_iptables_rules() {
    root_use
    mkdir -p /etc/iptables
    touch /etc/iptables/rules.v4
    iptables-save > /etc/iptables/rules.v4

    check_crontab_installed
    crontab -l | grep -v 'iptables-restore' | crontab - > /dev/null 2>&1
    (crontab -l ; echo '@reboot iptables-restore < /etc/iptables/rules.v4') | crontab - > /dev/null 2>&1
    echo -e "${gl_lv}iptables规则已保存，开机自启已配置${gl_bai}"
}

# 开放所有端口（重置iptables）
iptables_open() {
    root_use
    install iptables
    save_iptables_rules

    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -F

    ip6tables -P INPUT ACCEPT
    ip6tables -P FORWARD ACCEPT
    ip6tables -P OUTPUT ACCEPT
    ip6tables -F

    echo -e "${gl_lv}所有端口已开放，iptables规则已重置${gl_bai}"
    send_stats "开放所有端口"
}

# 开放指定端口（TCP+UDP）
open_port() {
    root_use
    local ports=($@)
    if [ ${#ports[@]} -eq 0 ]; then
        echo -e "${gl_hong}请提供至少一个端口号${gl_bai}"
        return 1
    fi

    install iptables

    for port in "${ports[@]}"; do
        iptables -D INPUT -p tcp --dport $port -j DROP 2>/dev/null
        iptables -D INPUT -p udp --dport $port -j DROP 2>/dev/null

        if ! iptables -C INPUT -p tcp --dport $port -j ACCEPT 2>/dev/null; then
            iptables -I INPUT 1 -p tcp --dport $port -j ACCEPT
        fi
        if ! iptables -C INPUT -p udp --dport $port -j ACCEPT 2>/dev/null; then
            iptables -I INPUT 1 -p udp --dport $port -j ACCEPT
            echo -e "${gl_lv}已开放端口: $port（TCP+UDP）${gl_bai}"
        fi
    done

    save_iptables_rules
    send_stats "开放端口:${ports[*]}"
}

# 关闭指定端口（TCP+UDP）
close_port() {
    root_use
    local ports=($@)
    if [ ${#ports[@]} -eq 0 ]; then
        echo -e "${gl_hong}请提供至少一个端口号${gl_bai}"
        return 1
    fi

    install iptables

    for port in "${ports[@]}"; do
        iptables -D INPUT -p tcp --dport $port -j ACCEPT 2>/dev/null
        iptables -D INPUT -p udp --dport $port -j ACCEPT 2>/dev/null

        if ! iptables -C INPUT -p tcp --dport $port -j DROP 2>/dev/null; then
            iptables -I INPUT 1 -p tcp --dport $port -j DROP
        fi
        if ! iptables -C INPUT -p udp --dport $port -j DROP 2>/dev/null; then
            iptables -I INPUT 1 -p udp --dport $port -j DROP
            echo -e "${gl_lv}已关闭端口: $port（TCP+UDP）${gl_bai}"
        fi
    done

    save_iptables_rules
    send_stats "关闭端口:${ports[*]}"
}

# IP白名单（放行指定IP/IP段）
allow_ip() {
    root_use
    local ips=($@)
    if [ ${#ips[@]} -eq 0 ]; then
        echo -e "${gl_hong}请提供至少一个IP地址或IP段${gl_bai}"
        return 1
    fi

    install iptables

    for ip in "${ips[@]}"; do
        iptables -D INPUT -s $ip -j DROP 2>/dev/null

        if ! iptables -C INPUT -s $ip -j ACCEPT 2>/dev/null; then
            iptables -I INPUT 1 -s $ip -j ACCEPT
            echo -e "${gl_lv}已放行IP: $ip${gl_bai}"
        fi
    done

    save_iptables_rules
    send_stats "放行IP:${ips[*]}"
}

# IP黑名单（阻止指定IP/IP段）
block_ip() {
    root_use
    local ips=($@)
    if [ ${#ips[@]} -eq 0 ]; then
        echo -e "${gl_hong}请提供至少一个IP地址或IP段${gl_bai}"
        return 1
    fi

    install iptables

    for ip in "${ips[@]}"; do
        iptables -D INPUT -s $ip -j ACCEPT 2>/dev/null

        if ! iptables -C INPUT -s $ip -j DROP 2>/dev/null; then
            iptables -I INPUT 1 -s $ip -j DROP
            echo -e "${gl_lv}已阻止IP: $ip${gl_bai}"
        fi
    done

    save_iptables_rules
    send_stats "阻止IP:${ips[*]}"
}

# 开启DDoS防御（SYN洪水+UDP限制）
enable_ddos_defense() {
    root_use
    install iptables

    iptables -A DOCKER-USER -p tcp --syn -m limit --limit 500/s --limit-burst 100 -j ACCEPT
    iptables -A DOCKER-USER -p tcp --syn -j DROP
    iptables -A DOCKER-USER -p udp -m limit --limit 3000/s -j ACCEPT
    iptables -A DOCKER-USER -p udp -j DROP

    iptables -A INPUT -p tcp --syn -m limit --limit 500/s --limit-burst 100 -j ACCEPT
    iptables -A INPUT -p tcp --syn -j DROP
    iptables -A INPUT -p udp -m limit --limit 3000/s -j ACCEPT
    iptables -A INPUT -p udp -j DROP

    save_iptables_rules
    echo -e "${gl_lv}DDoS防御已开启（SYN+UDP限制）${gl_bai}"
    send_stats "开启DDoS防御"
}

# 关闭DDoS防御
disable_ddos_defense() {
    root_use
    install iptables

    iptables -D DOCKER-USER -p tcp --syn -m limit --limit 500/s --limit-burst 100 -j ACCEPT 2>/dev/null
    iptables -D DOCKER-USER -p tcp --syn -j DROP 2>/dev/null
    iptables -D DOCKER-USER -p udp -m limit --limit 3000/s -j ACCEPT 2>/dev/null
    iptables -D DOCKER-USER -p udp -j DROP 2>/dev/null

    iptables -D INPUT -p tcp --syn -m limit --limit 500/s --limit-burst 100 -j ACCEPT 2>/dev/null
    iptables -D INPUT -p tcp --syn -j DROP 2>/dev/null
    iptables -D INPUT -p udp -m limit --limit 3000/s -j ACCEPT 2>/dev/null
    iptables -D INPUT -p udp -j DROP 2>/dev/null

    save_iptables_rules
    echo -e "${gl_lv}DDoS防御已关闭${gl_bai}"
    send_stats "关闭DDoS防御"
}

# 国家IP管理（阻止/允许/解除）
manage_country_rules() {
    root_use
    local action="$1"
    local country_code="$2"
    local ipset_name="${country_code,,}_block"
    local download_url="http://www.ipdeny.com/ipblocks/data/countries/${country_code,,}.zone"

    install ipset wget

    if ! [[ "$country_code" =~ ^[A-Za-z]{2}$ ]]; then
        echo -e "${gl_hong}无效国家代码！请输入2位字母（如 CN, US, JP）${gl_bai}"
        return 1
    fi
    country_code=$(echo "$country_code" | tr '[:lower:]' '[:upper:]')

    case "$action" in
        block)
            if ! ipset list "$ipset_name" &> /dev/null; then
                ipset create "$ipset_name" hash:net
            fi

            if ! wget -q "$download_url" -O "${country_code,,}.zone"; then
                echo -e "${gl_hong}错误：下载 $country_code 的IP段文件失败${gl_bai}"
                return 1
            fi

            while IFS= read -r ip; do
                ipset add "$ipset_name" "$ip" 2>/dev/null
            done < "${country_code,,}.zone"

            iptables -I INPUT -m set --match-set "$ipset_name" src -j DROP
            iptables -I OUTPUT -m set --match-set "$ipset_name" dst -j DROP

            echo -e "${gl_lv}已成功阻止 $country_code 国家的所有IP${gl_bai}"
            rm -f "${country_code,,}.zone"
            send_stats "阻止国家IP:$country_code"
            ;;

        allow)
            if ! ipset list "$ipset_name" &> /dev/null; then
                ipset create "$ipset_name" hash:net
            fi

            if ! wget -q "$download_url" -O "${country_code,,}.zone"; then
                echo -e "${gl_hong}错误：下载 $country_code 的IP段文件失败${gl_bai}"
                return 1
            fi

            iptables -D INPUT -m set --match-set "$ipset_name" src -j DROP 2>/dev/null
            iptables -D OUTPUT -m set --match-set "$ipset_name" dst -j DROP 2>/dev/null
            ipset flush "$ipset_name"

            while IFS= read -r ip; do
                ipset add "$ipset_name" "$ip" 2>/dev/null
            done < "${country_code,,}.zone"

            iptables -P INPUT DROP
            iptables -P OUTPUT DROP
            iptables -A INPUT -m set --match-set "$ipset_name" src -j ACCEPT
            iptables -A OUTPUT -m set --match-set "$ipset_name" dst -j ACCEPT
            iptables -A INPUT -i lo -j ACCEPT
            iptables -A OUTPUT -o lo -j ACCEPT
            iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
            iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

            echo -e "${gl_lv}已成功仅允许 $country_code 国家的IP访问${gl_bai}"
            rm -f "${country_code,,}.zone"
            send_stats "仅允许国家IP:$country_code"
            ;;

        unblock)
            iptables -D INPUT -m set --match-set "$ipset_name" src -j DROP 2>/dev/null
            iptables -D OUTPUT -m set --match-set "$ipset_name" dst -j DROP 2>/dev/null

            if ipset list "$ipset_name" &> /dev/null; then
                ipset destroy "$ipset_name"
            fi

            iptables -P INPUT ACCEPT
            iptables -P OUTPUT ACCEPT

            echo -e "${gl_lv}已成功解除 $country_code 国家的IP限制${gl_bai}"
            send_stats "解除国家IP限制:$country_code"
            ;;

        *)
            echo -e "${gl_hong}无效操作！仅支持 block/allow/unblock${gl_bai}"
            ;;
    esac
}

# 阻止容器端口访问（仅允许指定IP）
block_container_port() {
    local container_name_or_id=$1
    local allowed_ip=$2

    # 获取容器的 IP 地址
    local container_ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$container_name_or_id")

    if [ -z "$container_ip" ]; then
        echo "错误：无法获取容器 $container_name_or_id 的 IP 地址。请检查容器名称或ID是否正确。"
        return 1
    fi

    install iptables

    # TCP规则：拒绝所有，允许指定IP和本地
    if ! iptables -C DOCKER-USER -p tcp -d "$container_ip" -j DROP &>/dev/null; then
        iptables -I DOCKER-USER -p tcp -d "$container_ip" -j DROP
    fi
    if ! iptables -C DOCKER-USER -p tcp -s "$allowed_ip" -d "$container_ip" -j ACCEPT &>/dev/null; then
        iptables -I DOCKER-USER -p tcp -s "$allowed_ip" -d "$container_ip" -j ACCEPT
    fi
    if ! iptables -C DOCKER-USER -p tcp -s 127.0.0.0/8 -d "$container_ip" -j ACCEPT &>/dev/null; then
        iptables -I DOCKER-USER -p tcp -s 127.0.0.0/8 -d "$container_ip" -j ACCEPT
    fi

    # UDP规则：拒绝所有，允许指定IP和本地
    if ! iptables -C DOCKER-USER -p udp -d "$container_ip" -j DROP &>/dev/null; then
        iptables -I DOCKER-USER -p udp -d "$container_ip" -j DROP
    fi
    if ! iptables -C DOCKER-USER -p udp -s "$allowed_ip" -d "$container_ip" -j ACCEPT &>/dev/null; then
        iptables -I DOCKER-USER -p udp -s "$allowed_ip" -d "$container_ip" -j ACCEPT
    fi
    if ! iptables -C DOCKER-USER -p udp -s 127.0.0.0/8 -d "$container_ip" -j ACCEPT &>/dev/null; then
        iptables -I DOCKER-USER -p udp -s 127.0.0.0/8 -d "$container_ip" -j ACCEPT
    fi

    # 允许已建立连接
    if ! iptables -C DOCKER-USER -m state --state ESTABLISHED,RELATED -d "$container_ip" -j ACCEPT &>/dev/null; then
        iptables -I DOCKER-USER -m state --state ESTABLISHED,RELATED -d "$container_ip" -j ACCEPT
    fi

    echo "已阻止IP+端口访问该服务（仅允许 $allowed_ip 访问）"
    save_iptables_rules
}

# 清除容器端口限制（允许所有IP）
clear_container_rules() {
    local container_name_or_id=$1
    local allowed_ip=$2

    # 获取容器的 IP 地址
    local container_ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$container_name_or_id")

    if [ -z "$container_ip" ]; then
        echo "错误：无法获取容器 $container_name_or_id 的 IP 地址。请检查容器名称或ID是否正确。"
        return 1
    fi

    install iptables

    # 清除TCP规则
    iptables -D DOCKER-USER -p tcp -d "$container_ip" -j DROP 2>/dev/null
    iptables -D DOCKER-USER -p tcp -s "$allowed_ip" -d "$container_ip" -j ACCEPT 2>/dev/null
    iptables -D DOCKER-USER -p tcp -s 127.0.0.0/8 -d "$container_ip" -j ACCEPT 2>/dev/null

    # 清除UDP规则
    iptables -D DOCKER-USER -p udp -d "$container_ip" -j DROP 2>/dev/null
    iptables -D DOCKER-USER -p udp -s "$allowed_ip" -d "$container_ip" -j ACCEPT 2>/dev/null
    iptables -D DOCKER-USER -p udp -s 127.0.0.0/8 -d "$container_ip" -j ACCEPT 2>/dev/null

    # 清除已建立连接规则
    iptables -D DOCKER-USER -m state --state ESTABLISHED,RELATED -d "$container_ip" -j ACCEPT 2>/dev/null

    echo "已允许所有IP+端口访问该服务"
    save_iptables_rules
}

# 阻止主机端口访问（仅允许指定IP）
block_host_port() {
    local port=$1
    local allowed_ip=$2

    if [[ -z "$port" || -z "$allowed_ip" ]]; then
        echo "错误：请提供端口号和允许访问的 IP。"
        echo "用法: block_host_port <端口号> <允许的IP>"
        return 1
    fi

    install iptables

    # TCP规则：拒绝所有，允许指定IP和本地
    if ! iptables -C INPUT -p tcp --dport "$port" -j DROP &>/dev/null; then
        iptables -I INPUT -p tcp --dport "$port" -j DROP
    fi
    if ! iptables -C INPUT -p tcp --dport "$port" -s "$allowed_ip" -j ACCEPT &>/dev/null; then
        iptables -I INPUT -p tcp --dport "$port" -s "$allowed_ip" -j ACCEPT
    fi
    if ! iptables -C INPUT -p tcp --dport "$port" -s 127.0.0.0/8 -j ACCEPT &>/dev/null; then
        iptables -I INPUT -p tcp --dport "$port" -s 127.0.0.0/8 -j ACCEPT
    fi

    # UDP规则：拒绝所有，允许指定IP和本地
    if ! iptables -C INPUT -p udp --dport "$port" -j DROP &>/dev/null; then
        iptables -I INPUT -p udp --dport "$port" -j DROP
    fi
    if ! iptables -C INPUT -p udp --dport "$port" -s "$allowed_ip" -j ACCEPT &>/dev/null; then
        iptables -I INPUT -p udp --dport "$port" -s "$allowed_ip" -j ACCEPT
    fi
    if ! iptables -C INPUT -p udp --dport "$port" -s 127.0.0.0/8 -j ACCEPT &>/dev/null; then
        iptables -I INPUT -p udp --dport "$port" -s 127.0.0.0/8 -j ACCEPT
    fi

    # 允许已建立连接
    if ! iptables -C INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT &>/dev/null; then
        iptables -I INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    fi

    echo "已阻止IP+端口访问该服务（仅允许 $allowed_ip 访问端口 $port）"
    save_iptables_rules
}

# 清除主机端口限制（允许所有IP）
clear_host_port_rules() {
    local port=$1
    local allowed_ip=$2

    if [[ -z "$port" || -z "$allowed_ip" ]]; then
        echo "错误：请提供端口号和允许访问的 IP。"
        echo "用法: clear_host_port_rules <端口号> <允许的IP>"
        return 1
    fi

    install iptables

    # 清除TCP规则
    iptables -D INPUT -p tcp --dport "$port" -j DROP 2>/dev/null
    iptables -D INPUT -p tcp --dport "$port" -s "$allowed_ip" -j ACCEPT 2>/dev/null
    iptables -D INPUT -p tcp --dport "$port" -s 127.0.0.0/8 -j ACCEPT 2>/dev/null

    # 清除UDP规则
    iptables -D INPUT -p udp --dport "$port" -j DROP 2>/dev/null
    iptables -D INPUT -p udp --dport "$port" -s "$allowed_ip" -j ACCEPT 2>/dev/null
    iptables -D INPUT -p udp --dport "$port" -s 127.0.0.0/8 -j ACCEPT 2>/dev/null

    echo "已允许所有IP+端口访问该服务（端口 $port）"
    save_iptables_rules
}

# 高级防火墙管理面板
iptables_panel() {
    root_use
    install iptables
    save_iptables_rules

    while true; do
        clear
        echo -e "${gl_XLtool}====== 高级防火墙管理 ======${gl_bai}"
        echo -e "${gl_huang}当前INPUT链规则（前20条）:${gl_bai}"
        iptables -L INPUT --line-numbers | head -20
        echo -e "\n${gl_XLtool}------------------------${gl_bai}"
        echo "1. 开放指定端口（支持多端口，空格分隔）"
        echo "2. 关闭指定端口（支持多端口，空格分隔）"
        echo "3. 开放所有端口（重置iptables规则）"
        echo "4. 关闭所有端口（仅保留SSH端口）"
        echo -e "${gl_XLtool}------------------------${gl_bai}"
        echo "5. IP白名单（放行指定IP/IP段）"
        echo "6. IP黑名单（阻止指定IP/IP段）"
        echo "7. 清除指定IP的规则"
        echo -e "${gl_XLtool}------------------------${gl_bai}"
        echo "11. 允许PING"
        echo "12. 禁止PING"
        echo -e "${gl_XLtool}------------------------${gl_bai}"
        echo "13. 启动DDoS防御（SYN+UDP限制）"
        echo "14. 关闭DDoS防御"
        echo -e "${gl_XLtool}------------------------${gl_bai}"
        echo "15. 阻止指定国家IP"
        echo "16. 仅允许指定国家IP"
        echo "17. 解除指定国家IP限制"
        echo -e "${gl_XLtool}------------------------${gl_bai}"
        echo "0. 返回上一级选单"
        echo -e "${gl_XLtool}------------------------${gl_bai}"
        
        read -e -p "请输入你的选择: " sub_choice
        case $sub_choice in
            1)
                read -e -p "请输入开放的端口号（多端口空格分隔）: " o_port
                open_port $o_port
                ;;
            2)
                read -e -p "请输入关闭的端口号（多端口空格分隔）: " c_port
                close_port $c_port
                ;;
            3)
                iptables_open
                ;;
            4)
                local current_port=$(grep -E '^Port [0-9]+' /etc/ssh/sshd_config | awk '{print $2}' || echo 22)
                iptables -F
                iptables -X
                iptables -P INPUT DROP
                iptables -P FORWARD DROP
                iptables -P OUTPUT ACCEPT
                iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
                iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
                iptables -A INPUT -i lo -j ACCEPT
                iptables -A FORWARD -i lo -j ACCEPT
                iptables -A INPUT -p tcp --dport $current_port -j ACCEPT
                save_iptables_rules
                echo -e "${gl_lv}已关闭所有端口，仅保留SSH端口: $current_port${gl_bai}"
                send_stats "关闭所有端口（保留SSH:$current_port）"
                ;;
            5)
                read -e -p "请输入放行的IP或IP段（多IP空格分隔）: " o_ip
                allow_ip $o_ip
                ;;
            6)
                read -e -p "请输入封锁的IP或IP段（多IP空格分隔）: " c_ip
                block_ip $c_ip
                ;;
            7)
                read -e -p "请输入清除规则的IP: " d_ip
                iptables -D INPUT -s $d_ip -j ACCEPT 2>/dev/null
                iptables -D INPUT -s $d_ip -j DROP 2>/dev/null
                save_iptables_rules
                echo -e "${gl_lv}已清除IP: $d_ip 的所有规则${gl_bai}"
                send_stats "清除IP规则:$d_ip"
                ;;
            11)
                iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
                iptables -A OUTPUT -p icmp --icmp-type echo-reply -j ACCEPT
                save_iptables_rules
                echo -e "${gl_lv}已允许PING${gl_bai}"
                send_stats "允许PING"
                ;;
            12)
                iptables -D INPUT -p icmp --icmp-type echo-request -j ACCEPT 2>/dev/null
                iptables -D OUTPUT -p icmp --icmp-type echo-reply -j ACCEPT 2>/dev/null
                save_iptables_rules
                echo -e "${gl_lv}已禁止PING${gl_bai}"
                send_stats "禁止PING"
                ;;
            13)
                enable_ddos_defense
                ;;
            14)
                disable_ddos_defense
                ;;
            15)
                read -e -p "请输入阻止的国家代码（如 CN, US）: " country_code
                manage_country_rules block $country_code
                ;;
            16)
                read -e -p "请输入允许的国家代码（如 CN, US）: " country_code
                manage_country_rules allow $country_code
                ;;
            17)
                read -e -p "请输入解除限制的国家代码（如 CN, US）: " country_code
                manage_country_rules unblock $country_code
                ;;
            0)
                break
                ;;
            *)
                echo -e "${gl_hong}❌ 无效选择，请重新输入${gl_bai}"
                ;;
        esac
        break_end
    done
}

# ============== Swap 虚拟内存管理函数 ==============
# 添加Swap（指定大小，单位：MB）
add_swap() {
    root_use
    local new_swap=$1

    if ! [[ "$new_swap" =~ ^[0-9]+$ ]]; then
        echo -e "${gl_hong}无效大小！请输入数字（单位：MB）${gl_bai}"
        return 1
    fi
    if [ "$new_swap" -lt 256 ]; then
        echo -e "${gl_hong}Swap大小不能小于256MB${gl_bai}"
        return 1
    fi

    # 清理现有Swap
    local swap_partitions=$(grep -E '^/dev/' /proc/swaps | awk '{print $1}')
    for partition in $swap_partitions; do
        swapoff "$partition" 2>/dev/null
        wipefs -a "$partition" 2>/dev/null
    done
    swapoff /swapfile 2>/dev/null
    rm -f /swapfile

    # 创建新Swap
    if command -v fallocate &>/dev/null; then
        fallocate -l ${new_swap}M /swapfile
    else
        dd if=/dev/zero of=/swapfile bs=1M count=$new_swap
    fi

    # 配置Swap权限与开机自启
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile

    sed -i '/\/swapfile/d' /etc/fstab 2>/dev/null
    echo "/swapfile swap swap defaults 0 0" >> /etc/fstab

    # Alpine系统特殊处理
    if [ -f /etc/alpine-release ]; then
        echo "nohup swapon /swapfile &" > /etc/local.d/swap.start
        chmod +x /etc/local.d/swap.start
        rc-update add local default 2>/dev/null
    fi

    echo -e "${gl_lv}Swap虚拟内存已创建，大小：${new_swap}MB${gl_bai}"
    send_stats "添加Swap:${new_swap}MB"
}

# 检查并初始化Swap（无则创建1024MB）
check_swap() {
    root_use
    local swap_total=$(free -m | awk 'NR==3{print $2}')

    if [ "$swap_total" -le 0 ]; then
        echo -e "${gl_huang}未检测到Swap，自动创建1024MB Swap...${gl_bai}"
        add_swap 1024
    else
        echo -e "${gl_huang}当前Swap大小：${swap_total}MB，无需创建${gl_bai}"
    fi
}

# Swap 虚拟内存管理菜单
swap_manage_menu() {
    while true; do
        clear
        echo -e "${gl_XLtool}====== Swap 虚拟内存管理 ======${gl_bai}"
        send_stats "进入Swap虚拟内存管理菜单"
        local swap_total=$(free -m | awk 'NR==3{print $2}')
        local swap_used=$(free -m | awk 'NR==3{print $3}')
        local swap_free=$(free -m | awk 'NR==3{print $4}')
        echo -e "${gl_huang}当前Swap状态:${gl_bai}"
        echo "总大小: ${swap_total}MB"
        echo "已使用: ${swap_used}MB"
        echo "空闲: ${swap_free}MB"
        echo -e "\n${gl_XLtool}操作选项${gl_bai}"
        echo -e "${gl_XLtool}------------------------${gl_bai}"
        echo "1. 初始化Swap（无Swap时创建1024MB）"
        echo "2. 自定义创建Swap（指定大小，单位：MB）"
        echo "3. 查看Swap挂载信息"
        echo -e "${gl_XLtool}------------------------${gl_bai}"
        echo "0. 返回上一级选单"
        echo -e "${gl_XLtool}------------------------${gl_bai}"
        
        read -e -p "请输入你的选择: " sub_choice
        case $sub_choice in
            1)
                check_swap
                ;;
            2)
                read -e -p "请输入Swap大小（单位：MB，最小256MB）: " swap_size
                add_swap $swap_size
                ;;
            3)
                echo -e "${gl_huang}Swap挂载信息:${gl_bai}"
                cat /proc/swaps
                echo -e "\n${gl_huang}开机自启配置（/etc/fstab）:${gl_bai}"
                grep "/swapfile" /etc/fstab 2>/dev/null || echo "未配置Swap开机自启"
                send_stats "查看Swap挂载信息"
                ;;
            0)
                break
                ;;
            *)
                echo -e "${gl_hong}❌ 无效选择，请重新输入${gl_bai}"
                ;;
        esac
        break_end
    done
}

# ============== Docker IPv6 配置函数 ==============
# 开启Docker IPv6
docker_ipv6_on() {
    root_use
    install jq  # 确保jq工具存在

    local CONFIG_FILE="/etc/docker/daemon.json"
    local REQUIRED_IPV6_CONFIG='{"ipv6": true, "fixed-cidr-v6": "2001:db8:1::/64"}'

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "$REQUIRED_IPV6_CONFIG" | jq . > "$CONFIG_FILE"
        restart docker
        echo -e "${gl_lv}Docker IPv6 已开启，已重启Docker服务${gl_bai}"
    else
        local ORIGINAL_CONFIG=$(<"$CONFIG_FILE")
        local CURRENT_IPV6=$(echo "$ORIGINAL_CONFIG" | jq '.ipv6 // false')

        if [[ "$CURRENT_IPV6" == "false" ]]; then
            UPDATED_CONFIG=$(echo "$ORIGINAL_CONFIG" | jq '. + {ipv6: true, "fixed-cidr-v6": "2001:db8:1::/64"}')
        else
            UPDATED_CONFIG=$(echo "$ORIGINAL_CONFIG" | jq '. + {"fixed-cidr-v6": "2001:db8:1::/64"}')
        fi

        if [[ "$ORIGINAL_CONFIG" == "$UPDATED_CONFIG" ]]; then
            echo -e "${gl_huang}当前已开启Docker IPv6访问${gl_bai}"
        else
            echo "$UPDATED_CONFIG" | jq . > "$CONFIG_FILE"
            restart docker
            echo -e "${gl_lv}Docker IPv6 配置已更新，已重启Docker服务${gl_bai}"
        fi
    fi
    send_stats "开启Docker IPv6"
}

# 关闭Docker IPv6
docker_ipv6_off() {
    root_use
    install jq

    local CONFIG_FILE="/etc/docker/daemon.json"

    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${gl_hong}Docker配置文件不存在，无需关闭IPv6${gl_bai}"
        return
    fi

    local ORIGINAL_CONFIG=$(<"$CONFIG_FILE")
    local UPDATED_CONFIG=$(echo "$ORIGINAL_CONFIG" | jq 'del(.["fixed-cidr-v6"]) | .ipv6 = false')
    local CURRENT_IPV6=$(echo "$ORIGINAL_CONFIG" | jq -r '.ipv6 // false')

    if [[ "$CURRENT_IPV6" == "false" ]]; then
        echo -e "${gl_huang}当前已关闭Docker IPv6访问${gl_bai}"
    else
        echo "$UPDATED_CONFIG" | jq . > "$CONFIG_FILE"
        restart docker
        echo -e "${gl_lv}Docker IPv6 已关闭，已重启Docker服务${gl_bai}"
    fi
    send_stats "关闭Docker IPv6"
}

# Docker IPv6 配置菜单
docker_ipv6_menu() {
    while true; do
        clear
        echo -e "${gl_XLtool}====== Docker IPv6 配置 ======${gl_bai}"
        send_stats "进入Docker IPv6配置菜单"
        local config_file="/etc/docker/daemon.json"
        local ipv6_status="未配置"
        local cidr_v6="无"
        if [ -f "$config_file" ]; then
            ipv6_status=$(sudo cat "$config_file" | jq -r '.ipv6 // "false"')
            cidr_v6=$(sudo cat "$config_file" | jq -r '."fixed-cidr-v6" // "无"')
        fi
        echo -e "${gl_huang}当前状态:${gl_bai}"
        echo "IPv6 启用: $ipv6_status"
        echo "IPv6 子网: $cidr_v6"
        echo -e "\n${gl_XLtool}操作选项${gl_bai}"
        echo -e "${gl_XLtool}------------------------${gl_bai}"
        echo "1. 开启 Docker IPv6（默认子网：2001:db8:1::/64）"
        echo "2. 关闭 Docker IPv6"
        echo "3. 查看 Docker 网络配置（含IPv6）"
        echo -e "${gl_XLtool}------------------------${gl_bai}"
        echo "0. 返回上一级选单"
        echo -e "${gl_XLtool}------------------------${gl_bai}"
        
        read -e -p "请输入你的选择: " sub_choice
        case $sub_choice in
            1)
                docker_ipv6_on
                ;;
            2)
                docker_ipv6_off
                ;;
            3)
                echo -e "${gl_huang}Docker 网络配置详情:${gl_bai}"
                sudo docker network inspect $(sudo docker network ls -q) | jq '.[] | {Name, Driver, IPAM: .IPAM.Config}'
                send_stats "查看Docker网络配置"
                ;;
            0)
                break
                ;;
            *)
                echo -e "${gl_hong}❌ 无效选择，请重新输入${gl_bai}"
                ;;
        esac
        break_end
    done
}

# ============== Docker 核心功能 ==============
# Docker国内镜像配置
install_add_docker_cn() {
    local country=$(curl -s ipinfo.io/country 2>/dev/null)
    if [ "$country" = "CN" ]; then
        echo -e "${gl_huang}>>> 检测到国内环境，配置Docker国内镜像源...${gl_bai}"
        sudo mkdir -p /etc/docker
        sudo cat > /etc/docker/daemon.json << EOF
{
  "registry-mirrors": [
    "https://docker-0.unsee.tech",
    "https://docker.1panel.live",
    "https://registry.dockermirror.com",
    "https://docker.imgdb.de",
    "https://docker.m.daocloud.io"
  ]
}
EOF
        enable docker
        start docker
        restart docker
        echo -e "${gl_lv}>>> Docker国内镜像源配置完成！${gl_bai}"
        send_stats "Docker国内镜像配置完成"
    fi
}

# Docker官方安装（兼容国内/海外）
install_add_docker_guanfang() {
    local country=$(curl -s ipinfo.io/country 2>/dev/null)
    if [ "$country" = "CN" ]; then
        echo -e "${gl_huang}>>> 国内环境，使用阿里云镜像+GitHub代理安装Docker...${gl_bai}"
        cd ~
        curl -sS -O ${gh_proxy}raw.githubusercontent.com/kejilion/docker/main/install && chmod +x install
        sh install --mirror Aliyun
        rm -f install
        send_stats "国内环境Docker安装完成"
    else
        echo -e "${gl_huang}>>> 海外环境，使用官方脚本安装Docker...${gl_bai}"
        curl -fsSL https://get.docker.com | sh
        send_stats "海外环境Docker安装完成"
    fi
    install_add_docker_cn
}

# Docker安装（多系统适配）
install_add_docker() {
    echo -e "${gl_huang}正在安装Docker环境...${gl_bai}"
    install_dependency
    check_disk_space 20

    if [ -f /etc/os-release ] && grep -q "Fedora" /etc/os-release; then
        install_add_docker_guanfang
    
    elif command -v dnf &>/dev/null; then
        sudo dnf update -y
        sudo dnf install -y yum-utils device-mapper-persistent-data lvm2
        sudo rm -f /etc/yum.repos.d/docker*.repo > /dev/null
        local country=$(curl -s ipinfo.io/country 2>/dev/null)
        
        if [ "$country" = "CN" ]; then
            curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo | sudo tee /etc/yum.repos.d/docker-ce.repo > /dev/null
        else
            sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo > /dev/null
        fi
        
        sudo dnf install -y docker-ce docker-ce-cli containerd.io
        install_add_docker_cn
        send_stats "CentOS/RHEL Docker安装完成"
    
    elif [ -f /etc/os-release ] && grep -q "Kali" /etc/os-release; then
        sudo apt update -y
        sudo apt upgrade -y
        sudo rm -f /usr/share/keyrings/docker-archive-keyring.gpg
        local country=$(curl -s ipinfo.io/country 2>/dev/null)
        local arch=$(uname -m)
        
        if [ "$country" = "CN" ]; then
            sudo mkdir -p /etc/apt/keyrings
            curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/debian/gpg | gpg --dearmor | sudo tee /etc/apt/keyrings/docker-archive-keyring.gpg > /dev/null
            if [ "$arch" = "x86_64" ]; then
                echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker-archive-keyring.gpg] https://mirrors.aliyun.com/docker-ce/linux/debian bullseye stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            elif [ "$arch" = "aarch64" ]; then
                echo "deb [arch=arm64 signed-by=/etc/apt/keyrings/docker-archive-keyring.gpg] https://mirrors.aliyun.com/docker-ce/linux/debian bullseye stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            fi
        else
            sudo mkdir -p /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor | sudo tee /etc/apt/keyrings/docker-archive-keyring.gpg > /dev/null
            if [ "$arch" = "x86_64" ]; then
                echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian bullseye stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            elif [ "$arch" = "aarch64" ]; then
                echo "deb [arch=arm64 signed-by=/etc/apt/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian bullseye stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            fi
        fi
        
        sudo apt update -y
        sudo apt install -y docker-ce docker-ce-cli containerd.io
        install_add_docker_cn
        send_stats "Kali Docker安装完成"
    
    elif command -v apt &>/dev/null || command -v yum &>/dev/null; then
        install_add_docker_guanfang
    
    else
        echo -e "${gl_huang}>>> 检测到未知系统，尝试通用安装...${gl_bai}"
        install docker docker-compose
        install_add_docker_cn
        send_stats "通用系统Docker安装完成"
    fi
    
    sleep 2
    echo -e "${gl_lv}>>> Docker基础环境安装完成！${gl_bai}"
}

# Docker安装入口（判断是否已安装）
install_docker() {
    if ! command -v docker &>/dev/null; then
        install_add_docker
        send_stats "Docker首次安装完成"
    else
        echo -e "${gl_huang}>>> Docker已安装，跳过安装步骤...${gl_bai}"
        send_stats "Docker已安装，跳过安装"
    fi
}

# Docker 镜像管理
docker_image() {
    while true; do
        clear
        echo -e "${gl_XLtool}====== Docker 镜像管理 ======${gl_bai}"
        send_stats "进入Docker镜像管理"
        echo -e "${gl_huang}当前镜像列表:${gl_bai}"
        sudo docker image ls
        echo -e "\n${gl_XLtool}镜像操作${gl_bai}"
        echo -e "${gl_XLtool}------------------------${gl_bai}"
        echo "1. 获取指定镜像（支持多镜像，空格分隔）"
        echo "2. 更新指定镜像（支持多镜像，空格分隔）"
        echo "3. 删除指定镜像（支持多镜像，空格分隔）"
        echo "4. 删除所有镜像（需确认）"
        echo -e "${gl_XLtool}------------------------${gl_bai}"
        echo "0. 返回上一级选单"
        echo -e "${gl_XLtool}------------------------${gl_bai}"
        
        read -e -p "请输入你的选择: " sub_choice
        case $sub_choice in
            1)
                send_stats "拉取Docker镜像"
                read -e -p "请输入镜像名（多镜像空格分隔，如 nginx redis）: " imagenames
                for name in $imagenames; do
                    echo -e "${gl_huang}正在拉取镜像: $name${gl_bai}"
                    sudo docker pull $name
                    if [ $? -eq 0 ]; then
                        echo -e "${gl_lv}镜像 $name 拉取完成${gl_bai}"
                    else
                        echo -e "${gl_hong}镜像 $name 拉取失败${gl_bai}"
                    fi
                done
                ;;
            2)
                send_stats "更新Docker镜像"
                read -e -p "请输入镜像名（多镜像空格分隔，如 nginx redis）: " imagenames
                for name in $imagenames; do
                    echo -e "${gl_huang}正在更新镜像: $name${gl_bai}"
                    sudo docker pull $name
                    if [ $? -eq 0 ]; then
                        echo -e "${gl_lv}镜像 $name 更新完成${gl_bai}"
                    else
                        echo -e "${gl_hong}镜像 $name 更新失败${gl_bai}"
                    fi
                done
                ;;
            3)
                send_stats "删除Docker镜像"
                read -e -p "请输入镜像名/ID（多镜像空格分隔）: " imagenames
                for name in $imagenames; do
                    echo -e "${gl_huang}正在删除镜像: $name${gl_bai}"
                    sudo docker rmi -f $name
                    if [ $? -eq 0 ]; then
                        echo -e "${gl_lv}镜像 $name 删除完成${gl_bai}"
                    else
                        echo -e "${gl_hong}镜像 $name 删除失败（可能被容器占用）${gl_bai}"
                    fi
                done
                ;;
            4)
                send_stats "删除所有Docker镜像"
                read -e -p "$(echo -e "${gl_hong}警告: ${gl_bai}确定删除所有镜像吗？这将删除所有未使用/已使用的镜像！(Y/N): ")" choice
                case "$choice" in
                  [Yy])
                    echo -e "${gl_huang}正在删除所有镜像...${gl_bai}"
                    sudo docker rmi -f $(sudo docker images -q 2>/dev/null)
                    if [ $? -eq 0 ]; then
                        echo -e "${gl_lv}所有镜像删除完成${gl_bai}"
                    else
                        echo -e "${gl_hong}部分镜像删除失败（可能被运行中容器占用）${gl_bai}"
                    fi
                    ;;
                  [Nn])
                    echo -e "${gl_huang}已取消删除操作${gl_bai}"
                    ;;
                  *)
                    echo -e "${gl_hong}无效的选择，请输入 Y 或 N${gl_bai}"
                    ;;
                esac
                ;;
            0)
                break
                ;;
            *)
                echo -e "${gl_hong}❌ 无效选择，请重新输入${gl_bai}"
                ;;
        esac
        break_end
    done
}

# Docker 容器管理
docker_ps() {
    while true; do
        clear
        echo -e "${gl_XLtool}====== Docker 容器管理 ======${gl_bai}"
        send_stats "进入Docker容器管理"
        sudo docker ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}"
        echo -e "${gl_XLtool}-----------------------------${gl_bai}"
        echo "1. 创建新的容器"
        echo "2. 启动指定容器         6. 启动所有容器"
        echo "3. 停止指定容器         7. 停止所有容器"
        echo "4. 删除指定容器         8. 删除所有容器"
        echo "5. 重启指定容器         9. 重启所有容器"
        echo "11. 进入指定容器       12. 查看容器日志"
        echo "13. 查看容器网络       14. 查看容器占用"
        echo "0. 返回上一级"
        echo -e "${gl_XLtool}-----------------------------${gl_bai}"
        read -p "请输入选择: " c
        case $c in
            1) 
                read -p "输入镜像名: " img; read -p "输入容器名: " cname; 
                sudo docker run -dit --name $cname $img; 
                send_stats "创建Docker容器:$cname(镜像:$img)"
                ;;
            2) read -p "容器ID/名称: " id; sudo docker start $id; send_stats "启动Docker容器:$id";;
            3) read -p "容器ID/名称: " id; sudo docker stop $id; send_stats "停止Docker容器:$id";;
            4) read -p "容器ID/名称: " id; sudo docker rm -f $id; send_stats "删除Docker容器:$id";;
            5) read -p "容器ID/名称: " id; sudo docker restart $id; send_stats "重启Docker容器:$id";;
            6) sudo docker start $(sudo docker ps -aq); send_stats "启动所有Docker容器";;
            7) sudo docker stop $(sudo docker ps -aq); send_stats "停止所有Docker容器";;
            8) sudo docker rm -f $(sudo docker ps -aq); send_stats "删除所有Docker容器";;
            9) sudo docker restart $(sudo docker ps -q); send_stats "重启所有运行中Docker容器";;
            11) read -p "容器ID/名称: " id; sudo docker exec -it $id /bin/bash; send_stats "进入Docker容器:$id";;
            12) read -p "容器ID/名称: " id; read -p "显示行数(默认100): " lines; 
                lines=${lines:-100}; sudo docker logs --tail $lines $id; 
                send_stats "查看Docker容器日志:$id";;
            13) read -p "容器ID/名称: " id; sudo docker inspect $id | jq '.[] | .NetworkSettings'; 
                send_stats "查看Docker容器网络:$id";;
            14) sudo docker stats; send_stats "查看Docker容器资源占用";;
            0) break;;
            *) echo -e "${gl_hong}无效选择${gl_bai}";;
        esac
        break_end
    done
}

# Docker Compose 管理
docker_compose() {
    install docker-compose
    while true; do
        clear
        echo -e "${gl_XLtool}====== Docker Compose 管理 ======${gl_bai}"
        send_stats "进入Docker Compose管理"
        echo "1. 新建Compose项目（创建docker-compose.yml）"
        echo "2. 启动当前目录Compose项目（up -d）"
        echo "3. 停止当前目录Compose项目（down）"
        echo "4. 重启当前目录Compose项目（restart）"
        echo "5. 查看当前目录Compose日志（logs）"
        echo "6. 查看当前目录Compose状态（ps）"
        echo -e "${gl_XLtool}------------------------${gl_bai}"
        echo "0. 返回上一级选单"
        echo -e "${gl_XLtool}------------------------${gl_bai}"
        
        read -e -p "请输入你的选择: " sub_choice
        case $sub_choice in
            1)
                send_stats "新建Docker Compose项目"
                read -e -p "请输入项目名称（用于创建目录）: " proj_name
                mkdir -p "$proj_name" && cd "$proj_name"
                echo -e "${gl_huang}正在创建基础docker-compose.yml...${gl_bai}"
                cat > docker-compose.yml << 'EOF'
version: '3'
services:
  # 示例：Nginx服务
  nginx:
    image: nginx:latest
    container_name: my-nginx
    ports:
      - "80:80"
    volumes:
      - ./nginx/conf:/etc/nginx/conf.d
      - ./nginx/html:/usr/share/nginx/html
    restart: always
EOF
                echo -e "${gl_lv}已在 $(pwd)/docker-compose.yml 创建基础配置${gl_bai}"
                echo "可使用 nano docker-compose.yml 编辑配置"
                cd ..
                ;;
            2)
                send_stats "启动Docker Compose项目"
                if [ -f "docker-compose.yml" ]; then
                    sudo docker-compose up -d
                    echo -e "${gl_lv}Compose项目已启动${gl_bai}"
                else
                    echo -e "${gl_hong}当前目录未找到 docker-compose.yml${gl_bai}"
                fi
                ;;
            3)
                send_stats "停止Docker Compose项目"
                if [ -f "docker-compose.yml" ]; then
                    sudo docker-compose down
                    echo -e "${gl_lv}Compose项目已停止${gl_bai}"
                else
                    echo -e "${gl_hong}当前目录未找到 docker-compose.yml${gl_bai}"
                fi
                ;;
            4)
                send_stats "重启Docker Compose项目"
                if [ -f "docker-compose.yml" ]; then
                    sudo docker-compose restart
                    echo -e "${gl_lv}Compose项目已重启${gl_bai}"
                else
                    echo -e "${gl_hong}当前目录未找到 docker-compose.yml${gl_bai}"
                fi
                ;;
            5)
                send_stats "查看Docker Compose日志"
                if [ -f "docker-compose.yml" ]; then
                    read -e -p "显示行数(默认100): " lines
                    lines=${lines:-100}
                    sudo docker-compose logs --tail $lines
                else
                    echo -e "${gl_hong}当前目录未找到 docker-compose.yml${gl_bai}"
                fi
                ;;
            6)
                send_stats "查看Docker Compose状态"
                if [ -f "docker-compose.yml" ]; then
                    sudo docker-compose ps
                else
                    echo -e "${gl_hong}当前目录未找到 docker-compose.yml${gl_bai}"
                fi
                ;;
            0)
                break
                ;;
            *)
                echo -e "${gl_hong}❌ 无效选择，请重新输入${gl_bai}"
                ;;
        esac
        break_end
    done
}

# Docker 应用快速部署（预设常用应用）
docker_app_deploy() {
    install_docker
    while true; do
        clear
        echo -e "${gl_XLtool}====== Docker 应用快速部署 ======${gl_bai}"
        send_stats "进入Docker应用快速部署"
        echo "1. Nginx（Web服务器）        2. MySQL（数据库）"
        echo "3. Redis（缓存数据库）       4. MongoDB（文档数据库）"
        echo "5. PostgreSQL（关系型数据库） 6. PHP（7.4版本）"
        echo "7. Node.js（最新版）         8. Python（最新版）"
        echo "9. Jenkins（CI/CD工具）      10. GitLab（代码仓库）"
        echo "11. WordPress（博客系统）    12. 自定义Docker应用"
        echo -e "${gl_XLtool}------------------------${gl_bai}"
        echo "0. 返回上一级选单"
        echo -e "${gl_XLtool}------------------------${gl_bai}"
        
        read -e -p "请输入你的选择: " app_choice
        case $app_choice in
            1)  # Nginx
                docker_name="nginx"
                docker_img="nginx:latest"
                read -e -p "请输入映射端口（默认80）: " docker_port
                docker_port=${docker_port:-80}
                read -e -p "请输入数据目录（默认./nginx）: " data_dir
                data_dir=${data_dir:-./nginx}
                mkdir -p $data_dir/{conf,html,logs}
                sudo docker run -dit --name $docker_name \
                    -p $docker_port:80 \
                    -v $data_dir/conf:/etc/nginx/conf.d \
                    -v $data_dir/html:/usr/share/nginx/html \
                    -v $data_dir/logs:/var/log/nginx \
                    --restart always \
                    $docker_img
                echo -e "${gl_lv}Nginx已部署，访问地址: http://$(curl -s ipinfo.io/ip):$docker_port${gl_bai}"
                send_stats "部署Docker应用:Nginx"
                ;;
            2)  # MySQL
                docker_name="mysql"
                docker_img="mysql:latest"
                read -e -p "请输入映射端口（默认3306）: " docker_port
                docker_port=${docker_port:-3306}
                read -e -p "请输入root密码: " mysql_pwd
                read -e -p "请输入数据目录（默认./mysql）: " data_dir
                data_dir=${data_dir:-./mysql}
                mkdir -p $data_dir
                sudo docker run -dit --name $docker_name \
                    -p $docker_port:3306 \
                    -v $data_dir:/var/lib/mysql \
                    -e MYSQL_ROOT_PASSWORD=$mysql_pwd \
                    --restart always \
                    $docker_img
                echo -e "${gl_lv}MySQL已部署，端口: $docker_port，密码: $mysql_pwd${gl_bai}"
                send_stats "部署Docker应用:MySQL"
                ;;
            3)  # Redis
                docker_name="redis"
                docker_img="redis:latest"
                read -e -p "请输入映射端口（默认6379）: " docker_port
                docker_port=${docker_port:-6379}
                read -e -p "请输入数据目录（默认./redis）: " data_dir
                data_dir=${data_dir:-./redis}
                mkdir -p $data_dir
                sudo docker run -dit --name $docker_name \
                    -p $docker_port:6379 \
                    -v $data_dir:/data \
                    --restart always \
                    $docker_img redis-server --appendonly yes
                echo -e "${gl_lv}Redis已部署，端口: $docker_port${gl_bai}"
                send_stats "部署Docker应用:Redis"
                ;;
            12)  # 自定义应用
                read -e -p "请输入镜像名: " docker_img
                read -e -p "请输入容器名: " docker_name
                read -e -p "请输入端口映射（格式 宿主端口:容器端口，如 8080:80）: " port_map
                read -e -p "是否需要数据挂载？(y/n): " mount_choice
                mount_opt=""
                if [ "$mount_choice" = "y" ] || [ "$mount_choice" = "Y" ]; then
                    read -e -p "宿主目录: " host_dir
                    read -e -p "容器目录: " container_dir
                    mkdir -p $host_dir
                    mount_opt="-v $host_dir:$container_dir"
                fi
                sudo docker run -dit --name $docker_name -p $port_map $mount_opt --restart always $docker_img
                echo -e "${gl_lv}自定义容器 $docker_name 已创建${gl_bai}"
                send_stats "部署Docker应用:自定义($docker_img)"
                ;;
            0)
                break
                ;;
            *)
                echo -e "${gl_hong}❌ 功能开发中，敬请期待${gl_bai}"
                ;;
        esac
        break_end
    done
}

# Docker 管理主菜单
docker_menu() {
    while true; do
        clear
        echo -e "${gl_XLtool}====== Docker 管理中心 ======${gl_bai}"
        send_stats "进入Docker管理中心"
        if ! command -v docker &>/dev/null; then
            echo -e "${gl_huang}检测到未安装Docker环境${gl_bai}"
        else
            echo -e "${gl_huang}Docker状态: 已安装 (版本: $(docker --version | awk '{print $3}' | cut -d',' -f1))${gl_bai}"
            echo -e "${gl_huang}运行中容器: $(docker ps | wc -l | awk '{print $1-1}') 个${gl_bai}"
            echo -e "${gl_huang}镜像数量: $(docker images | wc -l | awk '{print $1-1}') 个${gl_bai}"
        fi
        echo -e "\n${gl_XLtool}核心功能${gl_bai}"
        echo -e "${gl_XLtool}------------------------${gl_bai}"
        echo "1. 安装/更新 Docker 环境"
        echo "2. 容器管理（启动/停止/删除等）"
        echo "3. 镜像管理（拉取/更新/删除等）"
        echo "4. Docker Compose 管理"
        echo -e "${gl_XLtool}------------------------${gl_bai}"
        echo "5. 常用应用快速部署（Nginx/MySQL等）"
        echo "6. Docker IPv6 配置"
        echo "7. 清理Docker缓存（镜像/容器/卷）"
        echo -e "${gl_XLtool}------------------------${gl_bai}"
        echo "0. 返回主菜单"
        echo -e "${gl_XLtool}------------------------${gl_bai}"
        
        read -e -p "请输入你的选择: " choice
        case $choice in
            1)
                install_docker
                ;;
            2)
                if command -v docker &>/dev/null; then
                    docker_ps
                else
                    echo -e "${gl_hong}请先安装Docker环境（选择1）${gl_bai}"
                fi
                ;;
            3)
                if command -v docker &>/dev/null; then
                    docker_image
                else
                    echo -e "${gl_hong}请先安装Docker环境（选择1）${gl_bai}"
                fi
                ;;
            4)
                if command -v docker &>/dev/null; then
                    docker_compose
                else
                    echo -e "${gl_hong}请先安装Docker环境（选择1）${gl_bai}"
                fi
                ;;
            5)
                docker_app_deploy
                ;;
            6)
                if command -v docker &>/dev/null; then
                    docker_ipv6_menu
                else
                    echo -e "${gl_hong}请先安装Docker环境（选择1）${gl_bai}"
                fi
                ;;
            7)
                if command -v docker &>/dev/null; then
                    read -e -p "$(echo -e "${gl_hong}警告: ${gl_bai}确定清理所有未使用的镜像、容器、卷和网络吗？(Y/N): ")" confirm
                    if [ "$confirm" = "Y" ] || [ "$confirm" = "y" ]; then
                        sudo docker system prune -a -f --volumes
                        echo -e "${gl_lv}Docker缓存清理完成${gl_bai}"
                        send_stats "清理Docker缓存"
                    else
                        echo -e "${gl_huang}已取消清理操作${gl_bai}"
                    fi
                else
                    echo -e "${gl_hong}请先安装Docker环境（选择1）${gl_bai}"
                fi
                ;;
            0)
                break
                ;;
            *)
                echo -e "${gl_hong}❌ 无效选择，请重新输入${gl_bai}"
                ;;
        esac
        break_end
    done
}

# ============== LDNMP (Linux+Nginx+Docker+MySQL+PHP) 相关 ==============
# LDNMP 安装
install_ldnmp() {
    root_use
    install_dependency
    check_disk_space 5
    install_docker

    echo -e "${gl_huang}正在部署LDNMP环境...${gl_bai}"
    mkdir -p /opt/ldnmp/{nginx,mysql,php,www,logs}
    cd /opt/ldnmp

    # 创建docker-compose.yml
    cat > docker-compose.yml << 'EOF'
version: '3'
services:
  nginx:
    image: nginx:latest
    container_name: ldnmp-nginx
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/conf:/etc/nginx/conf.d
      - ./nginx/ssl:/etc/nginx/ssl
      - ./www:/var/www/html
      - ./logs/nginx:/var/log/nginx
    depends_on:
      - php
    restart: always
    networks:
      - ldnmp-net

  php:
    image: php:7.4-fpm
    container_name: ldnmp-php
    volumes:
      - ./www:/var/www/html
      - ./php/conf:/usr/local/etc/php
      - ./logs/php:/var/log/php
    depends_on:
      - mysql
    restart: always
    networks:
      - ldnmp-net

  mysql:
    image: mysql:5.7
    container_name: ldnmp-mysql
    ports:
      - "3306:3306"
    volumes:
      - ./mysql/data:/var/lib/mysql
      - ./mysql/conf:/etc/mysql/conf.d
      - ./logs/mysql:/var/log/mysql
    environment:
      - MYSQL_ROOT_PASSWORD=ldnmp123456
      - MYSQL_DATABASE=ldnmp_db
    restart: always
    networks:
      - ldnmp-net

networks:
  ldnmp-net:
    driver: bridge
EOF

    # 创建默认Nginx配置
    mkdir -p ./nginx/conf
    cat > ./nginx/conf/default.conf << 'EOF'
server {
    listen 80;
    server_name localhost;
    root /var/www/html;
    index index.php index.html index.htm;

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass php:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
}
EOF

    # 创建默认首页
    mkdir -p ./www
    cat > ./www/index.php << 'EOF'
<?php
phpinfo();
?>
EOF

    # 启动LDNMP
    sudo docker-compose up -d
    echo -e "${gl_lv}LDNMP环境部署完成！${gl_bai}"
    echo "MySQL  root 密码: ldnmp123456"
    echo "网站根目录: /opt/ldnmp/www"
    echo "Nginx配置: /opt/ldnmp/nginx/conf"
    echo "访问测试: http://$(curl -s ipinfo.io/ip)"
    send_stats "安装LDNMP环境"
}

# LDNMP 管理菜单
ldnmp_menu() {
    while true; do
        clear
        echo -e "${gl_XLtool}====== LDNMP 环境管理 ======${gl_bai}"
        send_stats "进入LDNMP环境管理"
        local ldnmp_status="未安装"
        if [ -f "/opt/ldnmp/docker-compose.yml" ]; then
            ldnmp_status="已安装（运行中容器: $(sudo docker ps --filter "name=ldnmp-" --format "{{.Names}}" | wc -l) 个）"
        fi
        echo -e "${gl_huang}当前状态: $ldnmp_status${gl_bai}"
        echo -e "\n${gl_XLtool}操作选项${gl_bai}"
        echo -e "${gl_XLtool}------------------------${gl_bai}"
        echo "1. 安装 LDNMP 环境（Nginx+PHP7.4+MySQL5.7）"
        echo "2. 启动 LDNMP 服务"
        echo "3. 停止 LDNMP 服务"
        echo "4. 重启 LDNMP 服务"
        echo -e "${gl_XLtool}------------------------${gl_bai}"
        echo "5. 查看 LDNMP 日志"
        echo "6. 进入容器（Nginx/PHP/MySQL）"
        echo "7. 卸载 LDNMP 环境（保留数据）"
        echo "8. 彻底删除 LDNMP（含数据）"
        echo -e "${gl_XLtool}------------------------${gl_bai}"
        echo "0. 返回上一级选单"
        echo -e "${gl_XLtool}------------------------${gl_bai}"
        
        read -e -p "请输入你的选择: " sub_choice
        case $sub_choice in
            1)
                if [ -f "/opt/ldnmp/docker-compose.yml" ]; then
                    echo -e "${gl_hong}LDNMP已安装，无需重复安装${gl_bai}"
                else
                    install_ldnmp
                fi
                ;;
            2)
                if [ -f "/opt/ldnmp/docker-compose.yml" ]; then
                    cd /opt/ldnmp && sudo docker-compose start
                    echo -e "${gl_lv}LDNMP服务已启动${gl_bai}"
                    send_stats "启动LDNMP服务"
                else
                    echo -e "${gl_hong}未安装LDNMP，请先安装（选择1）${gl_bai}"
                fi
                ;;
            3)
                if [ -f "/opt/ldnmp/docker-compose.yml" ]; then
                    cd /opt/ldnmp && sudo docker-compose stop
                    echo -e "${gl_lv}LDNMP服务已停止${gl_bai}"
                    send_stats "停止LDNMP服务"
                else
                    echo -e "${gl_hong}未安装LDNMP，请先安装（选择1）${gl_bai}"
                fi
                ;;
            4)
                if [ -f "/opt/ldnmp/docker-compose.yml" ]; then
                    cd /opt/ldnmp && sudo docker-compose restart
                    echo -e "${gl_lv}LDNMP服务已重启${gl_bai}"
                    send_stats "重启LDNMP服务"
                else
                    echo -e "${gl_hong}未安装LDNMP，请先安装（选择1）${gl_bai}"
                fi
                ;;
            5)
                if [ -f "/opt/ldnmp/docker-compose.yml" ]; then
                    read -e -p "查看哪个服务的日志？(nginx/php/mysql): " log_service
                    case $log_service in
                        nginx|php|mysql)
                            read -e -p "显示行数(默认100): " lines
                            lines=${lines:-100}
                            cd /opt/ldnmp && sudo docker-compose logs --tail $lines $log_service
                            send_stats "查看LDNMP日志:$log_service"
                            ;;
                        *)
                            echo -e "${gl_hong}无效服务名，仅支持 nginx/php/mysql${gl_bai}"
                            ;;
                    esac
                else
                    echo -e "${gl_hong}未安装LDNMP，请先安装（选择1）${gl_bai}"
                fi
                ;;
            6)
                if [ -f "/opt/ldnmp/docker-compose.yml" ]; then
                    read -e -p "进入哪个容器？(nginx/php/mysql): " container
                    case $container in
                        nginx)
                            sudo docker exec -it ldnmp-nginx /bin/bash
                            send_stats "进入LDNMP容器:nginx"
                            ;;
                        php)
                            sudo docker exec -it ldnmp-php /bin/bash
                            send_stats "进入LDNMP容器:php"
                            ;;
                        mysql)
                            sudo docker exec -it ldnmp-mysql /bin/bash
                            send_stats "进入LDNMP容器:mysql"
                            ;;
                        *)
                            echo -e "${gl_hong}无效容器名，仅支持 nginx/php/mysql${gl_bai}"
                            ;;
                    esac
                else
                    echo -e "${gl_hong}未安装LDNMP，请先安装（选择1）${gl_bai}"
                fi
                ;;
            7)
                if [ -f "/opt/ldnmp/docker-compose.yml" ]; then
                    read -e -p "$(echo -e "${gl_hong}警告: ${gl_bai}确定卸载LDNMP环境？数据将保留！(Y/N): ")" confirm
                    if [ "$confirm" = "Y" ] || [ "$confirm" = "y" ]; then
                        cd /opt/ldnmp && sudo docker-compose down
                        rm -rf /opt/ldnmp/docker-compose.yml /opt/ldnmp/nginx/conf /opt/ldnmp/php/conf
                        echo -e "${gl_lv}LDNMP环境已卸载（数据已保留）${gl_bai}"
                        send_stats "卸载LDNMP环境（保留数据）"
                    else
                        echo -e "${gl_huang}已取消卸载操作${gl_bai}"
                    fi
                else
                    echo -e "${gl_hong}未安装LDNMP，请先安装（选择1）${gl_bai}"
                fi
                ;;
            8)
                if [ -f "/opt/ldnmp/docker-compose.yml" ]; then
                    read -e -p "$(echo -e "${gl_hong}警告: ${gl_bai}确定彻底删除LDNMP？所有数据将丢失！(Y/N): ")" confirm
                    if [ "$confirm" = "Y" ] || [ "$confirm" = "y" ]; then
                        cd /opt/ldnmp && sudo docker-compose down
                        rm -rf /opt/ldnmp
                        echo -e "${gl_lv}LDNMP已彻底删除（含所有数据）${gl_bai}"
                        send_stats "彻底删除LDNMP"
                    else
                        echo -e "${gl_huang}已取消删除操作${gl_bai}"
                    fi
                else
                    echo -e "${gl_hong}未安装LDNMP，请先安装（选择1）${gl_bai}"
                fi
                ;;
            0)
                break
                ;;
            *)
                echo -e "${gl_hong}❌ 无效选择，请重新输入${gl_bai}"
                ;;
        esac
        break_end
    done
}

# ============== SSL 证书管理 ==============
# 安装Certbot
install_certbot() {
    root_use
    install_dependency
    check_port  # 确保80/443端口空闲

    if command -v certbot &>/dev/null; then
        echo -e "${gl_huang}Certbot已安装，跳过安装步骤${gl_bai}"
        return
    fi

    echo -e "${gl_huang}正在安装Certbot...${gl_bai}"
    if command -v apt &>/dev/null; then
        apt update -y
        apt install -y certbot python3-certbot-nginx
    elif command -v yum &>/dev/null; then
        yum install -y certbot python3-certbot-nginx
    elif command -v dnf &>/dev/null; then
        dnf install -y certbot python3-certbot-nginx
    elif command -v apk &>/dev/null; then
        apk add certbot certbot-nginx
    else
        echo -e "${gl_huang}使用pip安装Certbot...${gl_bai}"
        install python3 python3-pip
        pip3 install certbot certbot-nginx
    fi
    echo -e "${gl_lv}Certbot安装完成${gl_bai}"
    send_stats "安装Certbot"
}

# 申请SSL证书（Let's Encrypt）
apply_ssl() {
    root_use
    install_certbot
    check_port  # 确保80端口可用（ACME验证需要）

    read -e -p "请输入域名（如 example.com）: " yuming
    if [ -z "$yuming" ]; then
        echo -e "${gl_hong}域名不能为空${gl_bai}"
        return 1
    fi

    # 检查域名解析
    local ip=$(curl -s ipinfo.io/ip)
    local dns_ip=$(dig +short $yuming | head -n 1)
    if [ "$dns_ip" != "$ip" ]; then
        echo -e "${gl_huang}警告：域名 $yuming 解析IP（$dns_ip）与服务器IP（$ip）不一致${gl_bai}"
        read -e -p "是否继续申请？(y/n): " confirm
        if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
            echo -e "${gl_huang}已取消申请${gl_bai}"
            return 1
        fi
    fi

    # 申请证书（支持单域名/泛域名）
    read -e -p "是否申请泛域名证书？(y/n，泛域名需要DNS验证): " wildcard
    if [ "$wildcard" = "y" ] || [ "$wildcard" = "Y" ]; then
        certbot certonly --manual --preferred-challenges dns -d "*.$yuming" -d $yuming
    else
        # 检查Nginx是否存在配置
        if [ -f "/etc/nginx/conf.d/$yuming.conf" ] || [ -f "/opt/ldnmp/nginx/conf/$yuming.conf" ]; then
            certbot --nginx -d $yuming
        else
            certbot certonly --standalone -d $yuming
        fi
    fi

    if [ -f "/etc/letsencrypt/live/$yuming/fullchain.pem" ]; then
        echo -e "${gl_lv}SSL证书申请成功！路径：/etc/letsencrypt/live/$yuming${gl_bai}"
        echo "证书自动续期已配置（系统定时任务）"
        send_stats "申请SSL证书:$yuming"
    else
        echo -e "${gl_hong}SSL证书申请失败${gl_bai}"
        send_stats "SSL证书申请失败:$yuming"
    fi
}

# 部署SSL到Nginx
deploy_ssl_nginx() {
    root_use
    read -e -p "请输入域名（如 example.com）: " yuming
    if [ ! -f "/etc/letsencrypt/live/$yuming/fullchain.pem" ]; then
        echo -e "${gl_hong}未找到 $yuming 的SSL证书，请先申请（选择1）${gl_bai}"
        return 1
    fi

    # 检测Nginx配置目录
    local nginx_conf_dir="/etc/nginx/conf.d"
    if [ -d "/opt/ldnmp/nginx/conf" ]; then
        nginx_conf_dir="/opt/ldnmp/nginx/conf"
    fi

    # 生成Nginx SSL配置
    cat > "$nginx_conf_dir/$yuming.conf" << EOF
server {
    listen 80;
    server_name $yuming;
    # 强制HTTPS
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name $yuming;

    ssl_certificate /etc/letsencrypt/live/$yuming/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$yuming/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;

    root /var/www/html/$yuming;
    index index.php index.html index.htm;

    access_log /var/log/nginx/$yuming-access.log;
    error_log /var/log/nginx/$yuming-error.log;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass php:9000;  # LDNMP环境使用
        # fastcgi_pass 127.0.0.1:9000;  # 非容器环境使用
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
}
EOF

    # 创建网站目录
    mkdir -p /var/www/html/$yuming
    echo "<h1>Welcome to $yuming</h1>" > /var/www/html/$yuming/index.html

    # 重启Nginx
    if [ -f "/opt/ldnmp/docker-compose.yml" ]; then
        cd /opt/ldnmp && sudo docker-compose restart nginx
    else
        restart nginx
    fi

    echo -e "${gl_lv}SSL已部署到Nginx，访问: https://$yuming${gl_bai}"
    send_stats "部署SSL到Nginx:$yuming"
}

# SSL证书管理菜单
ssl_menu() {
    while true; do
        clear
        echo -e "${gl_XLtool}====== SSL 证书管理 ======${gl_bai}"
        send_stats "进入SSL证书管理"
        echo -e "${gl_huang}已申请的证书（Let's Encrypt）:${gl_bai}"
        if [ -d "/etc/letsencrypt/live" ]; then
            ls -l /etc/letsencrypt/live | grep -v total | awk '{print $9}'
        else
            echo "无证书"
        fi
        echo -e "\n${gl_XLtool}操作选项${gl_bai}"
        echo -e "${gl_XLtool}------------------------${gl_bai}"
        echo "1. 申请新证书（Let's Encrypt，支持泛域名）"
        echo "2. 部署证书到Nginx（自动配置HTTPS）"
        echo "3. 手动续期所有证书"
        echo "4. 查看证书详情"
        echo "5. 吊销证书"
        echo -e "${gl_XLtool}------------------------${gl_bai}"
        echo "0. 返回上一级选单"
        echo -e "${gl_XLtool}------------------------${gl_bai}"
        
        read -e -p "请输入你的选择: " sub_choice
        case $sub_choice in
            1)
                apply_ssl
                ;;
            2)
                deploy_ssl_nginx
                ;;
            3)
                if command -v certbot &>/dev/null; then
                    certbot renew
                    echo -e "${gl_lv}证书续期操作完成${gl_bai}"
                    send_stats "SSL证书续期"
                else
                    echo -e "${gl_hong}请先安装Certbot（自动触发在申请时）${gl_bai}"
                fi
                ;;
            4)
                read -e -p "请输入域名: " yuming
                if [ -f "/etc/letsencrypt/live/$yuming/cert.pem" ]; then
                    openssl x509 -in /etc/letsencrypt/live/$yuming/cert.pem -noout -text
                    send_stats "查看SSL证书详情:$yuming"
                else
                    echo -e "${gl_hong}未找到 $yuming 的证书${gl_bai}"
                fi
                ;;
            5)
                read -e -p "请输入域名: " yuming
                if [ -f "/etc/letsencrypt/live/$yuming/cert.pem" ]; then
                    read -e -p "$(echo -e "${gl_hong}警告: ${gl_bai}确定吊销 $yuming 的证书吗？(Y/N): ")" confirm
                    if [ "$confirm" = "Y" ] || [ "$confirm" = "y" ]; then
                        certbot revoke --cert-path /etc/letsencrypt/live/$yuming/cert.pem
                        certbot delete --cert-name $yuming
                        echo -e "${gl_lv}$yuming 的证书已吊销并删除${gl_bai}"
                        send_stats "吊销SSL证书:$yuming"
                    else
                        echo -e "${gl_huang}已取消吊销操作${gl_bai}"
                    fi
                else
                    echo -e "${gl_hong}未找到 $yuming 的证书${gl_bai}"
                fi
                ;;
            0)
                break
                ;;
            *)
                echo -e "${gl_hong}❌ 无效选择，请重新输入${gl_bai}"
                ;;
        esac
        break_end
    done
}

# ============== 站点管理模块 ==============
# 创建站点（基于Nginx/LDNMP环境）
create_site() {
    root_use  # 权限检查（预设函数）
    # 1. 获取用户输入（域名、网站根目录）
    read -e -p "请输入站点域名（如 example.com）: " yuming
    read -e -p "请输入网站根目录（默认 /var/www/html/$yuming）: " webroot
    webroot=${webroot:-"/var/www/html/$yuming"}  # 默认值处理

    # 2. 创建根目录并初始化首页
    mkdir -p "$webroot"
    chmod -R 755 "$webroot"
    echo "<h1>Site $yuming created successfully</h1>" > "$webroot/index.html"

    # 3. 检测Nginx配置目录（适配原生Nginx/LDNMP）
    local nginx_conf_dir="/etc/nginx/conf.d"
    if [ -d "/opt/ldnmp/nginx/conf" ]; then
        nginx_conf_dir="/opt/ldnmp/nginx/conf"
    fi

    # 4. 生成Nginx基础配置文件
    cat > "$nginx_conf_dir/$yuming.conf" << EOF
server {
    listen 80;
    server_name $yuming;
    root $webroot;
    index index.php index.html index.htm;

    # 日志配置
    access_log /var/log/nginx/$yuming-access.log;
    error_log /var/log/nginx/$yuming-error.log;

    # 静态资源处理
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    # PHP解析配置（适配LDNMP容器/原生环境）
    location ~ \.php$ {
        fastcgi_pass php:9000;        # LDNMP容器环境
        # fastcgi_pass 127.0.0.1:9000; # 原生非容器环境（按需注释切换）
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
}
EOF

    # 5. 重启Nginx服务
    if [ -f "/opt/ldnmp/docker-compose.yml" ]; then
        # LDNMP环境（docker-compose重启）
        cd /opt/ldnmp && sudo docker-compose restart nginx
    else
        # 原生环境（系统服务重启）
        if command -v systemctl &>/dev/null; then
            systemctl restart nginx
        else
            service nginx restart
        fi
    fi

    # 6. 输出结果与统计
    echo -e "${gl_lv}站点 $yuming 创建完成！${gl_bai}"
    echo "网站根目录: $webroot"
    echo "配置文件: $nginx_conf_dir/$yuming.conf"
    echo "访问地址: http://$yuming"
    send_stats "创建站点:$yuming"  # 操作统计（预设函数）
}

# 站点管理主菜单
site_menu() {
    while true; do
        clear
        echo -e "${gl_XLtool}====== 站点管理 ======${gl_bai}"
        send_stats "进入站点管理"  # 操作统计

        # 检测Nginx配置目录
        local nginx_conf_dir="/etc/nginx/conf.d"
        if [ -d "/opt/ldnmp/nginx/conf" ]; then
            nginx_conf_dir="/opt/ldnmp/nginx/conf"
        fi

        # 显示当前站点列表
        echo -e "${gl_huang}当前站点列表:${gl_bai}"
        if [ -d "$nginx_conf_dir" ]; then
            # 过滤默认配置，仅显示自定义站点
            ls -l "$nginx_conf_dir" | grep -v "default" | grep ".conf" | awk -F '/' '{print $NF}' | sed 's/.conf//g'
        else
            echo "未检测到Nginx配置目录"
        fi

        # 显示操作选项
        echo -e "\n${gl_XLtool}操作选项${gl_bai}"
        echo -e "${gl_XLtool}------------------------${gl_bai}"
        echo "1. 创建新站点（自动生成Nginx配置）"
        echo "2. 启用HTTPS（自动部署SSL证书）"
        echo "3. 编辑站点配置"
        echo "4. 删除站点"
        echo -e "${gl_XLtool}------------------------${gl_bai}"
        echo "5. 查看站点访问日志"
        echo "6. 清空站点日志"
        echo "7. 设置反向代理"
        echo -e "${gl_XLtool}------------------------${gl_bai}"
        echo "0. 返回上一级菜单"
        echo -e "${gl_XLtool}------------------------${gl_bai}"

        # 处理用户选择
        read -e -p "请输入你的选择: " sub_choice
        case $sub_choice in
            1)
                create_site  # 调用创建站点函数
                ;;
            2)
                # 启用HTTPS（依赖预设的deploy_ssl_nginx函数）
                read -e -p "请输入要启用HTTPS的域名: " yuming
                if [ -f "$nginx_conf_dir/$yuming.conf" ]; then
                    deploy_ssl_nginx  # 部署SSL证书（预设函数）
                else
                    echo -e "${gl_hong}未找到 $yuming 的站点配置，请先创建站点（选择1）${gl_bai}"
                fi
                ;;
            3)
                # 编辑站点配置
                read -e -p "请输入要编辑的域名: " yuming
                if [ -f "$nginx_conf_dir/$yuming.conf" ]; then
                    nano "$nginx_conf_dir/$yuming.conf"  # 使用nano编辑（可替换为vim）
                    # 重启Nginx生效
                    if [ -f "/opt/ldnmp/docker-compose.yml" ]; then
                        cd /opt/ldnmp && sudo docker-compose restart nginx
                    else
                        if command -v systemctl &>/dev/null; then
                            systemctl restart nginx
                        else
                            service nginx restart
                        fi
                    fi
                    echo -e "${gl_lv}$yuming 配置已更新${gl_bai}"
                    send_stats "编辑站点配置:$yuming"
                else
                    echo -e "${gl_hong}未找到 $yuming 的站点配置${gl_bai}"
                fi
                ;;
            4)
                # 删除站点
                read -e -p "请输入要删除的域名: " yuming
                if [ -f "$nginx_conf_dir/$yuming.conf" ]; then
                    # 二次确认（防止误删）
                    read -e -p "$(echo -e "${gl_hong}警告: ${gl_bai}确定删除 $yuming 站点吗？(Y/N): ")" confirm
                    if [ "$confirm" = "Y" ] || [ "$confirm" = "y" ]; then
                        # 删除Nginx配置文件
                        rm -f "$nginx_conf_dir/$yuming.conf"
                        # 可选删除网站根目录
                        local webroot="/var/www/html/$yuming"
                        if [ -d "$webroot" ]; then
                            read -e -p "是否同时删除网站文件（$webroot）？(Y/N): " del_files
                            if [ "$del_files" = "Y" ] || [ "$del_files" = "y" ]; then
                                rm -rf "$webroot"
                                echo -e "${gl_lv}网站文件已删除${gl_bai}"
                            fi
                        fi
                        # 重启Nginx生效
                        if [ -f "/opt/ldnmp/docker-compose.yml" ]; then
                            cd /opt/ldnmp && sudo docker-compose restart nginx
                        else
                            if command -v systemctl &>/dev/null; then
                                systemctl restart nginx
                            else
                                service nginx restart
                            fi
                        fi
                        echo -e "${gl_lv}$yuming 站点已删除${gl_bai}"
                        send_stats "删除站点:$yuming"
                    else
                        echo -e "${gl_huang}已取消删除操作${gl_bai}"
                    fi
                else
                    echo -e "${gl_hong}未找到 $yuming 的站点配置${gl_bai}"
                fi
                ;;
            5)
                # 查看站点访问日志
                read -e -p "请输入要查看日志的域名: " yuming
                local log_file="/var/log/nginx/$yuming-access.log"
                if [ -f "$log_file" ]; then
                    read -e -p "显示行数(默认100): " lines
                    lines=${lines:-100}  # 默认显示100行
                    tail -n "$lines" "$log_file"
                    send_stats "查看站点日志:$yuming"
                else
                    echo -e "${gl_hong}未找到 $yuming 的日志文件${gl_bai}"
                fi
                ;;
            6)
                # 清空站点日志
                read -e -p "请输入要清空日志的域名: " yuming
                local access_log="/var/log/nginx/$yuming-access.log"
                local error_log="/var/log/nginx/$yuming-error.log"
                if [ -f "$access_log" ] || [ -f "$error_log" ]; then
                    # 清空日志（保留文件句柄，避免服务异常）
                    truncate -s 0 "$access_log" "$error_log"
                    echo -e "${gl_lv}$yuming 的日志已清空${gl_bai}"
                    send_stats "清空站点日志:$yuming"
                else
                    echo -e "${gl_hong}未找到 $yuming 的日志文件${gl_bai}"
                fi
                ;;
            7)
                # 设置反向代理
                read -e -p "请输入代理域名: " yuming
                read -e -p "请输入目标地址（如 http://127.0.0.1:8080）: " target
                # 检查配置文件是否存在（存在则询问覆盖）
                if [ -f "$nginx_conf_dir/$yuming.conf" ]; then
                    read -e -p "是否覆盖现有配置？(Y/N): " overwrite
                    if [ "$overwrite" != "Y" ] && [ "$overwrite" != "y" ]; then
                        echo -e "${gl_huang}已取消操作${gl_bai}"
                        continue
                    fi
                fi
                # 生成反向代理配置
                cat > "$nginx_conf_dir/$yuming.conf" << EOF
server {
    listen 80;
    server_name $yuming;

    location / {
        proxy_pass $target;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
                # 重启Nginx生效
                if [ -f "/opt/ldnmp/docker-compose.yml" ]; then
                    cd /opt/ldnmp && sudo docker-compose restart nginx
                else
                    if command -v systemctl &>/dev/null; then
                        systemctl restart nginx
                    else
                        service nginx restart
                    fi
                fi
                echo -e "${gl_lv}反向代理已设置：$yuming -> $target${gl_bai}"
                send_stats "设置反向代理:$yuming->$target"
                ;;
            0)
                # 返回上一级菜单
                break
                ;;
            *)
                # 无效选择提示
                echo -e "${gl_hong}❌ 无效选择，请重新输入${gl_bai}"
                ;;
        esac
        break_end  # 暂停查看结果（预设函数，如 read -p "按回车继续..."）
    done
}


# ============== 服务器监控模块 ==============
# 安装系统监控工具（htop/iftop/iotop等）
install_monitor() {
    root_use  # 权限检查
    install_dependency  # 安装依赖（预设函数）
    check_disk_space 10  # 检查磁盘空间（至少10MB，预设函数）

    # 检查工具是否已安装
    if command -v goaccess &>/dev/null && command -v htop &>/dev/null; then
        echo -e "${gl_huang}监控工具已安装，跳过安装步骤${gl_bai}"
        return
    fi

    # 安装工具（适配不同包管理器）
    echo -e "${gl_huang}正在安装监控工具...${gl_bai}"
    if command -v apt &>/dev/null; then
        apt install -y htop iftop iotop nload goaccess net-tools
    elif command -v yum &>/dev/null; then
        yum install -y htop iftop iotop nload goaccess net-tools
    elif command -v dnf &>/dev/null; then
        dnf install -y htop iftop iotop nload goaccess net-tools
    elif command -v apk &>/dev/null; then
        apk add htop iftop iotop nload goaccess net-tools
    else
        echo -e "${gl_hong}不支持的包管理器，无法安装监控工具${gl_bai}"
        return
    fi

    echo -e "${gl_lv}监控工具安装完成${gl_bai}"
    send_stats "安装系统监控工具"
}

# 实时系统监控（CPU/内存/网络等）
realtime_monitor() {
    install_monitor  # 确保工具已安装
    while true; do
        clear
        echo -e "${gl_XLtool}====== 实时系统监控 ======${gl_bai}"
        send_stats "进入实时系统监控"

        # 显示监控选项
        echo "1. CPU / 内存 / 进程监控（htop）"
        echo "2. 网络流量监控（iftop）"
        echo "3. 磁盘 IO 监控（iotop）"
        echo "4. 带宽监控（nload）"
        echo "5. Web 访问日志分析（goaccess）"
        echo -e "${gl_XLtool}------------------------${gl_bai}"
        echo "0. 返回上一级菜单"
        echo -e "${gl_XLtool}------------------------${gl_bai}"

        # 处理用户选择
        read -e -p "请输入你的选择: " sub_choice
        case $sub_choice in
            1)
                htop  # CPU/内存监控
                send_stats "使用 htop 监控"
                ;;
            2)
                iftop  # 网络流量监控
                send_stats "使用 iftop 监控"
                ;;
            3)
                iotop  # 磁盘IO监控
                send_stats "使用 iotop 监控"
                ;;
            4)
                nload  # 带宽监控
                send_stats "使用 nload 监控"
                ;;
            5)
                # Web日志分析（适配原生/LDNMP环境）
                local log_file="/var/log/nginx/access.log"
                if [ -f "/opt/ldnmp/logs/nginx/access.log" ]; then
                    log_file="/opt/ldnmp/logs/nginx/access.log"
                fi
                if [ -f "$log_file" ]; then
                    goaccess "$log_file"  # 交互式日志分析
                    send_stats "使用 goaccess 分析日志"
                else
                    echo -e "${gl_hong}未找到Nginx访问日志，请先安装Nginx或LDNMP${gl_bai}"
                fi
                ;;
            0)
                break  # 返回上一级
                ;;
            *)
                echo -e "${gl_hong}❌ 无效选择，请重新输入${gl_bai}"
                ;;
        esac
        break_end  # 暂停查看结果
    done
}

# 查看服务器详细信息
server_info() {
    clear
    echo -e "${gl_XLtool}====== 服务器信息 ======${gl_bai}"
    send_stats "查看服务器信息"

    # 1. 系统基础信息
    echo -e "${gl_huang}系统信息:${gl_bai}"
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "  发行版: $PRETTY_NAME"
    fi
    echo "  内核版本: $(uname -r)"
    echo "  架构: $(uname -m)"
    echo "  主机名: $(hostname)"
    echo "  当前时间: $(date)"

    # 2. 网络信息（公网/内网IP）
    echo -e "\n${gl_huang}网络信息:${gl_bai}"
    echo "  公网 IPv4: $(curl -s --max-time 2 ipinfo.io/ip || echo "获取失败")"
    echo "  公网 IPv6: $(curl -s --max-time 2 https://v6.ipinfo.io/ip || echo "未配置/获取失败")"
    echo "  内网 IP: $(hostname -I | awk '{print $1}' || echo "未配置")"

    # 3. 硬件信息（CPU/内存）
    echo -e "\n${gl_huang}硬件信息:${gl_bai}"
    local cpu_core=$(grep -c ^processor /proc/cpuinfo)
    local cpu_model=$(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | sed -e 's/^ *//')
    echo "  CPU: $cpu_core 核心 $cpu_model"
    echo "  内存：总 $(free -h | awk '/Mem:/ {print $2}')，已用 $(free -h | awk '/Mem:/ {print $3}')，空闲 $(free -h | awk '/Mem:/ {print $4}')"
    echo "  Swap: 总 $(free -h | awk '/Swap:/ {print $2}')，已用 $(free -h | awk '/Swap:/ {print $3}')，空闲 $(free -h | awk '/Swap:/ {print $4}')"

    # 4. 磁盘信息
    echo -e "\n${gl_huang}磁盘信息:${gl_bai}"
    df -h | grep -v tmpfs | grep -v loop  # 过滤临时文件系统

    # 5. 系统负载
    echo -e "\n${gl_huang}系统负载:${gl_bai}"
    uptime  # 显示1/5/15分钟负载

    # 6. 关键服务状态
    echo -e "\n${gl_huang}关键服务状态:${gl_bai}"
    for service in docker nginx mysql sshd; do
        if command -v systemctl &>/dev/null; then
            status=$(systemctl is-active "$service" 2>/dev/null || echo "未安装")
        elif command -v service &>/dev/null; then
            status=$(service "$service" status 2>/dev/null | grep -q "running" && echo "运行中" || echo "未运行/未安装")
        else
            status="未知"
        fi
        echo "  $service: $status"
    done

    break_end  # 暂停查看结果
}

# 监控与信息主菜单
monitor_menu() {
    while true; do
        clear
        echo -e "${gl_XLtool}====== 服务器监控与信息 ======${gl_bai}"
        send_stats "进入服务器监控与信息"

        # 显示操作选项
        echo "1. 查看服务器详细信息"
        echo "2. 实时系统监控（CPU / 内存 / 网络等）"
        echo "3. 安装 / 更新监控工具"
        echo "4. 查看系统负载历史（最近24小时）"
        echo -e "${gl_XLtool}------------------------${gl_bai}"
        echo "0. 返回主菜单"
        echo -e "${gl_XLtool}------------------------${gl_bai}"

        # 处理用户选择
        read -e -p "请输入你的选择: " choice
        case $choice in
            1)
                server_info  # 查看服务器信息
                ;;
            2)
                realtime_monitor  # 实时监控
                ;;
            3)
                install_monitor  # 安装监控工具
                ;;
            4)
                # 查看系统负载历史（sar工具）
                if command -v sar &>/dev/null; then
                    sar -A | less  # 显示所有历史数据（分页）
                else
                    echo -e "${gl_huang}正在安装 sysstat（包含sar工具）...${gl_bai}"
                    if command -v apt &>/dev/null; then
                        apt install -y sysstat
                    elif command -v yum &>/dev/null; then
                        yum install -y sysstat
                    elif command -v dnf &>/dev/null; then
                        dnf install -y sysstat
                    fi
                    echo -e "${gl_lv}安装完成，请24小时后查看历史数据${gl_bai}"
                fi
                send_stats "查看系统负载历史"
                ;;
            0)
                break  # 返回主菜单
                ;;
            *)
                echo -e "${gl_hong}❌ 无效选择，请重新输入${gl_bai}"
                ;;
        esac
        break_end  # 暂停查看结果
    done
}


# ============== Fail2ban防暴力破解模块 ==============
# 安装Fail2ban
install_fail2ban() {
    root_use  # 权限检查
    install_dependency  # 安装依赖

    # 检查是否已安装
    if command -v fail2ban-client &>/dev/null; then
        echo -e "${gl_huang}Fail2ban已安装，跳过安装步骤${gl_bai}"
        return
    fi

    # 安装Fail2ban（适配不同包管理器）
    echo -e "${gl_huang}正在安装Fail2ban...${gl_bai}"
    if command -v apt &>/dev/null; then
        apt install -y fail2ban
    elif command -v yum &>/dev/null; then
        yum install -y fail2ban
    elif command -v dnf &>/dev/null; then
        dnf install -y fail2ban
    elif command -v apk &>/dev/null; then
        apk add fail2ban
    else
        echo -e "${gl_hong}不支持的包管理器，无法安装Fail2ban${gl_bai}"
        return
    fi

    # 启动并设置开机自启
    if command -v systemctl &>/dev/null; then
        systemctl enable --now fail2ban
    else
        service fail2ban start
        chkconfig fail2ban on
    fi

    echo -e "${gl_lv}Fail2ban安装完成${gl_bai}"
    send_stats "安装 Fail2ban"
}

# 配置Fail2ban规则（SSH+Nginx防护）
configure_fail2ban() {
    root_use  # 权限检查
    install_fail2ban  # 确保已安装

    # 生成自定义规则配置（覆盖默认配置）
    cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
ignoreip = 127.0.0.1/8          # 忽略本地IP
bantime = 86400                 # 封禁时长（秒）：24小时
findtime = 3600                 # 检测时长（秒）：1小时
maxretry = 5                    # 最大失败次数：5次

# SSH防暴力破解
[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s

# Nginx HTTP认证防护
[nginx-http-auth]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log
EOF

    # 适配LDNMP环境（日志路径修正）
    if [ -d "/opt/ldnmp/logs/nginx" ]; then
        sed -i "s|/var/log/nginx/error.log|/opt/ldnmp/logs/nginx/error.log|g" /etc/fail2ban/jail.local
    fi

    # 重启Fail2ban生效
    if command -v systemctl &>/dev/null; then
        systemctl restart fail2ban
    else
        service fail2ban restart
    fi

    echo -e "${gl_lv}Fail2ban规则配置完成${gl_bai}"
    send_stats "配置 Fail2ban 规则"
}

# Fail2ban管理主菜单
fail2ban_menu() {
    while true; do
        clear
        echo -e "${gl_XLtool}====== Fail2ban 防暴力破解 ======${gl_bai}"
        send_stats "进入 Fail2ban 管理"

        # 显示当前Fail2ban状态
        local status="未安装"
        if command -v fail2ban-client &>/dev/null; then
            local jail_count=$(fail2ban-client status | grep "Number of jail" | awk '{print $4}')
            status="已安装（运行中: $jail_count 个规则）"
        fi
        echo -e "${gl_huang}当前状态: $status${gl_bai}"

        # 显示已启用的规则（若已安装）
        if command -v fail2ban-client &>/dev/null; then
            echo -e "\n${gl_huang}已启用的规则:${gl_bai}"
            fail2ban-client status | grep "Jail list" | awk -F': ' '{print $2}'
        fi

        # 显示操作选项
        echo -e "\n${gl_XLtool}操作选项${gl_bai}"
        echo -e "${gl_XLtool}------------------------${gl_bai}"
        echo "1. 安装 Fail2ban"
        echo "2. 配置默认规则（SSH+Nginx）"
        echo "3. 查看被封禁的IP"
        echo "4. 解封指定IP"
        echo -e "${gl_XLtool}------------------------${gl_bai}"
        echo "5. 启动 Fail2ban 服务"
        echo "6. 停止 Fail2ban 服务"
        echo "7. 重启 Fail2ban 服务"
        echo -e "${gl_XLtool}------------------------${gl_bai}"
        echo "0. 返回上一级菜单"
        echo -e "${gl_XLtool}------------------------${gl_bai}"

        # 处理用户选择
        read -e -p "请输入你的选择: " sub_choice
        case $sub_choice in
            1)
                install_fail2ban  # 安装Fail2ban
                ;;
            2)
                configure_fail2ban  # 配置规则
                ;;
            3)
                # 查看被封禁IP
                if command -v fail2ban-client &>/dev/null; then
                    read -e -p "请输入规则名称（如 sshd，留空查看所有）: " jail_name
                    if [ -z "$jail_name" ]; then
                        # 查看所有规则的封禁IP
                        local jails=$(fail2ban-client status | grep "Jail list" | awk -F': ' '{print $2}')
                        for jail in $jails; do
                            echo -e "\n${gl_huang}规则 $jail 封禁的IP:${gl_bai}"
                            fail2ban-client status "$jail" | grep "IP list" | awk -F': ' '{print $2}'
                        done
                    else
                        # 查看指定规则的封禁IP
                        echo -e "\n${gl_huang}规则 $jail_name 封禁的IP:${gl_bai}"
                        fail2ban-client status "$jail_name" | grep "IP list" | awk -F': ' '{print $2}'
                    fi
                    send_stats "查看Fail2ban封禁IP"
                else
                    echo -e "${gl_hong}请先安装 Fail2ban（选择1）${gl_bai}"
                fi
                ;;
            4)
                # 解封指定IP
                if command -v fail2ban-client &>/dev/null; then
                    read -e -p "请输入要解封的IP: " unban_ip
                    read -e -p "请输入规则名称（如 sshd，留空表示所有规则）: " jail_name
                    if [ -z "$jail_name" ]; then
                        fail2ban-client unban "$unban_ip"  # 所有规则解封
                    else
                        fail2ban-client set "$jail_name" unbanip "$unban_ip"  # 指定规则解封
                    fi
                    echo -e "${gl_lv}IP $unban_ip 已解封${gl_bai}"
                    send_stats "解封 IP:$unban_ip"
                else
                    echo -e "${gl_hong}请先安装 Fail2ban（选择1）${gl_bai}"
                fi
                ;;
            5)
                # 启动服务
                if command -v fail2ban-client &>/dev/null; then
                    if command -v systemctl &>/dev/null; then
                        systemctl start fail2ban
                    else
                        service fail2ban start
                    fi
                    echo -e "${gl_lv}Fail2ban服务已启动${gl_bai}"
                else
                    echo -e "${gl_hong}请先安装 Fail2ban（选择1）${gl_bai}"
                fi
                ;;
            6)
                # 停止服务
                if command -v fail2ban-client &>/dev/null; then
                    if command -v systemctl &>/dev/null; then
                        systemctl stop fail2ban
                    else
                        service fail2ban stop
                    fi
                    echo -e "${gl_lv}Fail2ban服务已停止${gl_bai}"
                else
                    echo -e "${gl_hong}请先安装 Fail2ban（选择1）${gl_bai}"
                fi
                ;;
            7)
                # 重启服务
                if command -v fail2ban-client &>/dev/null; then
                    if command -v systemctl &>/dev/null; then
                        systemctl restart fail2ban
                    else
                        service fail2ban restart
                    fi
                    echo -e "${gl_lv}Fail2ban服务已重启${gl_bai}"
                else
                    echo -e "${gl_hong}请先安装 Fail2ban（选择1）${gl_bai}"
                fi
                ;;
            0)
                break  # 返回上一级
                ;;
            *)
                echo -e "${gl_hong}❌ 无效选择，请重新输入${gl_bai}"
                ;;
        esac
        break_end  # 暂停查看结果
    done
}


# ============== 系统工具模块 ==============
# 系统更新与升级
system_update() {
    root_use  # 权限检查
    echo -e "${gl_huang}正在更新系统...${gl_bai}"

    # 适配不同包管理器
    if command -v apt &>/dev/null; then
        apt update -y
        apt upgrade -y
        apt autoremove -y
        apt autoclean
    elif command -v yum &>/dev/null; then
        yum update -y
        yum upgrade -y
        yum autoremove -y
    elif command -v dnf &>/dev/null; then
        dnf update -y
        dnf upgrade -y
        dnf autoremove -y
    elif command -v apk &>/dev/null; then
        apk update
        apk upgrade
        apk cache clean
    elif command -v pacman &>/dev/null; then
        pacman -Syu --noconfirm
    elif command -v zypper &>/dev/null; then
        zypper refresh
        zypper update -y
    else
        echo -e "${gl_hong}不支持的包管理器，无法更新系统${gl_bai}"
        return 1
    fi

    echo -e "${gl_lv}系统更新完成${gl_bai}"
    send_stats "系统更新"
}

# 更换国内软件源（阿里云镜像，加速下载）
change_mirror() {
    root_use  # 权限检查
    # 检测IP归属地（非国内IP需二次确认）
    local country=$(curl -s --max-time 2 ipinfo.io/country 2>/dev/null)
    if [ "$country" != "CN" ] && [ -n "$country" ]; then
        read -e -p "$(echo -e "${gl_huang}检测到非国内IP，确定更换为国内源吗？(Y/N): ${gl_bai}")" confirm
        if [ "$confirm" != "Y" ] && [ "$confirm" != "y" ]; then
            echo -e "${gl_huang}已取消操作${gl_bai}"
            return 1
        fi
    fi

    # 识别操作系统（基于/etc/os-release）
    if [ ! -f /etc/os-release ]; then
        echo -e "${gl_hong}无法确定操作系统${gl_bai}"
        return 1
    fi
    . /etc/os-release

    case "$ID" in
        ubuntu|debian)
            # APT源（Ubuntu/Debian）
            cp /etc/apt/sources.list /etc/apt/sources.list.bak  # 备份原配置
            if [ "$ID" = "ubuntu" ]; then
                # Ubuntu阿里云源
                local codename=$(lsb_release -c | awk '{print $2}')
                cat > /etc/apt/sources.list << EOF
deb http://mirrors.aliyun.com/ubuntu/ $codename main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ $codename main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ $codename-security main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ $codename-security main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ $codename-updates main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ $codename-updates main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ $codename-backports main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ $codename-backports main restricted universe multiverse
EOF
            else
                # Debian阿里云源
                local codename=$(cat /etc/debian_version | cut -d '/' -f1)
                cat > /etc/apt/sources.list << EOF
deb http://mirrors.aliyun.com/debian/ $codename main non-free contrib
deb-src http://mirrors.aliyun.com/debian/ $codename main non-free contrib
deb http://mirrors.aliyun.com/debian-security/ $codename-security main
deb-src http://mirrors.aliyun.com/debian-security/ $codename-security main
deb http://mirrors.aliyun.com/debian/ $codename-updates main non-free contrib
deb-src http://mirrors.aliyun.com/debian/ $codename-updates main non-free contrib
EOF
            fi
            apt update -y  # 更新源缓存
            echo -e "${gl_lv}APT源已更换为阿里云镜像${gl_bai}"
            send_stats "更换 APT 源为阿里云"
            ;;
        centos|rhel|almalinux|rocky)
            # YUM源（CentOS/RHEL系列）
            mkdir -p /etc/yum.repos.d/bak  # 备份目录
            mv /etc/yum.repos.d/*.repo /etc/yum.repos.d/bak/  # 备份原配置
            if [ "$ID" = "centos" ]; then
                # CentOS阿里云源
                local version=$(cat /etc/centos-release | grep -oE '[0-9]+\.[0-9]+' | cut -d '.' -f1)
                curl -o /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-$version.repo
            else
                # RHEL系列阿里云源（EPEL）
                curl -o /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo
            fi
            yum clean all && yum makecache  # 清理缓存并生成新缓存
            echo -e "${gl_lv}YUM源已更换为阿里云镜像${gl_bai}"
            send_stats "更换 YUM 源为阿里云"
            ;;
        alpine)
            # APK源（Alpine）
            cp /etc/apk/repositories /etc/apk/repositories.bak  # 备份原配置
            cat > /etc/apk/repositories << EOF
https://mirrors.aliyun.com/alpine/v3.16/main/
https://mirrors.aliyun.com/alpine/v3.16/community/
EOF
            apk update  # 更新源缓存
            echo -e "${gl_lv}APK源已更换为阿里云镜像${gl_bai}"
            send_stats "更换 APK 源为阿里云"
            ;;
        *)
            echo -e "${gl_hong}不支持的发行版: $ID${gl_bai}"
            return 1
            ;;
    esac
}

# 系统工具主菜单
system_tools() {
    while true; do
        clear
        echo -e "${gl_XLtool}====== 系统工具 ======${gl_bai}"
        send_stats "进入系统工具"

        # 显示操作选项
        echo "1. 系统更新与升级"
        echo "2. 更换国内软件源（加速下载）"
        echo "3. 防火墙高级管理"
        echo "4. Swap 虚拟内存管理"
        echo -e "${gl_XLtool}------------------------${gl_bai}"
        echo "5. 清理系统垃圾"
        echo "6. 查看系统日志"
        echo "7. 设置时区（默认 Asia/Shanghai）"
        echo "8. 重启 / 关机"
        echo -e "${gl_XLtool}------------------------${gl_bai}"
        echo "0. 返回主菜单"
        echo -e "${gl_XLtool}------------------------${gl_bai}"

        # 处理用户选择
        read -e -p "请输入你的选择: " choice
        case $choice in
            1)
                system_update  # 系统更新
                ;;
            2)
                change_mirror  # 更换国内源
                ;;
            3)
                iptables_panel  # 防火墙管理（预设函数）
                ;;
            4)
                swap_manage_menu  # Swap管理（预设函数）
                ;;
            5)
                # 清理系统垃圾
                root_use
                echo -e "${gl_huang}正在清理系统垃圾...${gl_bai}"
                # 清理APT缓存
                if command -v apt &>/dev/null; then
                    apt autoremove -y
                    apt autoclean
                    rm -rf /var/cache/apt/archives/*
                fi
                # 清理YUM缓存
                if command -v yum &>/dev/null; then
                    yum clean all
                    rm -rf /var/cache/yum/*
                fi
                # 清理临时文件
                rm -rf /tmp/*
                rm -rf /var/tmp/*
                # 清理日志文件（截断而非删除）
                find /var/log -type f -name "*.log" -exec truncate -s 0 {} \;
                echo -e "${gl_lv}系统垃圾清理完成${gl_bai}"
                send_stats "清理系统垃圾"
                ;;
            6)
                # 查看系统日志
                echo "1. 系统日志（/var/log/syslog 或 /var/log/messages）"
                echo "2. 安全日志（/var/log/auth.log 或 /var/log/secure）"
                echo "3. 内核日志（/var/log/kern.log）"
                read -e -p "请选择查看的日志类型: " log_choice
                case $log_choice in
                    1)
                        local log_file="/var/log/syslog"
                        [ ! -f "$log_file" ] && log_file="/var/log/messages"  # 适配CentOS
                        ;;
                    2)
                        local log_file="/var/log/auth.log"
                        [ ! -f "$log_file" ] && log_file="/var/log/secure"  # 适配CentOS
                        ;;
                    3)
                        local log_file="/var/log/kern.log"
                        ;;
                    *)
                        echo -e "${gl_hong}无效选择${gl_bai}"
                        continue
                        ;;
                esac
                # 显示日志（支持自定义行数）
                if [ -f "$log_file" ]; then
                    read -e -p "显示行数(默认100): " lines
                    lines=${lines:-100}
                    tail -n "$lines" "$log_file"
                    send_stats "查看系统日志:$log_file"
                else
                    echo -e "${gl_hong}未找到日志文件: $log_file${gl_bai}"
                fi
                ;;
            7)
                # 设置时区（默认上海）
                root_use
                echo -e "${gl_huang}正在设置时区为 Asia/Shanghai...${gl_bai}"
                timedatectl set-timezone Asia/Shanghai
                echo -e "${gl_lv}时区设置完成，当前时间: $(date)${gl_bai}"
                send_stats "设置时区为Asia/Shanghai"
                ;;
            8)
                # 重启/关机
                echo "1. 重启系统"
                echo "2. 关闭系统"
                read -e -p "请选择操作: " power_choice
                case $power_choice in
                    1)
                        read -e -p "确定要重启系统吗？(Y/N): " confirm
                        if [ "$confirm" = "Y" ] || [ "$confirm" = "y" ]; then
                            send_stats "重启系统"
                            reboot
                        fi
                        ;;
                    2)
                        read -e -p "确定要关闭系统吗？(Y/N): " confirm
                        if [ "$confirm" = "Y" ] || [ "$confirm" = "y" ]; then
                            send_stats "关闭系统"
                            poweroff
                        fi
                        ;;
                    *)
                        echo -e "${gl_hong}无效选择${gl_bai}"
                        ;;
                esac
                ;;
            0)
                break  # 返回主菜单
                ;;
            *)
                echo -e "${gl_hong}❌ 无效选择，请重新输入${gl_bai}"
                ;;
        esac
        break_end  # 暂停查看结果
    done
}


# ============== 脚本主菜单 ==============
XLtool() {
    clear
    CheckFirstRun_false  # 检查许可协议（预设函数）
    local sh_v="1.0.0"  # 脚本版本（示例）
    local gh_proxy="https://ghproxy.com/"  # GitHub代理（加速更新）

    while true; do
        clear
        # 显示脚本头部信息
        echo -e "${gl_XLtool}########################################################${gl_bai}"
        echo -e "${gl_XLtool}#                                                      #${gl_bai}"
        echo -e "${gl_XLtool}#               XLtool 服务器管理工具箱 v$sh_v               #${gl_bai}"
        echo -e "${gl_XLtool}#                  https://blog.5881314.xyz             #${gl_bai}"
        echo -e "${gl_XLtool}#                                                      #${gl_bai}"
        echo -e "${gl_XLtool}########################################################${gl_bai}"

        # 显示主菜单选项
        echo -e "\n${gl_XLtool}【容器与环境管理】${gl_bai}"
        echo "1. Docker 管理中心（安装/容器/镜像/应用部署）"
        echo "2. LDNMP 环境管理（Nginx+PHP+MySQL）"
        echo -e "\n${gl_XLtool}【网站与安全】${gl_bai}"
        echo "3. 站点管理（创建/配置/反向代理）"
        echo "4. SSL 证书管理（申请/部署/续期）"
        echo "5. Fail2ban 防暴力破解"
        echo -e "\n${gl_XLtool}【系统与监控】${gl_bai}"
        echo "6. 服务器监控与信息"
        echo "7. 系统工具（更新/源/防火墙/Swap等）"
        echo -e "\n${gl_XLtool}【其他】${gl_bai}"
        echo "8. 脚本更新"
        echo "9. 隐私设置（关闭统计）"
        echo -e "\n${gl_XLtool}0. 退出脚本${gl_bai}"
        echo -e "\n${gl_XLtool}########################################################${gl_bai}"

        # 处理用户选择
        read -e -p "请输入你的选择 [0-9]: " choice
        case $choice in
            1)
                docker_menu  # Docker管理（预设函数）
                ;;
            2)
                ldnmp_menu  # LDNMP管理（预设函数）
                ;;
            3)
                site_menu  # 站点管理（当前模块）
                ;;
            4)
                ssl_menu  # SSL管理（预设函数）
                ;;
            5)
                fail2ban_menu  # Fail2ban管理（当前模块）
                ;;
            6)
                monitor_menu  # 服务器监控（当前模块）
                ;;
            7)
                system_tools  # 系统工具（当前模块）
                ;;
            8)
                # 脚本更新（从GitHub拉取最新版本）
                echo -e "${gl_huang}正在检查更新...${gl_bai}"
                local update_url="https://raw.githubusercontent.com/kejilion/XLtool/main/XLtool.sh"
                local proxy_url="$gh_proxy$update_url"
                # 尝试直接下载/代理下载
                curl -sSL --connect-timeout 10 "$update_url" -o /tmp/XLtool_new.sh
                if [ $? -ne 0 ]; then
                    echo -e "${gl_hong}更新失败，尝试使用代理...${gl_bai}"
                    curl -sSL --connect-timeout 10 "$proxy_url" -o /tmp/XLtool_new.sh
                fi
                # 检查更新文件是否存在
                if [ -f "/tmp/XLtool_new.sh" ]; then
                    chmod +x /tmp/XLtool_new.sh
                    # 对比版本（假设新版本通过grep提取）
                    local new_version=$(grep 'sh_v="' /tmp/XLtool_new.sh | cut -d'"' -f2)
                    if [ "$new_version" != "$sh_v" ]; then
                        read -e -p "发现新版本 v$new_version，是否更新？(Y/N): " confirm
                        if [ "$confirm" = "Y" ] || [ "$confirm" = "y" ]; then
                            # 覆盖旧版本（安装路径：用户目录+系统目录）
                            cp -f /tmp/XLtool_new.sh ~/XLtool.sh
                            cp -f /tmp/XLtool_new.sh /usr/local/bin/k 2>/dev/null
                            chmod +x ~/XLtool.sh /usr/local/bin/k 2>/dev/null
                            echo -e "${gl_lv}更新完成，请重新运行脚本${gl_bai}"
                            send_stats "脚本更新至 v$new_version"
                            exit 0
                        fi
                    else
                        echo -e "${gl_lv}当前已是最新版本 v$sh_v${gl_bai}"
                    fi
                    rm -f /tmp/XLtool_new.sh  # 清理临时文件
                else
                    echo -e "${gl_hong}更新失败，无法获取新版本${gl_bai}"
                fi
                ;;
            9)
                # 隐私设置（关闭统计）
                read -e -p "确定要关闭使用统计吗？(Y/N): " confirm
                if [ "$confirm" = "Y" ] || [ "$confirm" = "y" ]; then
                    yinsiyuanquan2  # 关闭统计（预设函数）
                    echo -e "${gl_lv}已关闭使用统计${gl_bai}"
                    send_stats "关闭使用统计"
                else
                    echo -e "${gl_huang}已取消操作${gl_bai}"
                fi
                ;;
            0)
                # 退出脚本
                echo -e "${gl_XLtool}感谢使用 XLtool 脚本，再见！${gl_bai}"
                send_stats "退出脚本"
                exit 0
                ;;
            *)
                echo -e "${gl_hong}❌ 无效选择，请输入 0-9 之间的数字${gl_bai}"
                ;;
        esac
        break_end  # 暂停查看结果
    done
}


# ============== 脚本初始化 ==============
root_use  # 检查root权限（必须root执行）
XLtool    # 启动主菜单
