#!/bin/bash

#
# Synchronize a couchdb database from a source server to a target server
#
# E.g.:
#   ./sync.sh  192.168.123.12:5984  192.168.123.12:5985  test-db
#

# Set this to "true" to enable verbose output
CHATTY=false

# Exactly three arguments are required
if [ 3 -ne $# ]
then
  echo "Usage: $0 source target database"
  exit 1
fi
SOURCE=$1
TARGET=$2
DATABASE=$3

# Exactly two environment variables are also required (for authentication)
if [ -z "${MY_COUCHDB_USER}" ]
then
  echo "MY_COUCHDB_USER must be set in your environment"
  exit 1
fi
if [ -z "${MY_COUCHDB_PASSWORD}" ]
then
  echo "MY_COUCHDB_PASSWORD must be set in your environment"
  exit 1
fi
AUTH=${MY_COUCHDB_USER}:${MY_COUCHDB_PASSWORD}@

# Create the JSON payload
JSON="{\"source\":\"${DATABASE}\",\"target\":\"http://${AUTH}${TARGET}/${DATABASE}\",\"create_target\":true,\"continuous\":false}"
if [ true = ${CHATTY} ]; then echo "JSON=${JSON}"; fi

# Perform the sync...
HEADERS="Content-Type: application/json"
URL="http://${AUTH}${SOURCE}/_replicate"
if [ true = ${CHATTY} ]
then 
  echo "curl -sS -v -X POST -H '${HEADERS}' -d '${JSON}' ${URL}"
  curl -sS -v -X POST -H "${HEADERS}" -d "${JSON}" ${URL}
else
  curl -sS -X POST -H "${HEADERS}" -d "${JSON}" ${URL}
fi

