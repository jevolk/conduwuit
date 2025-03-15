variable "acct" {}
variable "repo" {}

variable "commands" {}

variable "cargo_profiles" {
	default = "[\"test\", \"bench\"]"
}
variable "cargo_features" {
	default = "jemalloc,direct_tls"
}
variable "rust_toolchains" {
	default = "[\"nightly\", \"stable\"]"
}
variable "rust_targets" {
	default = "[\"x86_64-unknown-linux-gnu\"]"
}
variable "sys_targets" {
	default = "[\"x86_64-linux-gnu\"]"
}
variable "sys_versions" {
	default = "[\"testing-slim\"]"
}
variable "sys_names" {
	default = "[\"debian\"]"
}

# RocksDB options
variable "rocksdb_portable" {
	default = 1
}

# Complement options
variable "complement_count" {
	default = 1
}
variable "complement_debug" {
	default = 0
}
variable "complement_run" {
	default = ".*"
}
variable "complement_skip" {
	default = ""
}

# Package metadata inputs
variable "package_name" {
	default = "conduwuit"
}
variable "package_authors" {
	default = "June Clementine Strawberry <june@girlboss.ceo> and Jason Volk <jason@zemos.net>"
}
variable "package_version" {
	default = "0.5"
}
variable "package_revision" {
	default = ""
}
variable "package_last_modified" {
	default = ""
}

# Use the cargo-chef layering strategy to separate and pre-build dependencies
# in a lower-layer image; only workspace crates will rebuild unless
# dependencies themselves change (default). This option can be set to false for
# bypassing chef, building within a single layer.
variable "use_chef" {
	default = "true"
}

# Options for output verbosity
variable "BUILDKIT_PROGRESS" {}
variable "cargo_verbose_arg" {
	default = equal(BUILDKIT_PROGRESS, "plain")? "--verbose": ""
}

# Override the project checkout
variable "git_checkout" {
	default = "HEAD"
}

###############################################################################
#
# Default
#

group "default" {
	targets = [
		"lints",
		"tests",
	]
}

group "lints" {
	targets = [
		"clippy",
	]
}

group "tests" {
	targets = [
		"tests-unit",
		"tests-smoke",
		"complement-testee",
		"complement-tester",
	]
}

#
# Complement tests
#

