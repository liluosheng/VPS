#!/bin/bash
set -e

# ============== 基础配置（颜色变量、GitHub代理） ==============
# ANSI颜色码定义（解决原脚本中gl_huang/gl_bai变量未定义问题）
gl_huang="\033[33m"  # 黄色
gl_bai="\033[0m"     # 白色（重置颜色）
# GitHub代理（国内环境默认启用，避免拉取脚本失败）
gh_proxy="https://ghproxy.com/"

# ============== 您提供的Docker安装核心函数 ==============
install_add_docker_cn() {
    local country=$(curl -s ipinfo.io/country)
    if [ "$country" = "CN" ]; then
        echo -e "${gl_huang}>>> 检测到国内环境，配置Docker国内镜像源...${gl_bai}"
        # 创建/覆盖daemon.json（确保目录存在）
        sudo mkdir -p /etc/docker
        sudo cat > /etc/docker/daemon.json << EOF
{
  "registry-mirrors": [
    "https://docker-0.unsee.tech",
    "https://docker.1panel.live",
    "https://registry.dockermirror.com",
    "https://docker.imgdb.de",
    "https://docker.m.daocloud.io",
    "https://hub.firefly.store",
    "https://hub.littlediary.cn",
    "https://hub.rat.dev",
    "https://dhub.kubesre.xyz",
    "https://cjie.eu.org",
    "https://docker.1panelproxy.com",
    "https://docker.hlmirror.com",
    "https://hub.fast360.xyz",
    "https://dockerpull.cn",
    "https://cr.laoyou.ip-ddns.com",
    "https://docker.melikeme.cn",
    "https://docker.kejilion.pro"
  ]
}
EOF
        # 重启Docker使镜像配置生效（修正原脚本中service命令兼容性问题）
        sudo systemctl enable docker
        sudo systemctl start docker
        sudo systemctl restart docker
        echo -e "${gl_huang}>>> Docker国内镜像源配置完成！${gl_bai}"
    fi
}

install_add_docker_guanfang() {
    local country=$(curl -s ipinfo.io/country)
    if [ "$country" = "CN" ]; then
        echo -e "${gl_huang}>>> 国内环境，使用阿里云镜像安装Docker...${gl_bai}"
        cd ~
        # 拉取阿里云Docker安装脚本（带GitHub代理）
        curl -sS -O ${gh_proxy}raw.githubusercontent.com/kejilion/docker/main/install && chmod +x install
        sh install --mirror Aliyun
        rm -f install
    else
        echo -e "${gl_huang}>>> 海外环境，使用官方脚本安装Docker...${gl_bai}"
        curl -fsSL https://get.docker.com | sh
    fi
    # 安装后配置国内镜像（若需）
    install_add_docker_cn
}

install_add_docker() {
    echo -e "${gl_huang}正在安装Docker环境...${gl_bai}"
    # 1. 适配Fedora系统（dnf包管理器）
    if [ -f /etc/os-release ] && grep -q "Fedora" /etc/os-release; then
        install_add_docker_guanfang
    
    # 2. 适配CentOS/RHEL系统（dnf包管理器）
    elif command -v dnf &>/dev/null; then
        sudo dnf update -y
        sudo dnf install -y yum-utils device-mapper-persistent-data lvm2
        # 删除旧的Docker repo
        sudo rm -f /etc/yum.repos.d/docker*.repo > /dev/null
        local country=$(curl -s ipinfo.io/country)
        local arch=$(uname -m)
        
        # 国内环境用阿里云源，海外用官方源
        if [ "$country" = "CN" ]; then
            curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo | sudo tee /etc/yum.repos.d/docker-ce.repo > /dev/null
        else
            sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo > /dev/null
        fi
        
        sudo dnf install -y docker-ce docker-ce-cli containerd.io
        install_add_docker_cn
    
    # 3. 适配Kali系统（基于Debian）
    elif [ -f /etc/os-release ] && grep -q "Kali" /etc/os-release; then
        sudo apt update
        sudo apt upgrade -y
        sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release
        sudo rm -f /usr/share/keyrings/docker-archive-keyring.gpg
        local country=$(curl -s ipinfo.io/country)
        local arch=$(uname -m)
        
        # 按架构和地区配置源
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
        
        sudo apt update
        sudo apt install -y docker-ce docker-ce-cli containerd.io
        install_add_docker_cn
    
    # 4. 适配Debian/Ubuntu/CentOS（apt/yum通用）
    elif command -v apt &>/dev/null || command -v yum &>/dev/null; then
        install_add_docker_guanfang
    
    # 5. 其他系统（通用安装命令）
    else
        echo -e "${gl_huang}>>> 检测到未知系统，尝试通用安装...${gl_bai}"
        sudo apt install -y docker docker-compose || sudo yum install -y docker docker-compose
        install_add_docker_cn
    fi
    
    sleep 2
    echo -e "${gl_huang}>>> Docker基础环境安装完成！${gl_bai}"
}

