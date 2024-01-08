#!/bin/sh
ROOT_PATH=$1
REPOSITORY_URL=$2
TAG=$3
COMMIT=$4
# 判断文件存在
if [ -d "${ROOT_PATH}/code" ]; then
	echo "文件夹已经存在,正在删除……"
	rm -rf $ROOT_PATH/code
fi
mkdir -p $ROOT_PATH/code
cd $ROOT_PATH/code
# 下拉指定分支的代码 最新代码
git clone -b $TAG $REPOSITORY_URL
REPOSITORY_NAME=$(ls)
mv $ROOT_PATH/code/$REPOSITORY_NAME/* $ROOT_PATH/code/
mv $ROOT_PATH/code/$REPOSITORY_NAME/.* $ROOT_PATH/code/
if [ "$COMMIT" != "" ]; then
    git checkout -q "$COMMIT"
fi
git log --oneline -n 1 HEAD
