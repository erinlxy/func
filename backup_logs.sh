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

echo "--- 开始执行 24 小时外日志清理任务 ($(date)) ---"

# 1. 找到修改时间在 24 小时之前的所有文件 (+0 表示 > 24小时)
# 这里排除目录，只处理文件
FILES=$(find . -maxdepth 1 -type f -mtime +0)

if [ -z "$FILES" ]; then
    echo "未发现 24 小时之前的旧日志，无需处理。"
    exit 0
fi

# 2. 遍历文件，按日期移动到临时目录进行分组
for FILE in $FILES; do
    # 获取文件的修改日期 (格式: 2026-05-07)
    FILE_DATE=$(date -r "$FILE" +%Y-%m-%d)
    
    # 创建该日期的临时子目录
    mkdir -p "$TEMP_DIR/$FILE_DATE"
    
    # 将文件移动到临时目录（先移动再压缩，确保原子性）
    mv "$FILE" "$TEMP_DIR/$FILE_DATE/"
done

# 3. 遍历临时目录，将每个日期的文件夹分别压缩
cd "$TEMP_DIR" || exit
for DATE_FOLDER in *; do
    if [ -d "$DATE_FOLDER" ]; then
        ARCHIVE_NAME="logs_$DATE_FOLDER.tar.gz"
        
        echo "正在打包 $DATE_FOLDER 的日志..."
        
        # 压缩文件夹
        tar -czf "$BACKUP_ROOT/$ARCHIVE_NAME" "$DATE_FOLDER"
        
        # 检查压缩包是否生成成功
        if [ -s "$BACKUP_ROOT/$ARCHIVE_NAME" ]; then
            echo "备份成功: $ARCHIVE_NAME，清理临时数据。"
            rm -rf "$DATE_FOLDER"
        else
            echo "错误：$DATE_FOLDER 压缩失败！保留临时文件以防数据丢失。"
        fi
    fi
done

# 4. 清理 30 天前的旧备份
find "$BACKUP_ROOT" -mtime +30 -name "*.tar.gz" -delete

echo "--- 任务完成 ---"
