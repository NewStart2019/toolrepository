#node: /lib64/libm.so.6: version `GLIBC_2.27' not found (required by node)
#node: /lib64/libc.so.6: version `GLIBC_2.25' not found (required by node)
#node: /lib64/libc.so.6: version `GLIBC_2.28' not found (required by node)
#node: /lib64/libstdc++.so.6: version `CXXABI_1.3.9' not found (required by node)
#node: /lib64/libstdc++.so.6: version `GLIBCXX_3.4.20' not found (required by node)
# nvm v18开始 最新版本的需要GLIBC_2.27支持，目前系统没有那么高的版本。 libstdc++
nvm_echo() {
  command printf %s\\n "$*" 2>/dev/null
}

nvm_try_profile() {
  if [ -z "${1-}" ] || [ ! -f "${1}" ]; then
    return 1
  fi
  nvm_echo "${1}"
}

#
# Detect profile file if not specified as environment variable
# (eg: PROFILE=~/.myprofile)
# The echo'ed path is guaranteed to be an existing file
# Otherwise, an empty string is returned
#
nvm_detect_profile() {
  if [ "${PROFILE-}" = '/dev/null' ]; then
    # the user has specifically requested NOT to have nvm touch their profile
    return
  fi

  if [ -n "${PROFILE}" ] && [ -f "${PROFILE}" ]; then
    nvm_echo "${PROFILE}"
    return
  fi

  local DETECTED_PROFILE
  DETECTED_PROFILE=''

  if [ -n "${BASH_VERSION-}" ]; then
    if [ -f "$HOME/.bashrc" ]; then
      DETECTED_PROFILE="$HOME/.bashrc"
    elif [ -f "$HOME/.bash_profile" ]; then
      DETECTED_PROFILE="$HOME/.bash_profile"
    fi
  elif [ -n "${ZSH_VERSION-}" ]; then
    DETECTED_PROFILE="$HOME/.zshrc"
  fi

  if [ -z "$DETECTED_PROFILE" ]; then
    for EACH_PROFILE in ".profile" ".bashrc" ".bash_profile" ".zshrc"; do
      if DETECTED_PROFILE="$(nvm_try_profile "${HOME}/${EACH_PROFILE}")"; then
        break
      fi
    done
  fi

  if [ -n "$DETECTED_PROFILE" ]; then
    nvm_echo "$DETECTED_PROFILE"
  fi
}

wget --version >>/dev/null
if [ "$?" = 127 ]; then
  yum install -y wget
fi

unzip -v >>/dev/null
if [ "$?" = 127 ]; then
  yum install -y unzip
fi

# 加载用户环境变量
NVM_PROFILE="$(nvm_detect_profile)"
# shellcheck disable=SC1090
source ${NVM_PROFILE}

if [ ! -e "${NVM_DIR}" ]; then
  echo -e "\e[31mNVM isn't already installed.\e[0m"
  exit 1
fi

#################### 更新glibc 需要bison
bison --version
if [ "$?" -ne 127 ]; then
  echo -e "\e[31m已经安装过bison\e[0m"
else
  sudo yum -y install bison
fi

#################### 下载glibc 需要 make4
make_upgrade() {
  make_version=$(make -v | grep -oP '(?<=GNU Make )(\d+\.\d+)')
  # 检查是否为空（即 make 是否安装）
  if [ -z "$make_version" ]; then
    echo -e "\e[31mMake is not installed.Installing make\e[0m"
    yum -y install make
    make -v
  fi
  make_version=$(make -v | grep -oP '(?<=GNU Make )(\d+\.\d+)')
  if [ "$make_version" != "4.3" ]; then
    echo -e "\e[31mInstalled make version: $make_version\e[0m"
    # 检查是否是 4.x 版本
    if [[ "$make_version" == "4."* ]]; then
      echo -e "\e[31mMake version 4.x is already installed.\e[0m"
    else
      echo -e "\e[31mInstalling make version 4.x...\e[0m"
      # 升级make 4.x 的命令
      cd || exit
      #    wget http://ftp.gnu.org/gnu/make/make-4.3.tar.gz
      wget http://172.16.0.97:84/make/make-4.3.tar.gz
      tar -xzvf make-4.3.tar.gz && cd make-4.3/ || exit
      ./configure --prefix=/usr/local/make
      if [ "$?" = 127 ]; then
        nvm_echo "make4安装 ../configure 失败"
        exit 1
      fi
      make && make install
      cd /usr/bin/ && mv -f make make.bak
      ln -sv /usr/local/make/bin/make /usr/bin/make
      cd || exit
      rm -rf make-4.3.tar.gz make-4.3
    fi
  fi
}

