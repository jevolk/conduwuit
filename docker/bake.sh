#!/bin/bash
set -eo pipefail

BASEDIR=$(dirname "$0")
bake_target=$@

CI=true
export DOCKER_BUILDKIT=1
if test "$CI" = true; then
	export BUILDKIT_PROGRESS="plain"
	echo "plain"
fi

default_uwu_id="jevolk/conduwuit"

uwu_id=${uwu_id:=$default_uwu_id}
uwu_acct=${uwu_acct:=$(echo $uwu_id | cut -d"/" -f1)}
uwu_repo=${uwu_repo:=$(echo $uwu_id | cut -d"/" -f2)}

###############################################################################

set -a
commands="check"
cargo_profiles='["test"]'
cargo_features="jemalloc,direct_tls,url_preview"
rust_toolchains='["nightly", "stable"]'
rust_targets='["x86_64-unknown-linux-gnu"]'
sys_targets='["x86_64-linux-gnu"]'
sys_versions='["testing-slim"]'
sys_names='["debian"]'

system="$systems"
runner_name=$(echo $RUNNER_NAME | cut -d"." -f1)
runner_num=$(echo $RUNNER_NAME | cut -d"." -f2)
cargo_verbose="${CI:=false}"
rocksdb_portable=1
git_checkout="HEAD"
use_chef="true"
complement_count=1
complement_skip="TestPartialStateJoin.*"
complement_skip="${complement_skip}|TestRoomDeleteAlias/Pa.*/Can_delete_canonical_alias"
complement_skip="${complement_skip}|TestUnbanViaInvite.*"
complement_skip="${complement_skip}|TestRoomDeleteAlias/Pa.*/Regular_users_can_add_and_delete_aliases_when.*"
complement_skip="${complement_skip}|TestToDeviceMessagesOverFederation/stopped_server"
set +a

###############################################################################

args="$uwu_docker_build_args"
args="$args --set *.platform=${sys_platform}"

if test ! -z "$runner_num"; then
	cpu_num=$(expr $runner_num % $(nproc))
	args="$args --cpuset-cpus=${cpu_num}"
	args="$args --set *.args.nprocs=1"
	# https://github.com/moby/buildkit/issues/1276
	:
else
	nprocs=$(nproc)
	args="$args --set *.args.nprocs=${nprocs}"
	:
fi

trap 'set +x; date; echo -e "\033[1;41;37mFAIL\033[0m"' ERR
date

arg="$args -f $BASEDIR/bake.hcl"
if test "$CI" = true; then
	docker buildx bake --print $arg $bake_target
fi

set -u -x
docker buildx bake $arg $bake_target
set +x

if test ! -z "$bake_target"; then
	exit 0
fi

image="smoketest-valgrind"
name_a="smoketest_valgrind"
arg="--rm --name $name_a -a stdout -a stderr $image"
set -x
#docker run $arg
set +x

date
image="smoketest-perf"
name_b="smoketest_perf"
arg="--rm --name $name_b -a stdout -a stderr --privileged $image"
set -x
#docker run $arg
set +x

image="complement-tester"
name_c="complement_tester"
sock="/var/run/docker.sock"
arg="--rm --name $name_c -v $sock:$sock -a stdout -a stderr --network=host $image"
set -x
docker run $arg
set +x

trap '' ERR
set -x +e
docker wait "$name_a" 2>/dev/null
docker wait "$name_b" 2>/dev/null
docker wait "$name_c" 2>/dev/null
set +x

echo -e "\033[1;42;37mPASS\033[0m"
