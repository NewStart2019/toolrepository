#!/bin/bash
# -e：当一个命令返回非零退出状态（即失败）时，立即退出整个脚本。这有助于快速定位错误，因为任何失败都会导致脚本停止执行。
# -u 当尝试扩展一个未定义的变量时，将该行为视为错误并立即退出脚本
# -o pipefail：这是一个选项，它改变了管道命令中如何处理返回状态的方式。默认情况下，管道命令的返回状态是最后一个命令的退出状态，
# 即使前面的命令失败了也不会被注意到。使用 pipefail 选项后，如果管道中的任何一个命令失败了，整个管道的退出状态将是最后一个失败命令的退出状态
set -Eeuo pipefail

# ${1:0:1}字符串切片操作  获取第一个参数（$1）从索引 0 开始的 1 个字符
# set -- mongod "$@" 这行命令用于重置位置参数. set -- 后面跟着的是新的位置参数列表
# $@ 包括 $1, $2, ... 所有参数
if [ "${1:0:1}" = '-' ]; then
	set -- mongod "$@"
fi

originalArgOne="$1"

# [[ ]] 是 Bash 的关键字，提供更强大的条件测试功能, && 、 || 、 < 或 >; 对变量引用更加宽容。即使变量未定义或者为空，也不会导致语法错误
if [[ "$originalArgOne" == mongo* ]] && [ "$(id -u)" = '0' ]; then
	if [ "$originalArgOne" = 'mongod' ]; then
    #	 执行 find 命令，查找 /data/configdb 和 /data/db 目录下不属于用户 mongodb 的所有文件和目录，并将其所有者更改为 mongodb。
		find /data/configdb /data/db \! -user mongodb -exec chown mongodb '{}' +
	fi

	# 使用 chown 命令尝试将标准输出（文件描述符 1）和标准错误（文件描述符 2）的所有权更改为 mongodb 用户
  #	  --dereference 参数确保即使目标是一个符号链接，也会更改其指向的实际文件的所有权。
  #   || : 表示即使 chown 命令失败（例如，由于权限问题），脚本也不会因此退出或报错
	# (for our "initdb" code later; see "--logpath" below)
	chown --dereference mongodb "/proc/$$/fd/1" "/proc/$$/fd/2" || :
	# ignore errors thanks to https://github.com/docker-library/mongo/issues/149

  # exec gosu mongodb ...：使用 gosu 工具以 mongodb 用户的身份重新执行当前脚本（"$BASH_SOURCE" 指向当前脚本的路径）和传递给它的所有参数（"$@"）。
  #   gosu 是一个用于以指定用户身份运行程序的工具，常用于 Docker 容器中，以便正确地处理用户权限和环境隔离。
  #   exec 命令替换当前 shell 进程为新的命令进程，这意味着一旦执行了这条命令，当前 shell 将被新的命令所取代，而不是创建一个新的子进程。
	exec gosu mongodb "$BASH_SOURCE" "$@"
fi

dpkgArch="$(dpkg --print-architecture)"
case "$dpkgArch" in
	amd64) # https://github.com/docker-library/mongo/issues/485#issuecomment-891991814
		if ! grep -qE '^flags.* avx( .*|$)' /proc/cpuinfo; then
			{
				echo
				echo 'WARNING: MongoDB 5.0+ requires a CPU with AVX support, and your current system does not appear to have that!'
				echo '  see https://jira.mongodb.org/browse/SERVER-54407'
				echo '  see also https://www.mongodb.com/community/forums/t/mongodb-5-0-cpu-intel-g4650-compatibility/116610/2'
				echo '  see also https://github.com/docker-library/mongo/issues/485#issuecomment-891991814'
				echo
			} >&2
		fi
		;;

	arm64) # https://github.com/docker-library/mongo/issues/485#issuecomment-970864306
		# https://en.wikichip.org/wiki/arm/armv8#ARMv8_Extensions_and_Processor_Features
		# http://javathunderx.blogspot.com/2018/11/cheat-sheet-for-cpuinfo-features-on.html
		if ! grep -qE '^Features.* (fphp|dcpop|sha3|sm3|sm4|asimddp|sha512|sve)( .*|$)' /proc/cpuinfo; then
			{
				echo
				echo 'WARNING: MongoDB requires ARMv8.2-A or higher, and your current system does not appear to implement any of the common features for that!'
				echo '  applies to all versions ≥5.0, any of 4.4 ≥4.4.19'
				echo '  see https://jira.mongodb.org/browse/SERVER-71772'
				echo '  see https://jira.mongodb.org/browse/SERVER-55178'
				echo '  see also https://en.wikichip.org/wiki/arm/armv8#ARMv8_Extensions_and_Processor_Features'
				echo '  see also https://github.com/docker-library/mongo/issues/485#issuecomment-970864306'
				echo
			} >&2
		fi
		;;
