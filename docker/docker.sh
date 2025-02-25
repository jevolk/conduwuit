#!/bin/sh

BASEDIR=$(dirname "$0")
mode="test"

export DOCKER_BUILDKIT=1
if test "$CI" = true; then
	export BUILDKIT_PROGRESS="plain"
	echo "plain"
fi

default_uwu_url="https://github.com/jevolk/conduwuit"
default_uwu_id="jevolk/conduwuit"

uwu_url=${uwu_url:=$default_uwu_url}
uwu_id=${uwu_id:=$default_uwu_id}
uwu_acct=${uwu_acct:=$(echo $uwu_id | cut -d"/" -f1)}
uwu_repo=${uwu_repo:=$(echo $uwu_id | cut -d"/" -f2)}

default_uwu_commands="check"
default_uwu_profiles="dev"
default_uwu_features="--features=default"
default_uwu_toolchains="+nightly"
default_uwu_systems="ubuntu-24.10"
default_uwu_machines="x86_64"

###############################################################################

uwu_commands=${uwu_commands:=$default_uwu_commands}
uwu_profiles=${uwu_profiles:=$default_uwu_profiles}
uwu_features=${uwu_features:=$default_uwu_features}
uwu_toolchains=${uwu_toolchains:=$default_uwu_toolchains}
uwu_systems=${uwu_systems:=$default_uwu_systems}
uwu_machines=${uwu_machines:=$default_uwu_machines}

dist_name=$(echo $system | cut -d"-" -f1)
dist_version=$(echo $system | cut -d"-" -f2)
runner_name=$(echo $RUNNER_NAME | cut -d"." -f1)
runner_num=$(echo $RUNNER_NAME | cut -d"." -f2)

args="$uwu_docker_build_args"

if test ! -z "$runner_num"; then
	cpu_num=$(expr $runner_num % $(nproc))
	#args="$args --cpuset-cpus=${cpu_num}"
	#args="$args --set nprocs=1"
	# https://github.com/moby/buildkit/issues/1276
else
	nprocs=$(nproc)
	#args="$args --set nprocs=${nprocs}"
fi

args="$args --set *.args.acct=${uwu_acct}"
args="$args --set *.args.repo=${uwu_repo}"
args="$args --set *.args.uwu_url=${uwu_url}"
args="$args --set *.args.dist_name=${dist_name}"
args="$args --set *.args.dist_version=${dist_version}"
args="$args --set *.args.cargo_commands=${uwu_commands}"
args="$args --set *.args.cargo_profiles=${uwu_profiles}"
args="$args --set *.args.cargo_features=${uwu_features}"
args="$args --set *.args.rust_toolchains=${uwu_toolchains}"
args="$args --set *.args.systems=${uwu_systems}"
args="$args --set *.args.machines=${uwu_machines}"

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
