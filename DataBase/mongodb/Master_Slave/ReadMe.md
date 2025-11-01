# 一主一从模式配置参考

[P-S模式搭建](https://www.yuque.com/yuqueyonghukvu43y/rpbw4d/xfz53it1pzewga7n)


# 问题：Location5579201: Unable to acquire security key[s]
    关键问题：mongod 实际运行时，是以 mongodb 用户身份读取 keyFile 的，而挂载的文件在容器内可能对 mongodb 用户不可读。