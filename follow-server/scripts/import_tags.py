#!/usr/bin/env python3
"""
批量导入音乐标签脚本

使用方式:
    python import_tags.py <excel_file> [--dry-run] [--category <分类>]

Excel 文件格式:
    - 每个 sheet 表示一个标签，sheet 名称即为标签名
    - 每个 sheet 中包含歌曲列表，格式为 "歌手 - 歌曲名称"
    - 可以是单列数据，也可以有表头

示例:
    python import_tags.py tags.xlsx --dry-run          # 预览模式，不实际写入
    python import_tags.py tags.xlsx                    # 实际执行导入
    python import_tags.py tags.xlsx --category 风格   # 指定标签分类
"""

import argparse
import sys
from pathlib import Path

import pandas as pd
import psycopg2
from psycopg2.extras import execute_values


def parse_song_name(song_str: str) -> tuple[str, str] | None:
    """
    解析歌曲字符串，提取歌手和歌曲名称
    
    格式: "歌手 - 歌曲名称"
    返回: (artist, title) 或 None（如果格式不正确）
    """
    if not song_str or not isinstance(song_str, str):
        return None
    
    song_str = song_str.strip()
    if ' - ' not in song_str:
        return None
    
    parts = song_str.split(' - ', 1)
    if len(parts) != 2:
        return None
    
    artist = parts[0].strip()
    title = parts[1].strip()
    
    if not artist or not title:
        return None
    
    return (artist, title)


def read_excel_sheets(excel_path: str) -> dict[str, list[str]]:
    """
    读取 Excel 文件，返回 {sheet名/标签名: [歌曲列表]} 的字典
    """
    excel_file = pd.ExcelFile(excel_path)
    result = {}
    
    for sheet_name in excel_file.sheet_names:
        df = pd.read_excel(excel_file, sheet_name=sheet_name, header=None)
        
        # 获取第一列的所有值（假设歌曲名在第一列）
        songs = []
        for value in df.iloc[:, 0].dropna():
            value_str = str(value).strip()
            if value_str and value_str != 'nan':
                songs.append(value_str)
        
        if songs:
            result[sheet_name] = songs
    
    return result


def get_db_connection(
    host: str = "localhost",
    port: int = 5432,
    database: str = "follow",
    user: str = "follow",
    password: str = "follow"
):
    """创建数据库连接"""
    return psycopg2.connect(
        host=host,
        port=port,
        database=database,
        user=user,
        password=password
    )


def get_or_create_tag(cursor, tag_name: str, category: str | None = None) -> str:
    """
    获取或创建标签，返回标签 ID
    """
    # 先查找是否存在
    cursor.execute(
        'SELECT "Id" FROM "Tags" WHERE "Name" = %s',
        (tag_name,)
    )
    result = cursor.fetchone()
    
    if result:
        return str(result[0])
    
    # 不存在则创建
    import uuid
    tag_id = str(uuid.uuid4())
    cursor.execute(
        '''
        INSERT INTO "Tags" ("Id", "Name", "Category", "CreatedAt")
        VALUES (%s, %s, %s, NOW())
        ''',
        (tag_id, tag_name, category)
    )
    return tag_id


def find_track_by_artist_title(cursor, artist: str, title: str) -> str | None:
    """
    根据歌手和歌曲名称查找 Track ID
    """
    cursor.execute(
        '''
        SELECT t."Id" 
        FROM "Tracks" t
        LEFT JOIN "Artists" a ON t."ArtistId" = a."Id"
        WHERE LOWER(t."Title") = LOWER(%s) 
          AND LOWER(a."Name") = LOWER(%s)
        ''',
        (title, artist)
    )
    result = cursor.fetchone()
    return str(result[0]) if result else None


def add_track_tag(cursor, track_id: str, tag_id: str) -> bool:
    """
    添加 Track-Tag 关联，如果已存在则跳过
    返回是否新增了关联
    """
    # 检查是否已存在
    cursor.execute(
        'SELECT 1 FROM "TrackTags" WHERE "TrackId" = %s AND "TagId" = %s',
        (track_id, tag_id)
    )
    if cursor.fetchone():
        return False
    
    # 添加关联
    import uuid
    cursor.execute(
        '''
        INSERT INTO "TrackTags" ("Id", "TrackId", "TagId", "CreatedAt")
        VALUES (%s, %s, %s, NOW())
        ''',
        (str(uuid.uuid4()), track_id, tag_id)
    )
    return True


