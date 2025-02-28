variable "acct" {}
variable "repo" {}

variable "source" {}
variable "cache_apt" {}
variable "cache_reg" {}

variable "sauces" {}
variable "commands" {}
variable "cargo_profiles" {}
variable "cargo_features" {}
variable "rust_toolchains" {}
variable "systems" {}
variable "machines" {}

variable "sys_name" {}
variable "sys_version" {}
variable "cargo_profile" {}
variable "rust_toolchain" {}
variable "rust_target" {}
variable "rocksdb_version" {}

target "default" {
	inherits = ["shared-test"]
}

group "shared" {
	targets = ["shared-check", "shared-clippy", "shared-build", "shared-test"]
}

target "shared-test" {
	inherits = ["shared-build"]
	contexts = {
		rocksdb = "target:rocksdb"
		build = "target:shared-build"
		clippy = "target:shared-clippy"
		check = "target:shared-check"
	}

	args = {
		cook_args = "--workspace --tests"
	}

	output = ["type=cacheonly"]
	tags = [
		"shared-test"
	]
}

target "shared-build" {
	inherits = ["shared-clippy"]
	contexts = {
		rocksdb = "target:rocksdb"
		clippy = "target:shared-clippy"
		check = "target:shared-check"
	}

	args = {
		cook_args = "--workspace"
	}

	output = ["type=image"]
	tags = [
		"shared-build"
	]
}

target "shared-clippy" {
	inherits = ["shared-check"]
	contexts = {
		rocksdb = "target:rocksdb"
		check = "target:shared-check"
	}

	args = {
		cook_args = "--workspace --all-targets --clippy"
	}

	tags = [
		"shared-clippy"
	]
}

target "shared-check" {
	context = "."
	dockerfile = "docker/Dockerfile.shared"
	contexts = {
		rocksdb = "target:rocksdb"
	}

	args = {
		sys_name = "${sys_name}"
		sys_version = "${sys_version}"
		cargo_profile = "${cargo_profile}"
		rust_toolchain = "${rust_toolchain}"
		rust_target = "${rust_target}"
		cook_args = "--workspace --all-targets --check"
	}

	output = ["type=cacheonly"]
	tags = [
		"shared-check"
	]
}

target "rocksdb" {
	context = "."
	dockerfile = "docker/Dockerfile.rocksdb"

	args = {
		sys_name = "${sys_name}"
		sys_version = "${sys_version}"
		rocksdb_version = "${rocksdb_version}"
	}

	output = ["type=image"]
	tags = [
		"rocksdb"
	]
}
