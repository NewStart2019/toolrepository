# 使用场景：数据库迁移之后比较数据库的大小和内容是否相同
# pip install pymongo tabulate

from pymongo import MongoClient
from tabulate import tabulate

def get_collection_stats(db, db_name):
    """获取指定数据库中所有集合的统计信息"""
    stats = []
    # 获取所有集合名称
    collections = db.list_collection_names()

    for coll_name in collections:
        # 使用 collStats 命令获取集合的详细底层统计信息
        coll_stat = db.command("collStats", coll_name)
        stats.append({
            "collection": coll_name,
            "doc_count": coll_stat.get("count", 0),  # 文档数
            "index_count": coll_stat.get("nindexes", 0),  # 索引数
            "storage_size": coll_stat.get("storageSize", 0)  # 存储大小(字节)
        })
    return {db_name: stats}

def compare_databases(source_uri, source_db_name, target_uri, target_db_name):
    """对比源库和目标库的集合信息"""
    # 1. 连接源数据库和目标数据库
    source_client = MongoClient(source_uri)
    target_client = MongoClient(target_uri)

    source_db = source_client[source_db_name]
    target_db = target_client[target_db_name]

    # 2. 获取两边的统计数据
    source_stats = get_collection_stats(source_db, source_db_name)
    target_stats = get_collection_stats(target_db, target_db_name)

    # 3. 整合数据以便对比
    source_data = {s['collection']: s for s in source_stats[source_db_name]}
    target_data = {s['collection']: s for s in target_stats[target_db_name]}

    # 获取所有出现过的集合名（并集，防止迁移漏了集合）
    all_collections = sorted(set(source_data.keys()) | set(target_data.keys()))

    # 4. 准备打印的表格数据
    table_data = []
    for coll in all_collections:
        src = source_data.get(coll, {})
        tgt = target_data.get(coll, {})

        # 如果某一边缺失该集合，标记为 "MISSING"
        doc_diff = "✅" if src.get('doc_count') == tgt.get('doc_count') else "❌ 不一致"
        idx_diff = "✅" if src.get('index_count') == tgt.get('index_count') else "❌ 不一致"

        # 格式化存储大小 (转换为 MB)
        src_size = f"{src.get('storage_size', 0) / 1024 / 1024:.2f} MB" if coll in source_data else "MISSING"
        tgt_size = f"{tgt.get('storage_size', 0) / 1024 / 1024:.2f} MB" if coll in target_data else "MISSING"

        if "❌ 不一致" == doc_diff or "❌ 不一致" == idx_diff:
            table_data.append([
                coll,
                src.get('doc_count', 'MISSING'), tgt.get('doc_count', 'MISSING'), doc_diff,
                src.get('index_count', 'MISSING'), tgt.get('index_count', 'MISSING'), idx_diff,
                src_size, tgt_size
            ])

    # 5. 打印对比结果表格
    headers = ["集合名", "源文档数", "目标文档数", "文档对比", "源索引数", "目标索引数", "索引对比", "源存储大小",
               "目标存储大小"]
    print(f"\n--- 数据库对比报告: {source_db_name} (源) vs {target_db_name} (目标) ---")
    print(tabulate(table_data, headers=headers, tablefmt="grid"))

    # 关闭连接
    source_client.close()
    target_client.close()
    return table_data

def find_id_differences(source_uri, source_db_name, target_uri, target_db_name, collection_name):
    print(f"\n正在对比集合: 【{collection_name}】")
    print("-" * 50)

    # 1. 连接数据库
    source_client = MongoClient(source_uri)
    target_client = MongoClient(target_uri)
    source_coll = source_client[source_db_name][collection_name]
    target_coll = target_client[target_db_name][collection_name]

    try:
        # 2. 提取源库和目标库的所有 _id 并转为集合 (Set)
        # 使用 set() 可以自动去重，并且后续做差集运算效率极高
        source_ids = set(doc['_id'] for doc in source_coll.find({}, {'_id': 1}))
        target_ids = set(doc['_id'] for doc in target_coll.find({}, {'_id': 1}))

        # 3. 计算差集
        # 目标库有，但源库没有的 _id (多出来的)
        extra_in_target = target_ids - source_ids
        # 源库有，但目标库没有的 _id (丢失的)
        missing_in_target = source_ids - target_ids

        # 4. 打印结果
        print(f"📊 源库文档总数: {len(source_ids)}")
        print(f"📊 目标库文档总数: {len(target_ids)}")

        if extra_in_target:
            print(f"\n🔴 目标库多出来的文档 _id (共 {len(extra_in_target)} 条):")
            for _id in extra_in_target:
                print(f"   -> {_id}")
        else:
            print(f"\n✅ 目标库没有多余的文档。")

        if missing_in_target:
            print(f"\n🟡 目标库缺失的文档 _id (共 {len(missing_in_target)} 条):")
            for _id in missing_in_target:
                print(f"   -> {_id}")
        else:
            print(f"\n✅ 目标库没有缺失文档。")

    except Exception as e:
        print(f"❌ 对比过程中发生错误: {e}")
    finally:
        # 关闭连接
        source_client.close()
        target_client.close()

if __name__ == "__main__":
    # 替换为你实际的 MongoDB 连接 URI 和数据库名
    SOURCE_URI = "mongodb://admin:Zjzx123!@172.16.0.29:27017/"
    SOURCE_DB = "jcgl-jbz"

    TARGET_URI = "mongodb://admin:KbJFJXEdKNjeDT4!@172.16.0.97:27017/"
    TARGET_DB = "jcgl-jbz"

    table_data = compare_databases(SOURCE_URI, SOURCE_DB, TARGET_URI, TARGET_DB)
    # 获取 table_data 数据中每个元素 也是[] 中的第一个 元素为数组
    COLLECTIONS_TO_CHECK = [item[0] for item in table_data]
    for coll_name in COLLECTIONS_TO_CHECK:
        find_id_differences(SOURCE_URI, SOURCE_DB, TARGET_URI, TARGET_DB, coll_name)
