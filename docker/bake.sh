#!/bin/sh

BASEDIR=$(dirname "$0")

export DOCKER_BUILDKIT=1
if test "$CI" = true; then
	export BUILDKIT_PROGRESS="plain"
	echo "plain"
fi

default_uwu_id="jevolk/conduwuit"

uwu_id=${uwu_id:=$default_uwu_id}
uwu_acct=${uwu_acct:=$(echo $uwu_id | cut -d"/" -f1)}
uwu_repo=${uwu_repo:=$(echo $uwu_id | cut -d"/" -f2)}

default_uwu_commands="check"
default_uwu_profiles="dev"
default_uwu_features="default"
default_uwu_toolchains="nightly"
default_uwu_systems="rustlang/rust:nightly-slim"
default_uwu_machines="x86_64"

###############################################################################

uwu_command=${uwu_commands:=$default_uwu_commands}
uwu_profile=${uwu_profiles:=$default_uwu_profiles}
uwu_feature=${uwu_features:=$default_uwu_features}
uwu_toolchain=${uwu_toolchains:=$default_uwu_toolchains}
uwu_system=${uwu_systems:=$default_uwu_systems}
uwu_machine=${uwu_machines:=$default_uwu_machines}

sys_name=$(echo $uwu_system | cut -d":" -f1)
sys_version=$(echo $uwu_system | cut -d":" -f2)
runner_name=$(echo $RUNNER_NAME | cut -d"." -f1)
runner_num=$(echo $RUNNER_NAME | cut -d"." -f2)
rust_target="x86_64-unknown-linux-gnu"
rust_toolchain="nightly"
cargo_profile="dev"

args="$uwu_docker_build_args"
args="$args --set *.contexts.source='${BASEDIR}/..'"
args="$args --set *.contexts.cache_apt='/tmp/cache/apt'"
args="$args --set *.contexts.cache_reg='/tmp/cache/registry'"

if test ! -z "$runner_num"; then
	cpu_num=$(expr $runner_num % $(nproc))
	args="$args --cpuset-cpus=${cpu_num}"
	args="$args --set *.args.nprocs=1"
	# https://github.com/moby/buildkit/issues/1276
else
	nprocs=$(nproc)
	nprocs=4
	args="$args --set *.args.nprocs=${nprocs}"
fi

args="$args --set *.args.acct='${uwu_acct}'"
args="$args --set *.args.repo='${uwu_repo}'"

args="$args --set *.args.commands='${uwu_commands}'"
args="$args --set *.args.cargo_profiles='${uwu_profiles}'"
args="$args --set *.args.cargo_features='${uwu_features}'"
args="$args --set *.args.rust_toolchains='${uwu_toolchains}'"
args="$args --set *.args.systems='${uwu_systems}'"
args="$args --set *.args.machines='${uwu_machines}'"

args="$args --set *.args.sys_name='${sys_name}'"
args="$args --set *.args.sys_version='${sys_version}'"
args="$args --set *.args.cargo_profile='${cargo_profile}'"
args="$args --set *.args.rust_toolchain='${rust_toolchain}'"
args="$args --set *.args.rust_target='${rust_target}'"
args="$args --set *.args.rocksdb_version='9.10.0'"

if test "$mode" = "test"; then
	cmd=$(which echo)
else
	cmd=$(which docker)
fi

arg="buildx bake $args -f $BASEDIR/docker-bake.hcl"
eval "$cmd $arg"
if test $? -ne 0; then return 1; fi

# Push built
# eval "$cmd push $tag"
# if test $? -ne 0; then return 1; fi
 