esac

# you should use numactl to start your mongod instances, including the config servers, mongos instances, and any clients.
# https://docs.mongodb.com/manual/administration/production-notes/#configuring-numa-on-linux
if [[ "$originalArgOne" == mongo* ]]; then
  # numactl 是一个用于控制进程与 NUMA（非统一内存访问）策略交互方式的工具。--interleave=all 参数告诉 numactl 使用轮询方式在所有可用的
  #   NUMA 节点之间分配内存页面，这有助于提高性能特别是在多处理器或多节点内存架构上
	numa='numactl --interleave=all'

  #	$numa true 实际上会运行 numactl --interleave=all true，其中 true 是一个简单的命令，它总是成功退出。
  #  &> /dev/null 将标准输出和标准错误都重定向到 /dev/null，这意味着无论命令成功还是失败，
  #  检查 numactl 是否可用
	if $numa true &> /dev/null; then
		set -- $numa "$@"
	fi
fi

# usage: file_env VAR [DEFAULT]
#    ie: file_env 'XYZ_DB_PASSWORD' 'example'
# (will allow for "$XYZ_DB_PASSWORD_FILE" to fill in the value of
#  "$XYZ_DB_PASSWORD" from a file, especially for Docker's secrets feature)
file_env() {
	local var="$1"
	local fileVar="${var}_FILE"
	local def="${2:-}"
	if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
		echo >&2 "error: both $var and $fileVar are set (but are exclusive)"
		exit 1
	fi
	local val="$def"
	if [ "${!var:-}" ]; then
		val="${!var}"
	elif [ "${!fileVar:-}" ]; then
		val="$(< "${!fileVar}")"
	fi
	export "$var"="$val"
	unset "$fileVar"
}

# see https://github.com/docker-library/mongo/issues/147 (mongod is picky about duplicated arguments)
_mongod_hack_have_arg() {
	local checkArg="$1"; shift
	local arg
	for arg; do
		case "$arg" in
			"$checkArg"|"$checkArg"=*)
				return 0
				;;
		esac
	done
	return 1
}
# _mongod_hack_get_arg_val '--some-arg' "$@"
_mongod_hack_get_arg_val() {
	local checkArg="$1"; shift
	while [ "$#" -gt 0 ]; do
		local arg="$1"; shift
		case "$arg" in
			"$checkArg")
				echo "$1"
				return 0
				;;
			"$checkArg"=*)
				echo "${arg#$checkArg=}"
				return 0
				;;
		esac
	done
	return 1
}
declare -a mongodHackedArgs
# _mongod_hack_ensure_arg '--some-arg' "$@"
# set -- "${mongodHackedArgs[@]}"
_mongod_hack_ensure_arg() {
	local ensureArg="$1"; shift
	mongodHackedArgs=( "$@" )
	if ! _mongod_hack_have_arg "$ensureArg" "$@"; then
		mongodHackedArgs+=( "$ensureArg" )
	fi
}
# _mongod_hack_ensure_no_arg '--some-unwanted-arg' "$@"
# set -- "${mongodHackedArgs[@]}"
_mongod_hack_ensure_no_arg() {
	local ensureNoArg="$1"; shift
	mongodHackedArgs=()
	while [ "$#" -gt 0 ]; do
		local arg="$1"; shift
		if [ "$arg" = "$ensureNoArg" ]; then
			continue
		fi
		mongodHackedArgs+=( "$arg" )
	done
}
# _mongod_hack_ensure_no_arg '--some-unwanted-arg' "$@"
# set -- "${mongodHackedArgs[@]}"
_mongod_hack_ensure_no_arg_val() {
	local ensureNoArg="$1"; shift
	mongodHackedArgs=()
	while [ "$#" -gt 0 ]; do
		local arg="$1"; shift
		case "$arg" in
			"$ensureNoArg")
				shift # also skip the value
				continue
				;;
			"$ensureNoArg"=*)
				# value is already included
				continue
				;;
		esac
		mongodHackedArgs+=( "$arg" )
	done
}
# _mongod_hack_ensure_arg_val '--some-arg' 'some-val' "$@"
# set -- "${mongodHackedArgs[@]}"
_mongod_hack_ensure_arg_val() {
	local ensureArg="$1"; shift
	local ensureVal="$1"; shift
	_mongod_hack_ensure_no_arg_val "$ensureArg" "$@"
	mongodHackedArgs+=( "$ensureArg" "$ensureVal" )
}

