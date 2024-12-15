#!/bin/bash

# 定义 AdGuardHome 默认端口列表
PORTS=("53/tcp" "53/udp" "67/udp" "80/tcp" "443/tcp" "3000/tcp")

echo "检测 AdGuardHome 默认端口是否被占用..."

for PORT in "${PORTS[@]}"; do
    # 提取协议和端口
    PROTOCOL=$(echo $PORT | cut -d'/' -f2)
    PORT_NUMBER=$(echo $PORT | cut -d'/' -f1)

    # 检测端口占用情况
    echo "检查端口 $PORT_NUMBER ($PROTOCOL)..."
    RESULT=$(sudo lsof -i $PROTOCOL:$PORT_NUMBER)

    if [[ -z "$RESULT" ]]; then
        echo "端口 $PORT_NUMBER ($PROTOCOL) 未被占用。"
    else
        echo "端口 $PORT_NUMBER ($PROTOCOL) 被占用，详细信息如下："
        echo "$RESULT"

        # 提取占用端口的进程 PID
        PIDS=$(echo "$RESULT" | awk 'NR>1 {print $2}' | sort -u)

        echo "以下进程正在占用端口 $PORT_NUMBER ($PROTOCOL)："
        for PID in $PIDS; do
            PROCESS_NAME=$(ps -p $PID -o comm=)
            echo "PID: $PID, 进程名: $PROCESS_NAME"
        done

        # 提示用户是否终止进程
        read -p "是否终止占用端口 $PORT_NUMBER ($PROTOCOL) 的所有进程？(y/n): " CONFIRM
        if [[ "$CONFIRM" == "y" || "$CONFIRM" == "Y" ]]; then
            for PID in $PIDS; do
                sudo kill -9 $PID
                echo "已终止 PID: $PID 的进程。"
            done
            echo "端口 $PORT_NUMBER ($PROTOCOL) 已释放。"
        else
            echo "未终止进程，请手动处理占用问题。"
        fi
    fi
done

echo "所有端口检测完成。"

