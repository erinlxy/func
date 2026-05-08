#!/bin/bash

# --- 配置信息 ---
SOURCE_DIR="/opt/test_platform_data/jobs"
BACKUP_ROOT="/opt/test_platform_data/backups"
TEMP_DIR="/tmp/log_grouping"

# 确保目录存在
mkdir -p "$BACKUP_ROOT"
mkdir -p "$TEMP_DIR"

# 进入源目录
cd "$SOURCE_DIR" || exit

echo "--- 开始执行 24 小时外日志目录清理任务 ($(date)) ---"

# 1. 找到修改时间在 24 小时之前的【文件夹】
# -maxdepth 1: 只查找当前层级
# -type d: 只找目录
# -mtime +0: 修改时间超过 24 小时
DIRS=$(find . -maxdepth 1 -mindepth 1 -type d -mtime +0)

if [ -z "$DIRS" ]; then
    echo "未发现 24 小时之前的旧目录，无需处理。"
    exit 0
fi

# 2. 遍历这些目录，按日期归类
for DIR in $DIRS; do
    # 去掉路径前缀 ./
    DIR_NAME=$(basename "$DIR")
    
    # 获取目录的最后修改日期 (格式: 2026-05-07)
    DIR_DATE=$(date -r "$DIR" +%Y-%m-%d)
    
    # 创建日期的临时中转站
    mkdir -p "$TEMP_DIR/$DIR_DATE"
    
    # 移动目录到临时中转站
    mv "$DIR" "$TEMP_DIR/$DIR_DATE/"
done

# 3. 遍历临时中转站，按天打包压缩
cd "$TEMP_DIR" || exit
for DATE_FOLDER in *; do
    if [ -d "$DATE_FOLDER" ]; then
        ARCHIVE_NAME="jobs_backup_$DATE_FOLDER.tar.gz"
        
        echo "正在打包日期为 $DATE_FOLDER 的所有任务目录..."
        
        # 压缩该日期下的所有文件夹
        tar -czf "$BACKUP_ROOT/$ARCHIVE_NAME" "$DATE_FOLDER"
        
        # 4. 安全检查：压缩成功才删除临时数据
        if [ -s "$BACKUP_ROOT/$ARCHIVE_NAME" ]; then
            echo "备份成功: $ARCHIVE_NAME"
            rm -rf "$DATE_FOLDER"
        else
            echo "错误：$DATE_FOLDER 压缩失败！"
        fi
    fi
done

# 5. 自动清理 30 天前的旧备份文件
find "$BACKUP_ROOT" -mtime +30 -name "*.tar.gz" -delete

echo "--- 任务完成 ---"