# 外层判断：若未安装Docker则执行安装
install_docker() {
    if ! command -v docker &>/dev/null; then
        install_add_docker
    else
        echo -e "${gl_huang}>>> Docker已安装，跳过安装步骤...${gl_bai}"
    fi
}

# ============== 原有功能模块（容器管理、镜像管理等） ==============
# ========== 容器管理 ==========
docker_ps() {
    while true; do
        clear
        echo "====== Docker 容器管理 ======"
        docker ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}"
        echo "-----------------------------"
        echo "1. 创建新的容器"
        echo "2. 启动指定容器         6. 启动所有容器"
        echo "3. 停止指定容器         7. 停止所有容器"
        echo "4. 删除指定容器         8. 删除所有容器"
        echo "5. 重启指定容器         9. 重启所有容器"
        echo "11. 进入指定容器       12. 查看容器日志"
        echo "13. 查看容器网络       14. 查看容器占用"
        echo "0. 返回上一级"
        echo "-----------------------------"
        read -p "请输入选择: " c
        case $c in
            1) read -p "输入镜像名: " img; read -p "输入容器名: " cname; sudo docker run -dit --name $cname $img;;
            2) read -p "容器ID/名: " id; sudo docker start $id;;
            3) read -p "容器ID/名: " id; sudo docker stop $id;;
            4) read -p "容器ID/名: " id; sudo docker rm -f $id;;
            5) read -p "容器ID/名: " id; sudo docker restart $id;;
            6) sudo docker start $(sudo docker ps -aq);;
            7) sudo docker stop $(sudo docker ps -aq);;
            8) sudo docker rm -f $(sudo docker ps -aq);;
            9) sudo docker restart $(sudo docker ps -aq);;
            11) read -p "容器ID/名: " id; sudo docker exec -it $id bash;;
            12) read -p "容器ID/名: " id; sudo docker logs -f $id;;
            13) sudo docker network ls;;
            14) sudo docker stats;;
            0) break;;
            *) echo "❌ 无效选择";;
        esac
        read -p "按回车继续..."
    done
}

# ========== 镜像管理 ==========
docker_image() {
    while true; do
        clear
        echo "====== Docker 镜像管理 ======"
        sudo docker images
        echo "-----------------------------"
        echo "1. 拉取指定镜像"
        echo "2. 更新指定镜像"
        echo "3. 删除指定镜像"
        echo "4. 删除所有镜像"
        echo "0. 返回上一级"
        echo "-----------------------------"
        read -p "请输入选择: " i
        case $i in
            1) read -p "输入镜像名: " img; sudo docker pull $img;;
            2) read -p "输入镜像名: " img; sudo docker pull $img;;
            3) read -p "输入镜像ID/名: " img; sudo docker rmi -f $img;;
            4) sudo docker rmi -f $(sudo docker images -q);;
            0) break;;
            *) echo "❌ 无效选择";;
        esac
        read -p "按回车继续..."
    done
}

# ========== 清理工具 ==========
docker_clean() {
    while true; do
        clear
        echo "====== Docker 清理工具 ======"
        echo "1. 删除容器"
        echo "2. 删除镜像"
        echo "3. 删除网络"
        echo "4. 清理日志"
        echo "5. 一键清理未使用资源"
        echo "0. 返回上一级"
        echo "-----------------------------"
        read -p "请输入选择: " c
        case $c in
            1) docker_ps;;
            2) docker_image;;
            3) sudo docker network prune -f;;
            4) sudo find /var/lib/docker/containers/ -type f -name "*.log" -exec truncate -s 0 {} \;;
            5) sudo docker system prune -af --volumes;;
            0) break;;
            *) echo "❌ 无效选择";;
        esac
        read -p "按回车继续..."
    done
}

