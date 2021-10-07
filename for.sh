#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

while read val; do
	echo -e "\n${YELLOW}$val${NC}"
	$(pwd)/broke.sh $val 2 50
done<$(pwd)/targ.txt