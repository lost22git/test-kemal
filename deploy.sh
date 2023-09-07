#!/usr/bin/env bash

shards build --release --verbose

for i in $(seq 1 $(nproc --all)); do
  ./bin/test-kemal &
  sleep 0.1
done

wait

