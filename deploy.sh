#!/usr/bin/env bash

set -e

# shards build --release --verbose

docker run --rm -it -v $(pwd):/workspace -w /workspace crystallang/crystal:latest-alpine \
    apk add sqlite && shards build --release --static

for i in $(seq 1 $(nproc --all)); do
  ./bin/test-kemal &
  sleep 0.1
done

wait

