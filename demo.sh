#!/usr/bin/env bash

PORT=/dev/ttyUSB1
DIR=test_images
while true; do
	for img in "$DIR"/*.bmp; do
	  python scripts/push.py "$img" "$PORT"
	  sleep 3
	done
done

