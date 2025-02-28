#!/bin/bash
# Builds base file
cargo vendor ./.docker-home >  ./.docker-home/.cargo-config.toml
pushd ./dockerfiles
docker buildx build -f ./Dockerfile.base -t conduwuit-base:latest ../ --progress=plain 2>&1 | tee build.log 
# Builds test file
docker buildx build -f ./Dockerfile.test-main -t conduwuit-test:latest ../
# Builds complement
popd