# _js_escape 'some "string" value'
_js_escape() {
	jq --null-input --arg 'str' "$1" '$str'
}

# : 是一个空命令（null command），它不做任何操作但可以用于执行参数扩展而不影响脚本的逻辑。
# "${TMPDIR:=/tmp}"  TMPDIR 环境变量设置一个默认值
: "${TMPDIR:=/tmp}"
jsonConfigFile="$TMPDIR/docker-entrypoint-config.json"
tempConfigFile="$TMPDIR/docker-entrypoint-temp-config.json"
_parse_config() {
	if [ -s "$tempConfigFile" ]; then
		return 0
	fi

	local configPath
	if configPath="$(_mongod_hack_get_arg_val --config "$@")" && [ -s "$configPath" ]; then
		# if --config is specified, parse it into a JSON file so we can remove a few problematic keys (especially SSL-related keys)
		# see https://docs.mongodb.com/manual/reference/configuration-options/
		if grep -vEm1 '^[[:space:]]*(#|$)' "$configPath" | grep -qE '^[[:space:]]*[^=:]+[[:space:]]*='; then
			# if the first non-comment/non-blank line of the config file looks like "foo = ...", this is probably the 2.4 and older "ini-style config format"
			# mongod tries to parse config as yaml and then falls back to ini-style parsing
			# https://github.com/mongodb/mongo/blob/r6.0.3/src/mongo/util/options_parser/options_parser.cpp#L1883-L1894
			echo >&2
			echo >&2 "WARNING: it appears that '$configPath' is in the older INI-style format (replaced by YAML in MongoDB 2.6)"
			echo >&2 '  This script does not parse the older INI-style format, and thus will ignore it.'
			echo >&2
			return 1
		fi
		if [ "$mongoShell" = 'mongo' ]; then
			"$mongoShell" --norc --nodb --quiet --eval "load('/js-yaml.js'); printjson(jsyaml.load(cat($(_js_escape "$configPath"))))" > "$jsonConfigFile"
		else
			# https://www.mongodb.com/docs/manual/reference/method/js-native/#std-label-native-in-mongosh
			"$mongoShell" --norc --nodb --quiet --eval "load('/js-yaml.js'); JSON.stringify(jsyaml.load(fs.readFileSync($(_js_escape "$configPath"), 'utf8')))" > "$jsonConfigFile"
		fi
		if [ "$(head -c1 "$jsonConfigFile")" != '{' ] || [ "$(tail -c2 "$jsonConfigFile")" != '}' ]; then
			# if the file doesn't start with "{" and end with "}", it's *probably* an error ("uncaught exception: YAMLException: foo" for example), so we should print it out
			echo >&2 'error: unexpected "js-yaml.js" output while parsing config:'
			cat >&2 "$jsonConfigFile"
			exit 1
		fi
		jq 'del(.systemLog, .processManagement, .net, .security, .replication)' "$jsonConfigFile" > "$tempConfigFile"
		return 0
	fi

	return 1
}
dbPath=
_dbPath() {
	if [ -n "$dbPath" ]; then
		echo "$dbPath"
		return
	fi

	if ! dbPath="$(_mongod_hack_get_arg_val --dbpath "$@")"; then
		if _parse_config "$@"; then
			dbPath="$(jq -r '.storage.dbPath // empty' "$jsonConfigFile")"
		fi
	fi

	if [ -z "$dbPath" ]; then
		if _mongod_hack_have_arg --configsvr "$@" || {
			_parse_config "$@" \
			&& clusterRole="$(jq -r '.sharding.clusterRole // empty' "$jsonConfigFile")" \
			&& [ "$clusterRole" = 'configsvr' ]
		}; then
			# if running as config server, then the default dbpath is /data/configdb
			# https://docs.mongodb.com/manual/reference/program/mongod/#cmdoption-mongod-configsvr
			dbPath=/data/configdb
		fi
	fi

	: "${dbPath:=/data/db}"

	echo "$dbPath"
}