target "complement-tester" {
	name = "complement-tester--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	tags = ["complement-tester"]
	target = "complement-tester"
	output = ["type=docker,compression=zstd"]
	cache_to = ["type=local,mode=max"]
	entitlements = ["network.host"]
	matrix = {
		cargo_profile = jsondecode(cargo_profiles)
		rust_toolchain = jsondecode(rust_toolchains)
		rust_target = jsondecode(rust_targets)
		sys_name = jsondecode(sys_names)
		sys_version = jsondecode(sys_versions)
		sys_target = jsondecode(sys_targets)
	}
	inherits = [
		"complement-runner--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	]
	contexts = {
		input = "target:complement-runner--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
		complement-testee = "target:complement-testee--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	}
}

target "complement-runner" {
	name = "complement-runner--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	target = "complement-runner"
	matrix = {
		cargo_profile = jsondecode(cargo_profiles)
		rust_toolchain = jsondecode(rust_toolchains)
		rust_target = jsondecode(rust_targets)
		sys_name = jsondecode(sys_names)
		sys_version = jsondecode(sys_versions)
		sys_target = jsondecode(sys_targets)
	}
	inherits = [
		"complement-base--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	]
	contexts = {
		input = "target:complement-base--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	}
	args = {
		complement_count = "${complement_count}"
		complement_debug = "${complement_debug}"
		complement_run = "${complement_run}"
		complement_skip = "${complement_skip}"
	}
}

target "complement-base" {
	name = "complement-base--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	target = "complement-base"
	output = ["type=cacheonly"]
	matrix = {
		cargo_profile = jsondecode(cargo_profiles)
		rust_toolchain = jsondecode(rust_toolchains)
		rust_target = jsondecode(rust_targets)
		sys_name = jsondecode(sys_names)
		sys_version = jsondecode(sys_versions)
		sys_target = jsondecode(sys_targets)
	}
	inherits = [
		"complement-testee--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	]
	contexts = {
		input = "target:diner--${sys_name}--${sys_version}--${sys_target}"
	}
}

target "complement-testee" {
	name = "complement-testee--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	tags = ["complement-testee"]
	target = "complement-testee"
	output = ["type=docker,compression=zstd"]
	cache_to = ["type=local,mode=max"]
	entitlements = ["network.host"]
	dockerfile = "docker/Dockerfile.complement"
	matrix = {
		cargo_profile = jsondecode(cargo_profiles)
		rust_toolchain = jsondecode(rust_toolchains)
		rust_target = jsondecode(rust_targets)
		sys_name = jsondecode(sys_names)
		sys_version = jsondecode(sys_versions)
		sys_target = jsondecode(sys_targets)
	}
	inherits = [
		"smoketest--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	]
	contexts = {
		input = "target:install--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
		build = "target:build-bins--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
		smoketest = "target:smoketest-startup--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	}
}

target "complement-config" {
	name = "complement-config--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	target = "complement-config"
	output = ["type=cacheonly"]
	cache_to = ["type=local,mode=max"]
	dockerfile = "docker/Dockerfile.complement"
	matrix = {
		cargo_profile = jsondecode(cargo_profiles)
		rust_toolchain = jsondecode(rust_toolchains)
		rust_target = jsondecode(rust_targets)
		sys_name = jsondecode(sys_names)
		sys_version = jsondecode(sys_versions)
		sys_target = jsondecode(sys_targets)
	}
	inherits = [
		"smoketest--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	]
	contexts = {
		build = "target:build-bins--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	}
}

#
# Smoke tests
#

group "tests-smoke" {
	targets = [
		"smoketest-version",
		"smoketest-startup",
		"smoketest-valgrind",
		"smoketest-perf",
	]
}

target "smoketest-valgrind" {
	name = "smoketest-valgrind--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	target = "smoketest-valgrind"
	tags = ["smoketest-valgrind"]
	cache_to = ["type=local,mode=max"]
	entitlements = ["security.insecure"]
	matrix = {
		cargo_profile = jsondecode(cargo_profiles)
		rust_toolchain = jsondecode(rust_toolchains)
		rust_target = jsondecode(rust_targets)
		sys_name = jsondecode(sys_names)
		sys_version = jsondecode(sys_versions)
		sys_target = jsondecode(sys_targets)
	}
	inherits = [
		"smoketest--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	]
}

target "smoketest-perf" {
	name = "smoketest-perf--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	tags = ["smoketest-perf"]
	target = "smoketest-perf"
	cache_to = ["type=local,mode=max"]
	entitlements = ["security.insecure"]
	matrix = {
		cargo_profile = jsondecode(cargo_profiles)
		rust_toolchain = jsondecode(rust_toolchains)
		rust_target = jsondecode(rust_targets)
		sys_name = jsondecode(sys_names)
		sys_version = jsondecode(sys_versions)
		sys_target = jsondecode(sys_targets)
	}
	inherits = [
		"smoketest--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	]
}

target "smoketest-startup" {
	name = "smoketest-startup--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	target = "smoketest-startup"
	matrix = {
		cargo_profile = jsondecode(cargo_profiles)
		rust_toolchain = jsondecode(rust_toolchains)
		rust_target = jsondecode(rust_targets)
		sys_name = jsondecode(sys_names)
		sys_version = jsondecode(sys_versions)
		sys_target = jsondecode(sys_targets)
	}
	inherits = [
		"smoketest--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	]
}

target "smoketest-version" {
	name = "smoketest-version--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	target = "smoketest-version"
	matrix = {
		cargo_profile = jsondecode(cargo_profiles)
		rust_toolchain = jsondecode(rust_toolchains)
		rust_target = jsondecode(rust_targets)
		sys_name = jsondecode(sys_names)
		sys_version = jsondecode(sys_versions)
		sys_target = jsondecode(sys_targets)
	}
	inherits = [
		"smoketest--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	]
}

target "smoketest" {
	name = "smoketest--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	output = ["type=image"]
	cache_to = ["type=local,mode=max"]
	dockerfile = "docker/Dockerfile.smoketest"
	matrix = {
		cargo_profile = jsondecode(cargo_profiles)
		rust_toolchain = jsondecode(rust_toolchains)
		rust_target = jsondecode(rust_targets)
		sys_name = jsondecode(sys_names)
		sys_version = jsondecode(sys_versions)
		sys_target = jsondecode(sys_targets)
	}
	inherits = [
		"install--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}",
	]
	contexts = {
		input = "target:install--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	}
}

#
# Installation
#

target "install" {
	name = "install--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	target = "install"
	output = ["type=image"]
	cache_to = ["type=local,mode=max"]
	dockerfile = "docker/Dockerfile.install"
	matrix = {
		cargo_profile = jsondecode(cargo_profiles)
		rust_toolchain = jsondecode(rust_toolchains)
		rust_target = jsondecode(rust_targets)
		sys_name = jsondecode(sys_names)
		sys_version = jsondecode(sys_versions)
		sys_target = jsondecode(sys_targets)
	}
	inherits = [
		"build-bins--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}",
	]
	contexts = {
		input = "target:diner--${sys_name}--${sys_version}--${sys_target}"
		build = "target:build-bins--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}",
	}
	labels = {
		"org.opencontainers.image.authors" = "${package_authors}"
		"org.opencontainers.image.created" ="${package_last_modified}"
		"org.opencontainers.image.description" = "a very cool Matrix chat homeserver written in Rust"
		"org.opencontainers.image.documentation" = "https://conduwuit.puppyirl.gay/"
		"org.opencontainers.image.licenses" = "Apache-2.0"
		"org.opencontainers.image.revision" = "${package_revision}"
		"org.opencontainers.image.source" = "https://github.com/girlbossceo/conduwuit"
		"org.opencontainers.image.title" = "${package_name}"
		"org.opencontainers.image.url" = "https://conduwuit.puppyirl.gay/"
		"org.opencontainers.image.vendor" = "girlbossceo"
		"org.opencontainers.image.version" = "${package_version}"
	}
}

#
# Unit tests
#

target "tests-unit" {
	name = "tests-unit--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	target = "unittest"
	output = ["type=image"]
	cache_to = ["type=local,mode=max"]
	dockerfile = "docker/Dockerfile.unittest"
	matrix = {
		cargo_profile = jsondecode(cargo_profiles)
		rust_toolchain = jsondecode(rust_toolchains)
		rust_target = jsondecode(rust_targets)
		sys_name = jsondecode(sys_names)
		sys_version = jsondecode(sys_versions)
		sys_target = jsondecode(sys_targets)
	}
	inherits = [
		"build-tests--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}",
	]
	contexts = {
		input = "target:cookware--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
		build-tests = "target:build-tests--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	}
	args = {
		cargo_test_nocapture = ""
	}
}

#
# Workspace builds
#

target "build-bins" {
	name = "build-bins--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	matrix = {
		cargo_profile = jsondecode(cargo_profiles)
		rust_toolchain = jsondecode(rust_toolchains)
		rust_target = jsondecode(rust_targets)
		sys_name = jsondecode(sys_names)
		sys_version = jsondecode(sys_versions)
		sys_target = jsondecode(sys_targets)
	}
	inherits = [
		"deps-build--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}",
		"build--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}",
	]
	contexts = {
		input = equal("true", use_chef)? "target:deps-build--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}": "target:build--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	}
	args = {
		cargo_args = "build --bins"
	}
}

target "build-tests" {
	name = "build-tests--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	matrix = {
		cargo_profile = jsondecode(cargo_profiles)
		rust_toolchain = jsondecode(rust_toolchains)
		rust_target = jsondecode(rust_targets)
		sys_name = jsondecode(sys_names)
		sys_version = jsondecode(sys_versions)
		sys_target = jsondecode(sys_targets)
	}
	inherits = [
		"deps-build--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}",
		"build--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}",
	]
	contexts = {
		input = equal("true", use_chef)? "target:deps-build--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}": "target:build--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	}
	args = {
		cargo_args = "build --tests"
	}
}

target "build" {
	name = "build--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	matrix = {
		cargo_profile = jsondecode(cargo_profiles)
		rust_toolchain = jsondecode(rust_toolchains)
		rust_target = jsondecode(rust_targets)
		sys_name = jsondecode(sys_names)
		sys_version = jsondecode(sys_versions)
		sys_target = jsondecode(sys_targets)
	}
	inherits = [
		"deps-build--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}",
		"cargo--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}",
	]
	contexts = {
		input = equal("true", use_chef)? "target:deps-build--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}": "target:ingredients--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	}
	args = {
		cargo_args = "build --all-targets"
	}
}

target "clippy" {
	name = "clippy--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	matrix = {
		cargo_profile = jsondecode(cargo_profiles)
		rust_toolchain = jsondecode(rust_toolchains)
		rust_target = jsondecode(rust_targets)
		sys_name = jsondecode(sys_names)
		sys_version = jsondecode(sys_versions)
		sys_target = jsondecode(sys_targets)
	}
	inherits = [
		"deps-clippy--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}",
		"cargo--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}",
	]
	contexts = {
		input = equal("true", use_chef)? "target:deps-clippy--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}": "target:ingredients--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	}
	args = {
		cargo_args = "clippy --all-targets --no-deps"
		cargo_pass = "-- -D warnings"
	}
}

target "check" {
	name = "check--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	matrix = {
		cargo_profile = jsondecode(cargo_profiles)
		rust_toolchain = jsondecode(rust_toolchains)
		rust_target = jsondecode(rust_targets)
		sys_name = jsondecode(sys_names)
		sys_version = jsondecode(sys_versions)
		sys_target = jsondecode(sys_targets)
	}
	inherits = [
		"deps-check--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}",
		"cargo--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}",
	]
	contexts = {
		input = equal("true", use_chef)? "target:deps-check--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}": "target:ingredients--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	}
	args = {
		cargo_args = "check --all-targets"
	}
}

target "cargo" {
	name = "cargo--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	target = "cargo"
	output = ["type=cacheonly"]
	cache_to = ["type=local,mode=max"]
	dockerfile = "docker/Dockerfile.cargo"
	matrix = {
		cargo_profile = jsondecode(cargo_profiles)
		rust_toolchain = jsondecode(rust_toolchains)
		rust_target = jsondecode(rust_targets)
		sys_name = jsondecode(sys_names)
		sys_version = jsondecode(sys_versions)
		sys_target = jsondecode(sys_targets)
	}
	inherits = [
		"deps-base--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	]
}

#
# Dependency builds
#

target "deps-build" {
	name = "deps-build--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	tags = ["deps-build"]
	matrix = {
		cargo_profile = jsondecode(cargo_profiles)
		rust_toolchain = jsondecode(rust_toolchains)
		rust_target = jsondecode(rust_targets)
		sys_name = jsondecode(sys_names)
		sys_version = jsondecode(sys_versions)
		sys_target = jsondecode(sys_targets)
	}
	inherits = [
		"deps-base--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	]
	args = {
		cook_args = "--all-targets"
	}
}

target "deps-clippy" {
	name = "deps-clippy--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	matrix = {
		cargo_profile = jsondecode(cargo_profiles)
		rust_toolchain = jsondecode(rust_toolchains)
		rust_target = jsondecode(rust_targets)
		sys_name = jsondecode(sys_names)
		sys_version = jsondecode(sys_versions)
		sys_target = jsondecode(sys_targets)
	}
	inherits = [
		"deps-base--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	]
	args = {
		cook_args = "--all-targets --clippy"
	}
}

target "deps-check" {
	name = "deps-check--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	matrix = {
		cargo_profile = jsondecode(cargo_profiles)
		rust_toolchain = jsondecode(rust_toolchains)
		rust_target = jsondecode(rust_targets)
		sys_name = jsondecode(sys_names)
		sys_version = jsondecode(sys_versions)
		sys_target = jsondecode(sys_targets)
	}
	inherits = [
		"deps-base--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	]
	args = {
		cook_args = "--all-targets --check"
	}
}

target "deps-base" {
	name = "deps-base--${cargo_profile}--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	target = "chef"
	output = ["type=cacheonly"]
	dockerfile = "docker/Dockerfile.deps"
	matrix = {
		cargo_profile = jsondecode(cargo_profiles)
		rust_toolchain = jsondecode(rust_toolchains)
		rust_target = jsondecode(rust_targets)
		sys_name = jsondecode(sys_names)
		sys_version = jsondecode(sys_versions)
		sys_target = jsondecode(sys_targets)
	}
	inherits = [
		"recipe--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	]
	contexts = {
		input = "target:ingredients--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
		recipe = "target:recipe--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
		rocksdb = "target:rocksdb--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	}
	args = {
		cargo_profile = cargo_profile
		cargo_features = "${cargo_features}"
		cook_args = "--all-targets --no-build"
	}
}

#
# Special-cased dependency builds
#

target "rocksdb" {
	name = "rocksdb--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	target = "rocksdb"
	output = ["type=docker,compression=zstd"]
	cache_to = ["type=local,mode=max"]
	matrix = {
		rust_toolchain = jsondecode(rust_toolchains)
		rust_target = jsondecode(rust_targets)
		sys_name = jsondecode(sys_names)
		sys_version = jsondecode(sys_versions)
		sys_target = jsondecode(sys_targets)
	}
	inherits = [
		"rocksdb-build--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	]
	contexts = {
		input = "target:rocksdb-build--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	}
}

target "rocksdb-build" {
	name = "rocksdb-build--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	target = "rocksdb-build"
	matrix = {
		rust_toolchain = jsondecode(rust_toolchains)
		rust_target = jsondecode(rust_targets)
		sys_name = jsondecode(sys_names)
		sys_version = jsondecode(sys_versions)
		sys_target = jsondecode(sys_targets)
	}
	inherits = [
		"rocksdb-fetch--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	]
	contexts = {
		input = "target:rocksdb-fetch--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	}
	args = {
		rocksdb_portable = "${rocksdb_portable}"
		rocksdb_shared = 0
	}
}

target "rocksdb-fetch" {
	name = "rocksdb-fetch--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	target = "rocksdb-fetch"
	output = ["type=cacheonly"]
	cache_to = ["type=inline,mode=max"]
	dockerfile = "docker/Dockerfile.rocksdb"
	matrix = {
		rust_toolchain = jsondecode(rust_toolchains)
		rust_target = jsondecode(rust_targets)
		sys_name = jsondecode(sys_names)
		sys_version = jsondecode(sys_versions)
		sys_target = jsondecode(sys_targets)
	}
	inherits = [
		"recipe--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}",
		"kitchen--${sys_name}--${sys_version}--${sys_target}",
	]
	contexts = {
		input = "target:kitchen--${sys_name}--${sys_version}--${sys_target}"
		recipe = "target:recipe--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	}
}

#
# Source acquisition and processing
#

target "recipe" {
	name = "recipe--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	target =  "recipe"
	output = ["type=image"]
	matrix = {
		rust_toolchain = jsondecode(rust_toolchains)
		rust_target = jsondecode(rust_targets)
		sys_name = jsondecode(sys_names)
		sys_version = jsondecode(sys_versions)
		sys_target = jsondecode(sys_targets)
	}
	inherits = [
		"preparing--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	]
	contexts = {
		input = "target:preparing--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	}
}

target "preparing" {
	name = "preparing--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	target =  "preparing"
	output = ["type=cacheonly"]
	matrix = {
		rust_toolchain = jsondecode(rust_toolchains)
		rust_target = jsondecode(rust_targets)
		sys_name = jsondecode(sys_names)
		sys_version = jsondecode(sys_versions)
		sys_target = jsondecode(sys_targets)
	}
	inherits = [
		"ingredients--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	]
	contexts = {
		input = "target:ingredients--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	}
}

target "ingredients" {
	name = "ingredients--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	target =  "ingredients"
	output = ["type=image"]
	cache_to = ["type=local,mode=max"]
	dockerfile = "docker/Dockerfile.ingredients"
	matrix = {
		rust_toolchain = jsondecode(rust_toolchains)
		rust_target = jsondecode(rust_targets)
		sys_name = jsondecode(sys_names)
		sys_version = jsondecode(sys_versions)
		sys_target = jsondecode(sys_targets)
	}
	inherits = [
		"chef--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	]
	contexts = {
		input = "target:chef--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	}
	args = {
		cargo_target_dir = "/usr/src/conduwuit/target/${sys_name}/${sys_version}/${rust_toolchain}"
		cargo_verbose_arg = "${cargo_verbose_arg}"
		git_checkout = "${git_checkout}"
	}
}

#
# Rust build environment
#

target "chef" {
	name = "chef--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	target = "chef"
	dockerfile = "docker/Dockerfile.chef"
	matrix = {
		rust_toolchain = jsondecode(rust_toolchains)
		rust_target = jsondecode(rust_targets)
		sys_name = jsondecode(sys_names)
		sys_version = jsondecode(sys_versions)
		sys_target = jsondecode(sys_targets)
	}
	inherits = [
		"cookware--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	]
	contexts = {
		input = "target:cookware--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	}
}

target "cookware" {
	name = "cookware--${rust_toolchain}--${rust_target}--${sys_name}--${sys_version}--${sys_target}"
	target = "cookware"
	dockerfile = "docker/Dockerfile.cookware"
	matrix = {
		rust_toolchain = jsondecode(rust_toolchains)
		rust_target = jsondecode(rust_targets)
		sys_name = jsondecode(sys_names)
		sys_version = jsondecode(sys_versions)
		sys_target = jsondecode(sys_targets)
	}
	inherits = [
		"kitchen--${sys_name}--${sys_version}--${sys_target}"
	]
	contexts = {
		input = "target:kitchen--${sys_name}--${sys_version}--${sys_target}"
	}
	args = {
		rust_toolchain = rust_toolchain
		rust_target = rust_target
		rust_home = "/opt/rustup"
		cargo_home = "/opt/${sys_name}/${sys_target}/cargo"
	}
}

#
# Base systems
#

target "kitchen" {
	description = "Base build environment; sans Rust"
	name = "kitchen--${sys_name}--${sys_version}--${sys_target}"
	target = "kitchen"
	dockerfile = "docker/Dockerfile.kitchen"
	matrix = {
		sys_name = jsondecode(sys_names)
		sys_version = jsondecode(sys_versions)
		sys_target = jsondecode(sys_targets)
	}
	inherits = [
		"diner--${sys_name}--${sys_version}--${sys_target}"
	]
	contexts = {
		input = "target:diner--${sys_name}--${sys_version}--${sys_target}"
	}
}

target "diner" {
	description = "Base runtime environment for executing the application."
	name = "diner--${sys_name}--${sys_version}--${sys_target}"
	target = "diner"
	matrix = {
		sys_name = jsondecode(sys_names)
		sys_version = jsondecode(sys_versions)
		sys_target = jsondecode(sys_targets)
	}
	inherits = [
		"system--${sys_name}--${sys_version}--${sys_target}"
	]
	args = {
		var_cache = "/var/cache"
		var_lib_apt = "/var/lib/apt"
	}
}

target "system" {
	description = "Base system. Root of all our layers."
	name = "system--${sys_name}--${sys_version}--${sys_target}"
	target = "system"
	output = ["type=docker,compression=zstd"]
	cache_to = ["type=local,mode=max"]
	cache_from = ["type=local"]
	dockerfile = "docker/Dockerfile.diner"
	context = "."
	matrix = {
		sys_name = jsondecode(sys_names)
		sys_version = jsondecode(sys_versions)
		sys_target = jsondecode(sys_targets)
	}
	args = {
		sys_name = sys_name
		sys_version = sys_version
		sys_target = sys_target
	}
}
