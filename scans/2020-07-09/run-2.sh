#!/bin/sh
myth -v 4 analyze -a $1 --rpc localhost:8545 -t 2 2>&1 | tee $1.log