# ========== Docker Compose 管理 ==========
docker_compose_manage() {
    while true; do
        clear
        echo "====== Docker Compose 管理 ======"
        
        # 查找当前目录下的docker-compose配置文件
        compose_files=$(find . -maxdepth 1 -type f \( -name "docker-compose.yml" -o -name "docker-compose.yaml" \) | sort)
        file_count=$(echo "$compose_files" | wc -l | tr -d ' ')

        if [ $file_count -eq 0 ]; then
            echo "⚠️ 当前目录未找到 docker-compose.yml 或 docker-compose.yaml 文件"
        else
            echo "📁 找到 $file_count 个 Compose 项目："
            echo "-----------------------------"
            index=1
            # 存储文件列表到数组
            declare -a files_array=()
            while IFS= read -r file; do
                files_array+=("$file")
                echo "$index. $file"
                index=$((index + 1))
            done <<< "$compose_files"
        fi

        echo "-----------------------------"
        echo "1. 选择项目操作"
        echo "2. 新建/指定其他 Compose 文件"
        echo "0. 返回上一级"
        echo "-----------------------------"
        read -p "请输入选择: " choice

        case $choice in
            1)
                if [ $file_count -eq 0 ]; then
                    echo "❌ 没有可操作的项目"
                    read -p "按回车继续..."
                    continue
                fi
                read -p "请输入项目序号: " num
                if ! [[ $num =~ ^[0-9]+$ ]] || [ $num -lt 1 ] || [ $num -gt $file_count ]; then
                    echo "❌ 无效序号"
                    read -p "按回车继续..."
                    continue
                fi
                selected_file="${files_array[$((num - 1))]}"
                echo "已选择: $selected_file"
                
                # 项目操作菜单
                while true; do
                    clear
                    echo "====== 操作项目: $selected_file ======"
                    echo "1. 启动服务 (up -d)"
                    echo "2. 停止服务 (down)"
                    echo "3. 重启服务 (restart)"
                    echo "4. 查看日志 (logs -f)"
                    echo "5. 查看状态 (ps)"
                    echo "0. 返回上一级"
                    echo "-----------------------------"
                    read -p "请输入操作: " action
                    case $action in
                        1) sudo docker compose -f "$selected_file" up -d;;
                        2) sudo docker compose -f "$selected_file" down;;
                        3) sudo docker compose -f "$selected_file" restart;;
                        4) sudo docker compose -f "$selected_file" logs -f;;
                        5) sudo docker compose -f "$selected_file" ps;;
                        0) break;;
                        *) echo "❌ 无效操作";;
                    esac
                    read -p "按回车继续..."
                done
                ;;
            2)
                read -p "请输入 Compose 文件路径 (如: ./my-compose.yml): " custom_file
                if [ ! -f "$custom_file" ]; then
                    echo "❌ 文件不存在: $custom_file"
                    read -p "按回车继续..."
                    continue
                fi
                # 自定义文件操作菜单
                while true; do
                    clear
                    echo "====== 操作项目: $custom_file ======"
                    echo "1. 启动服务 (up -d)"
                    echo "2. 停止服务 (down)"
                    echo "3. 重启服务 (restart)"
                    echo "4. 查看日志 (logs -f)"
                    echo "5. 查看状态 (ps)"
                    echo "0. 返回上一级"
                    echo "-----------------------------"
                    read -p "请输入操作: " action
                    case $action in
                        1) sudo docker compose -f "$custom_file" up -d;;
                        2) sudo docker compose -f "$custom_file" down;;
                        3) sudo docker compose -f "$custom_file" restart;;
                        4) sudo docker compose -f "$custom_file" logs -f;;
                        5) sudo docker compose -f "$custom_file" ps;;
                        0) break;;
                        *) echo "❌ 无效操作";;
                    esac
                    read -p "按回车继续..."
                done
                ;;
            0)
                break
                ;;
            *)
                echo "❌ 无效选择"
                read -p "按回车继续..."
                ;;
        esac
    done
}

# ============== 主菜单 ==============
while true; do
    clear
    echo -e "${gl_huang}==============================${gl_bai}"
    echo -e "${gl_huang} 🛠 Docker 工具箱（多系统适配版）${gl_bai}"
    echo -e "${gl_huang}==============================${gl_bai}"
    echo "1) 安装 Docker & Compose（自动适配系统/地区）"
    echo "2) 容器管理"
    echo "3) 镜像管理"
    echo "4) 清理工具"
    echo "5) Docker Compose 管理"
    echo "0) 退出"
    echo -e "${gl_huang}==============================${gl_bai}"
    read -p "请选择操作: " main_choice
    case $main_choice in
        1) install_docker; read -p "按回车继续...";;
        2) docker_ps;;
        3) docker_image;;
        4) docker_clean;;
        5) docker_compose_manage;;
        0) echo -e "${gl_huang}>>> 退出工具箱，再见！${gl_bai}"; exit 0;;
        *) echo "❌ 无效选择";;
    esac
done