####################  升级gcc 的版本到8
gcc_upgrade() {
  gcc_version=$(gcc --version | grep -oP '(?<=gcc \(GCC\) )(\d+\.\d+.\d+)')
  # 检查是否为空（即 gcc 是否安装）
  if [ -z "$gcc_version" ] || [ "$gcc_version" != "8.3.1" ]; then
    echo -e "\e[31m正在升级gcc到8\e[0m"
    yum install -y centos-release-scl
    yum install -y devtoolset-8-gcc*
    mv /usr/bin/gcc /usr/bin/gcc-4.8.5
    ln -s /opt/rh/devtoolset-8/root/bin/gcc /usr/bin/gcc
    mv /usr/bin/g++ /usr/bin/g++-4.8.5
    ln -s /opt/rh/devtoolset-8/root/bin/g++ /usr/bin/g++
  else
    echo -e "\e[31mGCC version is greater 4.8.5.\e[0m"
  fi
}

# 安装 glibc-2.28
glibc_upgrade() {
  glibc_version=$(ldd --version | grep "2.28")
  if [ -z "$glibc_version" ]; then
    echo -e "\e[31mGlibc-2.28 is not installed.Installing glibc\e[0m"
    cd || exit
    #  wget http://ftp.gnu.org/gnu/glibc/glibc-2.28.tar.gz
    wget http://172.16.0.97:84/glibc/glibc-2.28.tar.gz
    tar xf glibc-2.28.tar.gz
    cd glibc-2.28/ && mkdir build && cd build || exit
    ../configure --prefix=/usr --disable-profile --enable-add-ons --with-headers=/usr/include --with-binutils=/usr/bin
    if [ "$?" = 127 ]; then
      nvm_echo "glibc-2.28 ../configure 失败"
      exit 1
    fi
    make && make install
    ldd --version
    cd || exit
    rm -rf glibc-2.28.tar.gz glibc-2.28
    # 设置语言环境变量
    sudo localedef -i zh_CN -f UTF-8 zh_CN.UTF-8
    sudo mandb
  fi
  echo -e "\e[31mInstalled glibc-2.28\e[0m"
}

# 升级libstdc++
# 问题：node: /usr/lib64/libstdc++.so.6: version `GLIBCXX_3.4.20' not found (required by node)
# 升级gcc时，生成的动态库没有替换老版本gcc的动态库。
libstdc_upgrade() {
  # strings查看有没有GLIBCXX_3.4.20
  libstdc_version=$(strings /usr/lib64/libstdc++.so.6 | grep GLIBC | grep GLIBCXX_3.4.20)
  if [ -z "$libstdc_version" ]; then
    cd || exit
    # 文件不存在则下载
    if [[ ! -e "/lib64/libstdc++.so.6.0.26" ]]; then
    #  sudo wget http://www.vuln.cn/wp-content/uploads/2019/08/libstdc.so_.6.0.26.zip
      sudo wget http://172.16.0.97:84/glibc/libstdc.so_.6.0.26.zip
      unzip libstdc.so_.6.0.26.zip
      cp libstdc++.so.6.0.26 /lib64/
    fi
    cd /lib64 || exit
    # 备份文件不存在
    if [[ ! -e "/lib64/libstdc++.so.6.bak" ]]; then
      # 把原来的命令做备份
      mv -f libstdc++.so.6 libstdc++.so.6.bak
    fi
    # 链接文件存在
    if [[ -e "/lib64/libstdc++.so.6" ]]; then
      rm -f libstdc++.so.6
    fi
    # 重新链接
    ln -s libstdc++.so.6.0.26 libstdc++.so.6
    # 移除多余的文件
    cd || exit
    rm -rf libstdc.so_.6.0.26.zip libstdc++.so.6.0.26
  fi
  echo -e "\e[31mInstalled libstdc.so_.6.0.26!\e[0m"
}

gcc_upgrade
make_upgrade
glibc_upgrade
libstdc_upgrade