def import_tags(
    excel_path: str,
    category: str | None = None,
    dry_run: bool = False,
    db_host: str = "localhost",
    db_port: int = 5432,
    db_name: str = "follow",
    db_user: str = "follow",
    db_password: str = "follow"
):
    """
    主导入函数
    """
    print(f"📂 读取 Excel 文件: {excel_path}")
    
    # 读取 Excel
    sheets = read_excel_sheets(excel_path)
    print(f"📋 发现 {len(sheets)} 个标签 (sheets)")
    
    if dry_run:
        print("\n🔍 预览模式 (--dry-run)，不会实际写入数据库\n")
    
    # 统计
    stats = {
        "tags_created": 0,
        "tags_existing": 0,
        "tracks_found": 0,
        "tracks_not_found": 0,
        "relations_added": 0,
        "relations_skipped": 0,
        "parse_errors": 0,
    }
    
    not_found_songs = []
    
    conn = None
    try:
        if not dry_run:
            conn = get_db_connection(db_host, db_port, db_name, db_user, db_password)
            cursor = conn.cursor()
        else:
            # 干运行模式下也需要连接数据库来验证歌曲是否存在
            conn = get_db_connection(db_host, db_port, db_name, db_user, db_password)
            cursor = conn.cursor()
        
        for tag_name, songs in sheets.items():
            print(f"\n🏷️  处理标签: {tag_name} ({len(songs)} 首歌曲)")
            
            # 获取或创建标签
            if not dry_run:
                tag_id = get_or_create_tag(cursor, tag_name, category)
            else:
                # 检查标签是否存在
                cursor.execute('SELECT "Id" FROM "Tags" WHERE "Name" = %s', (tag_name,))
                existing = cursor.fetchone()
                if existing:
                    tag_id = str(existing[0])
                    stats["tags_existing"] += 1
                    print(f"   ℹ️  标签已存在")
                else:
                    tag_id = "dry-run-id"
                    stats["tags_created"] += 1
                    print(f"   ✨ 将创建新标签")
            
            # 处理每首歌曲
            for song_str in songs:
                parsed = parse_song_name(song_str)
                if not parsed:
                    stats["parse_errors"] += 1
                    print(f"   ⚠️  格式错误: {song_str}")
                    continue
                
                artist, title = parsed
                
                # 查找歌曲
                track_id = find_track_by_artist_title(cursor, artist, title)
                
                if not track_id:
                    stats["tracks_not_found"] += 1
                    not_found_songs.append((tag_name, artist, title))
                    continue
                
                stats["tracks_found"] += 1
                
                if not dry_run:
                    # 添加关联
                    if add_track_tag(cursor, track_id, tag_id):
                        stats["relations_added"] += 1
                    else:
                        stats["relations_skipped"] += 1
                else:
                    # 干运行模式下检查关联是否存在
                    cursor.execute(
                        'SELECT 1 FROM "TrackTags" WHERE "TrackId" = %s AND "TagId" = %s',
                        (track_id, tag_id if tag_id != "dry-run-id" else None)
                    )
                    if cursor.fetchone():
                        stats["relations_skipped"] += 1
                    else:
                        stats["relations_added"] += 1
        
        if not dry_run:
            conn.commit()
            print("\n✅ 数据已提交到数据库")
        
    finally:
        if conn:
            conn.close()
    
    # 打印统计
    print("\n" + "=" * 50)
    print("📊 执行统计:")
    print(f"   标签 - 新创建: {stats['tags_created']}, 已存在: {stats['tags_existing']}")
    print(f"   歌曲 - 匹配成功: {stats['tracks_found']}, 未找到: {stats['tracks_not_found']}")
    print(f"   关联 - 新增: {stats['relations_added']}, 已存在跳过: {stats['relations_skipped']}")
    print(f"   错误 - 格式解析失败: {stats['parse_errors']}")
    
    # 输出未找到的歌曲列表
    if not_found_songs:
        print(f"\n⚠️  未找到的歌曲 ({len(not_found_songs)} 首):")
        for tag, artist, title in not_found_songs[:20]:  # 只显示前20首
            print(f"   [{tag}] {artist} - {title}")
        if len(not_found_songs) > 20:
            print(f"   ... 还有 {len(not_found_songs) - 20} 首未显示")
        
        # 保存完整的未找到列表到文件
        not_found_file = Path(excel_path).stem + "_not_found.txt"
        with open(not_found_file, 'w', encoding='utf-8') as f:
            for tag, artist, title in not_found_songs:
                f.write(f"[{tag}] {artist} - {title}\n")
        print(f"\n📝 完整未找到列表已保存到: {not_found_file}")
    
    return stats


def main():
    parser = argparse.ArgumentParser(
        description="从 Excel 文件批量导入音乐标签",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
    python import_tags.py tags.xlsx --dry-run          # 预览模式
    python import_tags.py tags.xlsx                    # 执行导入
    python import_tags.py tags.xlsx --category 风格   # 指定标签分类
        """
    )
    
    parser.add_argument("excel_file", help="Excel 文件路径")
    parser.add_argument("--dry-run", action="store_true", help="预览模式，不实际写入数据库")
    parser.add_argument("--category", help="标签分类（如：风格、场景、语言）")
    parser.add_argument("--db-host", default="localhost", help="数据库主机")
    parser.add_argument("--db-port", type=int, default=5432, help="数据库端口")
    parser.add_argument("--db-name", default="follow", help="数据库名称")
    parser.add_argument("--db-user", default="follow", help="数据库用户名")
    parser.add_argument("--db-password", default="follow", help="数据库密码")
    
    args = parser.parse_args()
    
    # 检查文件是否存在
    if not Path(args.excel_file).exists():
        print(f"❌ 文件不存在: {args.excel_file}")
        sys.exit(1)
    
    import_tags(
        excel_path=args.excel_file,
        category=args.category,
        dry_run=args.dry_run,
        db_host=args.db_host,
        db_port=args.db_port,
        db_name=args.db_name,
        db_user=args.db_user,
        db_password=args.db_password
    )


if __name__ == "__main__":
    main()
