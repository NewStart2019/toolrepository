  ROOT_PATH=$1
  REPOSITORY_URL=$2
  # 判断文件夹存在与否
  if [ ! -d ROOT_PATH ];then
    mkdir -p $ROOT_PATH
  else
    echo "文件夹已经存在,正在删除创建……"
    rm -rf $ROOT_PATH/*
  fi
  cd $ROOT_PATH
  # 下拉指定分支的代码 最新代码
  git clone -b $TAG $REPOSITORY_URL
