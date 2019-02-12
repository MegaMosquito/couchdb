#!/bin/bash

ADDRESS='192.168.123.3'
SOURCE_PORT=5984
TARGET_PORT=5985
USER="admin"
PASSWORD="p4ssw0rd"
DATABASE="lan_hosts"

SOURCE="${DATABASE}"
TARGET="http://${ADDRESS}:${TARGET_PORT}/${DATABASE}"
STT_DATA="{\"source\":\"${SOURCE}\",\"target\":\"${TARGET}\"}"
#echo "${STT_DATA}"
TTS_DATA="{\"source\":\"${TARGET}\",\"target\":\"${SOURCE}\"}"
#echo "${TTS_DATA}"

HEADERS="Content-Type: application/json"
URL="http://${USER}:${PASSWORD}@${ADDRESS}:${SOURCE_PORT}/_replicate"
#echo "${URL}"

# Source to target:
#echo "curl -sS -v -X POST -H '${HEADERS}' -d '${STT_DATA}' ${URL}"
#curl -sS -v -X POST -H "${HEADERS}" -d "${STT_DATA}" ${URL}

# Target to source:
echo "curl -sS -v -X POST -H '${HEADERS}' -d '${TTS_DATA}' ${URL}"
curl -sS -v -X POST -H "${HEADERS}" -d "${TTS_DATA}" ${URL}

