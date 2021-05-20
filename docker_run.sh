#!/bin/bash
KERNEL_VERSION=$VER
FUZZ_TIME="86700"
	for R in {1...10}
	do
		timeout 86700  docker run --env ROUND=$R -v /linux/$VER:/share fuzzer  /eva/eva/run.sh 
	done


