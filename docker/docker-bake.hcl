variable "acct" {}
variable "repo" {}
variable "uwu_url" {}
variable "dist_name" {}
variable "dist_version" {}

variable "sauces" {}
variable "cargo_commands" {}
variable "cargo_profiles" {}
variable "cargo_features" {}
variable "rust_toolchains" {}
variable "systems" {}
variable "machines" {}

target "default" {
	inherits = ["complement"]
}

### sauces

target "complement" {
	inherits = ["static-base-test","keys"]
	tags = ["conduwuit-complement:latest"]
}

target "keys" {
	dockerfile = "Dockerfile.keys"
	output = ["type=cacheonly"]
}

### shared

group "shared" {
	targets = [""]
}

target "shared-test" {
	inherits = ["shared-base"]
	output = ["type=image"]
	args = {
		CARGO_PROFILE = "test"
	}
}

target "shared-base" {
	dockerfile = "Dockerfile.shared.base"
	output = ["type=cacheonly"]
}

### static

group "static" {
	targets = ["static-base-test"]
}

target "static-base-test" {
	inherits = ["static-base-profile-test","keys"]
	dockerfile = "Dockerfile.test-main"
	contexts = {
		base = "target:static-base-profile-test"
		keys = "target:keys"
	}
}

target "static-base-profile-test"{
	inherits = ["static-base"]
	args = {
		CARGO_PROFILE = "test-max-perf"
	}
}

target "static-base" {
	dockerfile = "Dockerfile.static.base"
	output = ["type=cacheonly"]
	contexts = {
		rocksdb = "target:rocksdb-shared"
	}
}

### rocksdb

target "rocksdb-shared" {
	inherits = ["rocksdb-base"]
	tags = ["rocksdb-compiled-shared:v9.9.3"]
	args = {
		ROCKS_DB_TARGET = "shared_lib"
	}
}

target "rocksdb-static" {
	inherits = ["rocksdb-base"]
	tags = ["rocksdb-compiled-static:v9.9.3"]
	args = {
		ROCKS_DB_TARGET = "static_lib"
	}
}

target "rocksdb-base" {
	dockerfile = "Dockerfile.rocksdb"
}
