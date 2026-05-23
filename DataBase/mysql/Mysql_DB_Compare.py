# pip install pymysql cryptography
import pymysql
import hashlib

# 数据库连接配置（请替换为你的实际信息）
SOURCE_DB_CONFIG = {
    'host': '172.16.0.29',
    'user': 'stc-jcgl',
    'password': 'VPvD2duhjFbzP8Cv6Ev2',
    'database': 'stc-jcgl',
    'charset': 'utf8mb4'
}

TARGET_DB_CONFIG = {
    'host': '172.16.0.97',
    'user': 'root',
    'password': 'VPvD2duhjFbzP8Cv6Ev2',
    'database': 'stc-jcgl',
    'charset': 'utf8mb4'
}


def get_connection(config):
    """建立数据库连接"""
    return pymysql.connect(**config)


def get_all_tables(cursor):
    """获取数据库中所有表名"""
    cursor.execute("SHOW TABLES")
    return [table[0] for table in cursor.fetchall()]


def get_table_row_count(cursor, table_name):
    """获取指定表的行数"""
    cursor.execute(f"SELECT COUNT(*) FROM `{table_name}`")
    return cursor.fetchone()[0]


def get_table_checksum(cursor, table_name):
    """
    计算表的校验和（基于MySQL自带的CHECKSUM TABLE命令）
    注意：此方法快速高效，适合绝大多数场景。
    """
    cursor.execute(f"CHECKSUM TABLE `{table_name}`")
    result = cursor.fetchone()
    return result[1] if result else None


def validate_migration():
    source_conn = get_connection(SOURCE_DB_CONFIG)
    target_conn = get_connection(TARGET_DB_CONFIG)

    try:
        with source_conn.cursor() as source_cursor, target_conn.cursor() as target_cursor:
            print("🚀 开始校验数据库迁移完整性...\n")

            # 1. 获取源库和目标库的所有表
            source_tables = set(get_all_tables(source_cursor))
            target_tables = set(get_all_tables(target_cursor))

            # 2. 校验表结构是否完整（有没有漏表或多表）
            missing_tables = source_tables - target_tables
            extra_tables = target_tables - source_tables

            if missing_tables:
                print(f"❌ 目标库缺失表: {missing_tables}")
            if extra_tables:
                print(f"⚠️ 目标库多出表: {extra_tables}")
            if not missing_tables and not extra_tables:
                print("✅ 表结构校验通过：所有表均存在。")

            # 3. 逐表校验数据行数和校验和
            common_tables = source_tables & target_tables
            all_passed = True

            print("\n🔍 开始逐表数据比对：")
            for table in sorted(common_tables):
                source_count = get_table_row_count(source_cursor, table)
                target_count = get_table_row_count(target_cursor, table)

                source_checksum = get_table_checksum(source_cursor, table)
                target_checksum = get_table_checksum(target_cursor, table)

                if source_count == target_count and source_checksum == target_checksum:
                    pass
                    # print(f"✅ 表 `{table}` 校验通过 (行数: {source_count}, 校验和: {source_checksum})")
                else:
                    print(f"❌ 表 `{table}` 数据不一致！")
                    print(f"   源库 -> 行数: {source_count}, 校验和: {source_checksum}")
                    print(f"   目标库 -> 行数: {target_count}, 校验和: {target_checksum}")
                    all_passed = False

            print("\n" + "=" * 40)
            if all_passed and not missing_tables:
                print("🎉 恭喜！所有数据校验通过，迁移未丢失数据！")
            else:
                print("⚠️ 警告：发现数据不一致或表缺失，请仔细排查！")

    finally:
        source_conn.close()
        target_conn.close()


if __name__ == "__main__":
    validate_migration()