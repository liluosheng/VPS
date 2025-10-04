#!/bin/bash
set -e

show_menu() {
    clear
    echo "=============================="
    echo " 🚀 Docker 清理工具"
    echo "=============================="
    echo "1) 查看容器"
    echo "2) 删除容器"
    echo "3) 查看镜像"
    echo "4) 删除镜像"
    echo "5) 查看网络"
    echo "6) 删除网络"
    echo "7) 清理日志"
    echo "8) 一键清理未使用资源 (容器+镜像+网络+缓存)"
    echo "0) 退出"
    echo "=============================="
}

delete_containers() {
    docker ps -a
    echo -n "输入要删除的容器ID/NAME（多个用空格分隔，或输入 all 全部删除）："
    read ids
    if [ "$ids" = "all" ]; then
        docker rm -f $(docker ps -aq)
    else
        docker rm -f $ids
    fi
}

delete_images() {
    docker images
    echo -n "输入要删除的镜像ID/NAME（多个用空格分隔，或输入 all 全部删除）："
    read ids
    if [ "$ids" = "all" ]; then
        docker rmi -f $(docker images -q)
    else
        docker rmi -f $ids
    fi
}

delete_networks() {
    docker network ls
    echo -n "输入要删除的网络NAME/ID（多个用空格分隔，或输入 all 全部删除）："
    read ids
    if [ "$ids" = "all" ]; then
        docker network prune -f
    else
        docker network rm $ids
    fi
}

clean_logs() {
    echo "正在清理 Docker 日志..."
    sudo find /var/lib/docker/containers/ -type f -name "*.log" -exec truncate -s 0 {} \;
    echo "✅ 日志已清空"
}

while true; do
    show_menu
    read -p "请选择操作: " choice
    case $choice in
        1) docker ps -a; read -p "按回车继续...";;
        2) delete_containers; read -p "按回车继续...";;
        3) docker images; read -p "按回车继续...";;
        4) delete_images; read -p "按回车继续...";;
        5) docker network ls; read -p "按回车继续...";;
        6) delete_networks; read -p "按回车继续...";;
        7) clean_logs; read -p "按回车继续...";;
        8) docker system prune -af --volumes; read -p "按回车继续...";;
        0) echo "退出"; exit 0;;
        *) echo "❌ 无效选择";;
    esac
done
