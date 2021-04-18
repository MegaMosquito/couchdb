#
# This Makefile is setup to create one or more instances of couchdb.
#
# I designed this so I could update a database in RAM frequently, (every few
# seconds) and then sync that RAM instance to another database on disk much
# less frequently (e.g., hourly, or daily).
#
# Please see the README.md file for usage details.
#

# These variables configure where on the host the couchdb will store its files
# (RAM to enable frequent read/write or disk for data persistence between
# host reboots).
RAM_STORAGE_DIR:=/ramdisk/couchdb
DISK_STORAGE_DIR:=/home/$(USER)/_couchdb_data
DEV_STORAGE_DIR:=/home/$(USER)/_couchdb_DEV

default: build run

build:
	docker build -t couchdb .

dev: build
	@echo "Copying DISK storage to dev and RAM storage..."
	-mkdir -p $(DISK_STORAGE_DIR) >/dev/null 2>&1 || :
	-mkdir -p $(DEV_STORAGE_DIR) >/dev/null 2>&1 || :
	-mkdir -p $(RAM_STORAGE_DIR) >/dev/null 2>&1 || :
	-rm -rf $(DEV_STORAGE_DIR)/* >/dev/null 2>&1 || :
	-rm -rf $(RAM_STORAGE_DIR)/* >/dev/null 2>&1 || :
	-cp -r $(DISK_STORAGE_DIR) $(DEV_STORAGE_DIR) >/dev/null 2>&1 || :
	-cp -r $(DISK_STORAGE_DIR) $(RAM_STORAGE_DIR) >/dev/null 2>&1 || :
	@echo "-----  Spawning RAM instance...  -----"
	env \
	  MY_COUCHDB_NAME=couchdb \
	  MY_COUCHDB_USER=$(MY_COUCHDB_USER) \
	  MY_COUCHDB_PASSWORD=$(MY_COUCHDB_PASSWORD) \
	  MY_COUCHDB_PUBLISH_ADDRESS=0.0.0.0 \
	  MY_COUCHDB_CLIENT_ADDRESS=127.0.0.1 \
	  MY_COUCHDB_HOST_PORT=5984 \
	  MY_COUCHDB_STORAGE_DIR=$(RAM_STORAGE_DIR) \
	  MY_COUCHDB_NETWORK=couchdbnet \
	  MY_COUCHDB_EXTRAS="--volume `pwd`:/outside" \
	  MY_COUCHDB_COMMAND= \
	  ./spawn.py -nr
	@echo "-----  Spawning disk instance...  -----"
	env \
	  MY_COUCHDB_NAME=couchdb_disk \
	  MY_COUCHDB_USER=$(MY_COUCHDB_USER) \
	  MY_COUCHDB_PASSWORD=$(MY_COUCHDB_PASSWORD) \
	  MY_COUCHDB_PUBLISH_ADDRESS=127.0.0.1 \
	  MY_COUCHDB_CLIENT_ADDRESS=127.0.0.1 \
	  MY_COUCHDB_HOST_PORT=5985 \
	  MY_COUCHDB_STORAGE_DIR=$(DEV_STORAGE_DIR) \
	  MY_COUCHDB_NETWORK=couchdbnet \
	  MY_COUCHDB_EXTRAS="--volume `pwd`:/outside" \
	  MY_COUCHDB_COMMAND= \
	  ./spawn.py -nr

run:
	@echo "Copying DISK storage to RAM storage..."
	-mkdir -p $(DISK_STORAGE_DIR) >/dev/null 2>&1 || :
	-mkdir -p $(RAM_STORAGE_DIR) >/dev/null 2>&1 || :
	-rm -rf $(RAM_STORAGE_DIR)/* >/dev/null 2>&1 || :
	-cp -r $(DISK_STORAGE_DIR) $(RAM_STORAGE_DIR) >/dev/null 2>&1 || :
	@echo "-----  Spawning RAM instance...  -----"
	env \
	  MY_COUCHDB_NAME=couchdb \
	  MY_COUCHDB_USER=$(MY_COUCHDB_USER) \
	  MY_COUCHDB_PASSWORD=$(MY_COUCHDB_PASSWORD) \
	  MY_COUCHDB_PUBLISH_ADDRESS=0.0.0.0 \
	  MY_COUCHDB_CLIENT_ADDRESS=127.0.0.1 \
	  MY_COUCHDB_HOST_PORT=5984 \
	  MY_COUCHDB_STORAGE_DIR=$(RAM_STORAGE_DIR) \
	  MY_COUCHDB_NETWORK=couchdbnet \
	  MY_COUCHDB_EXTRAS= \
	  MY_COUCHDB_COMMAND= \
	  ./spawn.py
	@echo "-----  Spawning disk instance...  -----"
	env \
	  MY_COUCHDB_NAME=couchdb_disk \
	  MY_COUCHDB_USER=$(MY_COUCHDB_USER) \
	  MY_COUCHDB_PASSWORD=$(MY_COUCHDB_PASSWORD) \
	  MY_COUCHDB_PUBLISH_ADDRESS=127.0.0.1 \
	  MY_COUCHDB_CLIENT_ADDRESS=127.0.0.1 \
	  MY_COUCHDB_HOST_PORT=5985 \
	  MY_COUCHDB_STORAGE_DIR=$(DISK_STORAGE_DIR) \
	  MY_COUCHDB_NETWORK=couchdbnet \
	  MY_COUCHDB_EXTRAS= \
	  MY_COUCHDB_COMMAND= \
	  ./spawn.py

# Exec into the RAM instance
exec:
	docker exec -it \
	  -e MY_COUCHDB_USER=$(MY_COUCHDB_USER) \
	  -e MY_COUCHDB_PASSWORD=$(MY_COUCHDB_PASSWORD) \
	  couchdb /bin/bash

# Perform a basic query (list all DBs) on both the RAM and disk instances
HOST_ADDR:=$(word 1,$(shell hostname -I))
check:
	@echo "Checking the RAM instance using $(HOST_ADDR):5984..."
	curl -sS -X GET -H "Content-Type: application/json" "http://${MY_COUCHDB_USER}:${MY_COUCHDB_PASSWORD}@$(HOST_ADDR):5984/_all_dbs"
	@echo "Checking the RAM instance using 127.0.0.1:5985..."
	curl -sS -X GET -H "Content-Type: application/json" "http://${MY_COUCHDB_USER}:${MY_COUCHDB_PASSWORD}@127.0.0.1:5985/_all_dbs"

# To sync a DB from  RAM to disk, set MY_COUCHDB_DATABASE, then `make sync`
sync:
	docker exec -it \
	  -e MY_COUCHDB_USER=$(MY_COUCHDB_USER) \
	  -e MY_COUCHDB_PASSWORD=$(MY_COUCHDB_PASSWORD) \
	  couchdb \
          /sync.sh localhost:5984 couchdb_disk:5984 $(MY_COUCHDB_DATABASE)

# Create a stand-alone remove instance
remote:
	@echo "-----  Spawning remote instance with defaults...  -----"
	bash -c 'source creds; ./spawn.py'

# Perform a basic query (list all DBs) on a stand-alone instance
remotecheck:
	@echo "Checking the stand-alone instance using $(MY_COUCHDB_CLIENT_ADDRESS):$(MY_COUCHDB_HOST_PORT)..."
	curl -sS -X GET -H "Content-Type: application/json" "http://${MY_COUCHDB_USER}:${MY_COUCHDB_PASSWORD}@$(MY_COUCHDB_CLIENT_ADDRESS):$(MY_COUCHDB_HOST_PORT)/_all_dbs"

# Remote sync *DISK*. Set MY_COUCHDB_REMOTE (addr:port) and MY_COUCHDB_DATABASE
remotesync:
	docker exec -it \
	  -e MY_COUCHDB_USER=$(MY_COUCHDB_USER) \
	  -e MY_COUCHDB_PASSWORD=$(MY_COUCHDB_PASSWORD) \
	  couchdb \
          /sync.sh localhost:5984 ${MY_COUCHDB_REMOTE} $(MY_COUCHDB_DATABASE)

stop:
	-docker rm -f couchdb 2>/dev/null || :
	-docker rm -f couchdb_disk 2>/dev/null || :
	sudo rm -rf $(RAM_STORAGE_DIR) || :
	sudo rm -rf $(DEV_STORAGE_DIR) || :

clean: stop
	-docker rmi couchdb 2>/dev/null || :

.PHONY: all build dev run exec check sync remote remotecheck remotesync stop clean
