
# This Makefile is setup to create 2 instance os couchdb: one that updates
# a database in RAM frequently, and another that updates a database on disk
# much less frequently.

# This Makefile requires you to configure a RAM disk for the RAM instance
# of the couchDB. This is the one that will be updated once per minute
# by the `netmon` container (you don't want to update one on a flash disk
# at that rate or the flash disk will soon fail. To create a RAM disk just
# add this line to your `/etc/fstab` file (as root):
# tmpfs   /ramdisk    tmpfs    defaults,noatime,nosuid,mode=0755,size=100m    0 0

# To initiate a sync between the RAM instance and the disk instance, use
# the `make sync` command.

# These variables configure where on the host couchdb will store its files
# (RAM ro enable frequent read/write or flash diskfor data persistence
# between container start/stop and host reboots).
# The specified directory is mounted in each running container as `/data`
# and the Dockerfile symlinks `/data` to `/home/couchdb/data` where couchdb
# will normally write its data. See the Dockerfile for more details.
RAM_STORAGE_DIR:=/ramdisk
DISK_STORAGE_DIR:=$(shell pwd)/../_couchdb_data
DEV_STORAGE_DIR:=$(shell pwd)/../_couchdb_dev_data

# Host ports for the RAM instance and the DISK instance
HOST_RAM_PORT:=5984
HOST_DISK_PORT:=5985

all: build run

build:
	docker build -t couchdb .

dev: build
	-docker rm -f couchdb 2> /dev/null || :
	echo "Storing couchdb data files in $(STORAGE_DIR)"
	docker run -it --name couchdb --volume `pwd`:/outside --volume $(DEV_STORAGE_DIR):/data --publish 5984:5984 couchdb /bin/bash

run:
	-docker rm -f couchdb 2>/dev/null || :
	echo "Starting RAM instance of couchdb on port $(HOST_RAM_PORT) with data files in $(RAM_STORAGE_DIR)"
	docker run -d --name couchdb --volume `pwd`:/outside --volume $(RAM_STORAGE_DIR):/data --publish $(HOST_RAM_PORT):5984 couchdb
	echo "Starting DISK instance of couchdb on port $(HOST_DISK_PORT) with data files in $(DISK_STORAGE_DIR)"
	docker run -d --name couchdb2 --volume `pwd`:/outside --volume $(DISK_STORAGE_DIR):/data --publish $(HOST_DISK_PORT):5984 couchdb

exec:
	docker exec -it couchdb /bin/bash

stop:
	-docker rm -f couchdb 2>/dev/null || :
	-docker rm -f couchdb2 2>/dev/null || :

clean: stop
	-docker rmi couchdb 2>/dev/null || :

sync:
	sync.sh

.PHONY: all build dev run exec stop clean sync
