
# This Makefile is setup to create 2 instance os couchdb: one that updates
# a database in RAM frequently, and another that updates a database on disk
# much less frequently.

# This Makefile requires you to configure a RAM disk for the RAM instance
# of the couchDB. This is the one that will be updated once per minute
# by the `netmon` container (you don't want to update one on a flash disk
# at that rate or the flash disk will soon fail. To create a RAM disk just
# add this line to your `/etc/fstab` file (as root):
# tmpfs   /ramdisk    tmpfs    defaults,noatime,nosuid,mode=0755,size=100m    0 0

# Some bits from https://github.com/MegaMosquito/netstuff/blob/master/Makefile
LOCAL_DEFAULT_ROUTE     := $(shell sh -c "ip route | grep default | sed 's/dhcp src //'")
LOCAL_IP_ADDRESS        := $(word 7, $(LOCAL_DEFAULT_ROUTE))

# These variables need to match couchdb_ini, and sync.sh, and *_PORT below
MY_COUCHDB_ADDRESS        := $(LOCAL_IP_ADDRESS)
MY_COUCHDB_PORT           := 5984
MY_COUCHDB_USER           := 'admin'
MY_COUCHDB_PASSWORD       := 'p4ssw0rd'

# To initiate a sync between the RAM instance and the disk instance, use
# the `make sync` command.

# These variables configure where on the host couchdb will store its files
# (RAM ro enable frequent read/write or flash diskfor data persistence
# between container start/stop and host reboots).
# The specified directory is mounted in each running container as `/data`
# and the Dockerfile symlinks `/data` to `/home/couchdb/data` where couchdb
# will normally write its data. See the Dockerfile for more details.
RAM_STORAGE_DIR:=/ramdisk/couchdb
DISK_STORAGE_DIR:=$(shell pwd)/../_couchdb_data
DEV_STORAGE_DIR:=$(shell pwd)/../_couchdb_dev_data

# Host ports for the RAM instance and the DISK instance
HOST_RAM_PORT:=5984
HOST_DISK_PORT:=5985
PUBLISH:=
# Set this to publish the service port to the host
PUBLISH:=--publish $(HOST_RAM_PORT):5984

# Private network
NETNAME:=
NETWORK:=
ALIAS:=
# Set these to use the private network
NETNAME:=dbnet
NETWORK:=--net=$(NETNAME)
ALIAS:=--net-alias=couchdb

all: build run

build:
	docker build -t couchdb .

dev: build
	-docker rm -f couchdb 2> /dev/null || :
	echo "Storing couchdb data files in $(STORAGE_DIR)"
	-docker network create $(NETNAME) 2>/dev/null || :
	docker run -it \
            --name couchdb \
            -e MY_COUCHDB_ADDRESS=$(MY_COUCHDB_ADDRESS) \
            -e MY_COUCHDB_PORT=$(MY_COUCHDB_PORT) \
            -e MY_COUCHDB_USER=$(MY_COUCHDB_USER) \
            -e MY_COUCHDB_PASSWORD=$(MY_COUCHDB_PASSWORD) \
            --volume $(DEV_STORAGE_DIR):/data \
            $(PUBLISH) \
            $(NETWORK) $(ALIAS) \
            --volume `pwd`:/outside couchdb /bin/sh

run:
	echo "MY_COUCHDB_ADDRESS=$(MY_COUCHDB_ADDRESS)"
	-docker network create $(NETNAME) 2>/dev/null || :
	-docker rm -f couchdb 2>/dev/null || :
	echo "Starting RAM instance of couchdb on port $(HOST_RAM_PORT) with data files in $(RAM_STORAGE_DIR)"
	docker run -d \
            --name couchdb \
            -e MY_COUCHDB_ADDRESS=$(MY_COUCHDB_ADDRESS) \
            -e MY_COUCHDB_PORT=$(MY_COUCHDB_PORT) \
            -e MY_COUCHDB_USER=$(MY_COUCHDB_USER) \
            -e MY_COUCHDB_PASSWORD=$(MY_COUCHDB_PASSWORD) \
            --volume $(RAM_STORAGE_DIR):/data \
            --publish 5984:5984 \
            --restart unless-stopped \
            couchdb
	@echo "RAM CouchDB instance is ready. Relax."
	#echo "Starting DISK instance of couchdb on port $(HOST_DISK_PORT) with data files in $(DISK_STORAGE_DIR)"
	#docker run -d \
        #    --name couchdb \
        #    -e MY_COUCHDB_ADDRESS=$(MY_COUCHDB_ADDRESS) \
        #    -e MY_COUCHDB_PORT=$(MY_COUCHDB_PORT) \
        #    -e MY_COUCHDB_USER=$(MY_COUCHDB_USER) \
        #    -e MY_COUCHDB_PASSWORD=$(MY_COUCHDB_PASSWORD) \
        #    --volume $(DISK_STORAGE_DIR):/data \
	#    --publish $(HOST_DISK_PORT):5984 couchdb \
        #    --restart unless-stopped \
        #    couchdb
	pip3 install couchdb
	export MY_COUCHDB_ADDRESS=$(MY_COUCHDB_ADDRESS) && \
	export MY_COUCHDB_PORT=$(MY_COUCHDB_PORT) && \
	export MY_COUCHDB_USER=$(MY_COUCHDB_USER) && \
	export MY_COUCHDB_PASSWORD=$(MY_COUCHDB_PASSWORD) && \
	python3 ./setup.py

exec:
	docker exec -it couchdb /bin/bash

stop:
	-docker rm -f couchdb 2>/dev/null || :
	#-docker rm -f couchdb2 2>/dev/null || :
	sudo rm -rf $(RAM_STORAGE_DIR) || :

clean: stop
	-docker rmi couchdb 2>/dev/null || :

sync:
	sync.sh

.PHONY: all build dev run exec stop clean sync
