function waitForMembers(hosts, timeoutSec) {
  const start = new Date();
  print("⏳ Waiting for all replica set members to be available...");
  while (true) {
    let allOk = true;
    for (const h of hosts) {
      try {
        // 尝试连接成员
        const conn = new Mongo(h);
        conn.getDB("admin").runCommand({ ping: 1 });
      } catch (e) {
        allOk = false;
        print(`❌ ${h} not ready yet: ${e}`);
        break;
      }
    }
    if (allOk) {
      print("✅ All members are reachable");
      return;
    }
    if ((new Date() - start) / 1000 > timeoutSec) {
      throw new Error("❌ Timeout waiting for all members to be ready");
    }
    sleep(2000); // 每 2 秒重试一次
  }
}

// 成员地址（Docker 内部网络名）
const members = [
  "172.16.0.170:27017",
  "172.16.0.170:27018",
  "172.16.0.170:27019"
];

// 会在 primary 启动时不断 ping 其他成员（包括 secondary 和 arbiter）直到可连接
// 等待节点就绪（最多等 120 秒）
waitForMembers(members, 120);

// 初始化副本集
rs.initiate({
  _id: "rs0",
  members: [
    { _id: 0, host: members[0], priority: 2 },
    { _id: 1, host: members[1], priority: 0 },
    { _id: 2, host: members[2], arbiterOnly: true }
  ]
});

// 等待选主完成
sleep(5000);
// 设置默认写 concern
use admin;
db.adminCommand({
  setDefaultRWConcern: 1,
  defaultWriteConcern: { w: "majority" }
});

// 创建 root 用户
db.createUser({
  user: "root",
  pwd: "123456",
  roles: [ { role: "root", db: "admin" } ]
});

print("🎉 Replica set initialized successfully!");
rs.status();
