#!/bin/bash

CHANNEL_NAME=AssetAtom TIMEOUT=10000 docker-compose -f docker-compose-cli.yaml up -d
docker exec -it cli bash