if [ "$originalArgOne" = 'mongod' ]; then
	file_env 'MONGO_INITDB_ROOT_USERNAME'
	file_env 'MONGO_INITDB_ROOT_PASSWORD'

	mongoShell='mongo'
	if ! command -v "$mongoShell" > /dev/null; then
		mongoShell='mongosh'
	fi

	# pre-check a few factors to see if it's even worth bothering with initdb
	shouldPerformInitdb=
	if [ "$MONGO_INITDB_ROOT_USERNAME" ] && [ "$MONGO_INITDB_ROOT_PASSWORD" ]; then
		# if we have a username/password, let's set "--auth"
		_mongod_hack_ensure_arg '--auth' "$@"
		set -- "${mongodHackedArgs[@]}"
		shouldPerformInitdb='true'
	elif [ "$MONGO_INITDB_ROOT_USERNAME" ] || [ "$MONGO_INITDB_ROOT_PASSWORD" ]; then
		cat >&2 <<-'EOF'

			error: missing 'MONGO_INITDB_ROOT_USERNAME' or 'MONGO_INITDB_ROOT_PASSWORD'
			       both must be specified for a user to be created

		EOF
		exit 1
	fi

	if [ -z "$shouldPerformInitdb" ]; then
		# if we've got any /docker-entrypoint-initdb.d/* files to parse later, we should initdb
		for f in /docker-entrypoint-initdb.d/*; do
			case "$f" in
				*.sh|*.js) # this should match the set of files we check for below
					shouldPerformInitdb="$f"
					break
					;;
			esac
		done
	fi

	# check for a few known paths (to determine whether we've already initialized and should thus skip our initdb scripts)
	if [ -n "$shouldPerformInitdb" ]; then
		dbPath="$(_dbPath "$@")"
		for path in \
			"$dbPath/WiredTiger" \
			"$dbPath/journal" \
			"$dbPath/local.0" \
			"$dbPath/storage.bson" \
		; do
			if [ -e "$path" ]; then
				shouldPerformInitdb=
				break
			fi
		done
	fi

	if [ -n "$shouldPerformInitdb" ]; then
		mongodHackedArgs=( "$@" )
		if _parse_config "$@"; then
			_mongod_hack_ensure_arg_val --config "$tempConfigFile" "${mongodHackedArgs[@]}"
		fi
		_mongod_hack_ensure_arg_val --bind_ip 127.0.0.1 "${mongodHackedArgs[@]}"
		_mongod_hack_ensure_arg_val --port 27017 "${mongodHackedArgs[@]}"
		_mongod_hack_ensure_no_arg --bind_ip_all "${mongodHackedArgs[@]}"

		# remove "--auth" and "--replSet" for our initial startup (see https://docs.mongodb.com/manual/tutorial/enable-authentication/#start-mongodb-without-access-control)
		# https://github.com/docker-library/mongo/issues/211
		_mongod_hack_ensure_no_arg --auth "${mongodHackedArgs[@]}"
		# "keyFile implies security.authorization"
		# https://docs.mongodb.com/manual/reference/configuration-options/#mongodb-setting-security.keyFile
		_mongod_hack_ensure_no_arg_val --keyFile "${mongodHackedArgs[@]}"
		if [ "$MONGO_INITDB_ROOT_USERNAME" ] && [ "$MONGO_INITDB_ROOT_PASSWORD" ]; then
			_mongod_hack_ensure_no_arg_val --replSet "${mongodHackedArgs[@]}"
		fi

		# "BadValue: need sslPEMKeyFile when SSL is enabled" vs "BadValue: need to enable SSL via the sslMode flag when using SSL configuration parameters"
		tlsMode='disabled'
		if _mongod_hack_have_arg '--tlsCertificateKeyFile' "$@"; then
			tlsMode='allowTLS'
		fi
		_mongod_hack_ensure_arg_val --tlsMode "$tlsMode" "${mongodHackedArgs[@]}"

		if stat "/proc/$$/fd/1" > /dev/null && [ -w "/proc/$$/fd/1" ]; then
			# https://github.com/mongodb/mongo/blob/38c0eb538d0fd390c6cb9ce9ae9894153f6e8ef5/src/mongo/db/initialize_server_global_state.cpp#L237-L251
			# https://github.com/docker-library/mongo/issues/164#issuecomment-293965668
			_mongod_hack_ensure_arg_val --logpath "/proc/$$/fd/1" "${mongodHackedArgs[@]}"
		else
			initdbLogPath="$(_dbPath "$@")/docker-initdb.log"
			echo >&2 "warning: initdb logs cannot write to '/proc/$$/fd/1', so they are in '$initdbLogPath' instead"
			_mongod_hack_ensure_arg_val --logpath "$initdbLogPath" "${mongodHackedArgs[@]}"
		fi
		_mongod_hack_ensure_arg --logappend "${mongodHackedArgs[@]}"

		pidfile="$TMPDIR/docker-entrypoint-temp-mongod.pid"
		rm -f "$pidfile"
		_mongod_hack_ensure_arg_val --pidfilepath "$pidfile" "${mongodHackedArgs[@]}"

		"${mongodHackedArgs[@]}" --fork

		mongo=( "$mongoShell" --host 127.0.0.1 --port 27017 --quiet )

		# check to see that our "mongod" actually did start up (catches "--help", "--version", slow prealloc, etc)
		# https://jira.mongodb.org/browse/SERVER-16292
		tries=30
		while true; do
			if ! { [ -s "$pidfile" ] && ps "$(< "$pidfile")" &> /dev/null; }; then
				# bail ASAP if "mongod" isn't even running
				echo >&2
				echo >&2 "error: $originalArgOne does not appear to have stayed running -- perhaps it had an error?"
				echo >&2
				exit 1
			fi
			if "${mongo[@]}" 'admin' --eval 'quit(0)' &> /dev/null; then
				# success!
				break
			fi
			(( tries-- ))
			if [ "$tries" -le 0 ]; then
				echo >&2
				echo >&2 "error: $originalArgOne does not appear to have accepted connections quickly enough -- perhaps it had an error?"
				echo >&2
				exit 1
			fi
			sleep 1
		done

		if [ "$MONGO_INITDB_ROOT_USERNAME" ] && [ "$MONGO_INITDB_ROOT_PASSWORD" ]; then
			rootAuthDatabase='admin'

			"${mongo[@]}" "$rootAuthDatabase" <<-EOJS
				db.createUser({
					user: $(_js_escape "$MONGO_INITDB_ROOT_USERNAME"),
					pwd: $(_js_escape "$MONGO_INITDB_ROOT_PASSWORD"),
					roles: [ { role: 'root', db: $(_js_escape "$rootAuthDatabase") } ]
				})
			EOJS
		fi

		export MONGO_INITDB_DATABASE="${MONGO_INITDB_DATABASE:-test}"

		echo
		for f in /docker-entrypoint-initdb.d/*; do
			case "$f" in
				*.sh) echo "$0: running $f"; . "$f" ;;
				*.js) echo "$0: running $f"; "${mongo[@]}" "$MONGO_INITDB_DATABASE" "$f"; echo ;;
				*)    echo "$0: ignoring $f" ;;
			esac
			echo
		done

		"${mongodHackedArgs[@]}" --shutdown
		rm -f "$pidfile"

		echo
		echo 'MongoDB init process complete; ready for start up.'
		echo
	fi

	# MongoDB defaults to localhost-only binding
	haveBindIp=
	if _mongod_hack_have_arg --bind_ip "$@" || _mongod_hack_have_arg --bind_ip_all "$@"; then
		haveBindIp=1
	elif _parse_config "$@" && jq --exit-status '.net.bindIp // .net.bindIpAll' "$jsonConfigFile" > /dev/null; then
		haveBindIp=1
	fi
	if [ -z "$haveBindIp" ]; then
		# so if no "--bind_ip" is specified, let's add "--bind_ip_all"
		set -- "$@" --bind_ip_all
	fi

	unset "${!MONGO_INITDB_@}"
fi

rm -f "$jsonConfigFile" "$tempConfigFile"

exec "$@"
