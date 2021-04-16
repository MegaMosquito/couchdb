
# This Makefile is setup to create 2 instance os couchdb: one that updates
# a database in RAM frequently, and another that updates a database on disk
# much less frequently.

# This Makefile requires you to configure a RAM disk for the RAM instance
# of the couchDB. This is the one that will be updated once per minute
# by the `netmon` container (you don't want to update one on a flash disk
# at that rate or the flash disk will soon fail. To create a RAM disk just
# add this line to your `/etc/fstab` file (as root):
#   tmpfs /ramdisk   tmpfs defaults,noatime,nosuid,size=100m,uid=pi,gid=pi,mode=1700 0 0
# then reboot. The above will create a 100MB file system owned by the "pi" user
# so then the pi user can bind mount this into the container with r/w as the
# "make dev" and "make run" commands below do..
# On a Raspberry Pi, or other machine that uses MicroSD flash for storage,
# you may want to disable swapping, since "tmpfs" will swap out to storage
# when RAM is full and this may cause early disk failure. To do that, set this:
#   CONF_SWAPSIZE=0
# in:
#  /etc/dphys-swapfile

# Some bits from https://github.com/MegaMosquito/netstuff/blob/master/Makefile
LOCAL_DEFAULT_ROUTE     := $(shell sh -c "ip route | grep default | sed 's/dhcp src //'")
LOCAL_IP_ADDRESS        := $(word 7, $(LOCAL_DEFAULT_ROUTE))

# These variables need to match couchdb_ini, and sync.sh, and *_PORT below
MY_COUCHDB_ADDRESS        := $(LOCAL_IP_ADDRESS)
MY_COUCHDB_PORT           := 5984
MY_COUCHDB_USER           := 'admin'
MY_COUCHDB_PASSWORD       := 'p4ssw0rd'

# To initiate a regular sync between the RAM instance and the disk instance,
# use `make runsync` command.

# These variables configure where on the host couchdb will store its files
# (RAM to enable frequent read/write or disk for data persistence between
# host reboots).  See `couchdb_ini` and `Dockerfile` for more details.
RAM_STORAGE_DIR:=/ramdisk/couchdb
DISK_STORAGE_DIR:=/home/$(USER)/_couchdb_data
DEV_STORAGE_DIR:=/home/$(USER)/_dev_couchdb_data

# Bind addresses and port for the RAM instance (accessible from LAN with creds)
RAM_BIND_ADDRESS:=0.0.0.0
RAM_BIND_PORT:=$(MY_COUCHDB_PORT)

# Bind address and port for the DISK instance (not visible off this host)
DISK_BIND_ADDRESS:=127.0.0.1
DISK_BIND_PORT:=5985

# Docker bridge (private virtual) network for local container comms
NETNAME:=couchdbnet
RAM_ALIAS:=couchdb
DISK_ALIAS:=couchdb_disk

default: build run

build:
	docker build -t couchdb .

dev: devdisk devram

# Run the RAM Instance for development
devram: build
	-docker rm -f couchdb 2> /dev/null || :
	-docker network create $(NETNAME) 2>/dev/null || :
	@echo " "
	@echo "Copying DISK storage to RAM storage ($(RAM_STORAGE_DIR))..."
	-sudo rm -rf $(RAM_STORAGE_DIR) || :
	-sudo cp -r $(DISK_STORAGE_DIR) $(RAM_STORAGE_DIR)|| :
	@echo " "
	@echo "Starting DEV RAM instance at $(RAM_BIND_ADDRESS):$(RAM_BIND_PORT)."
	@echo "Storing couchdb data files in $(DEV_STORAGE_DIR)"
	@echo "Connect to Futon at: http://$(RAM_BIND_ADDRESS):$(RAM_BIND_PORT)/_utils/
	@echo " "
	docker run -it --volume `pwd`:/outside \
	  --name couchdb \
	  --publish $(RAM_BIND_ADDRESS):$(MY_COUCHDB_PORT):$(MY_COUCHDB_PORT) \
	  -e MY_COUCHDB_ADDRESS=$(MY_COUCHDB_ADDRESS) \
	  -e MY_COUCHDB_PORT=$(MY_COUCHDB_PORT) \
	  -e MY_COUCHDB_USER=$(MY_COUCHDB_USER) \
	  -e MY_COUCHDB_PASSWORD=$(MY_COUCHDB_PASSWORD) \
	  --volume $(RAM_STORAGE_DIR):/data \
	  --net $(NETNAME) --net-alias $(RAM_ALIAS) \
	  couchdb /bin/sh

# Run the disk Instance for development
# NOTE: runs as a daemon, with `sleep 365d` to keep itself up.
# To do anything interesting in this container exec in.
devdisk: build
	-docker rm -f couchdb_disk 2> /dev/null || :
	-docker network create $(NETNAME) 2>/dev/null || :
	@echo " "
	@echo "Copying DISK storage to DEV storage ($(DEV_STORAGE_DIR))..."
	-sudo rm -rf $(DISK_STORAGE_DIR) || :
	-sudo cp -r $(DISK_STORAGE_DIR) $(DEV_STORAGE_DIR)|| :
	@echo "Starting DEV DISK instance at $(DISK_BIND_ADDRESS):$(DISK_BIND_PORT)."
	@echo "Connect to Futon at: http://$(DISK_BIND_ADDRESS):$(DISK_BIND_PORT)/_utils/
	@echo " "
	docker run -d --volume `pwd`:/outside \
	  --name couchdb_disk \
	  --publish $(DISK_BIND_ADDRESS):$(DISK_BIND_PORT):$(MY_COUCHDB_PORT) \
	  -e MY_COUCHDB_ADDRESS=$(MY_COUCHDB_ADDRESS) \
	  -e MY_COUCHDB_PORT=$(MY_COUCHDB_PORT) \
	  -e MY_COUCHDB_USER=$(MY_COUCHDB_USER) \
	  -e MY_COUCHDB_PASSWORD=$(MY_COUCHDB_PASSWORD) \
	  --volume $(DEV_STORAGE_DIR):/data \
	  --net $(NETNAME) --net-alias $(DISK_ALIAS) \
	  couchdb sleep 365d &

run: runram rundisk

runram:
	-docker network create $(NETNAME) 2>/dev/null || :
	-docker rm -f couchdb 2>/dev/null || :
	-sudo rm -rf $(RAM_STORAGE_DIR) || :
	@echo " "
	@echo "Starting RAM instance on port $(HOST_RAM_INSTANCE_PORT)."
	@echo "Storing couchdb data files in $(RAM_STORAGE_DIR)"
	@echo " "
	docker run -d --restart unless-stopped \
	  --name couchdb \
	  --publish $(HOST_RAM_INSTANCE_PORT):$(MY_COUCHDB_PORT) \
	  --volume $(RAM_STORAGE_DIR):/data \
	  -e MY_COUCHDB_ADDRESS=$(MY_COUCHDB_ADDRESS) \
	  -e MY_COUCHDB_PORT=$(MY_COUCHDB_PORT) \
	  -e MY_COUCHDB_USER=$(MY_COUCHDB_USER) \
	  -e MY_COUCHDB_PASSWORD=$(MY_COUCHDB_PASSWORD) \
	  --net $(NETWORK) --net-alias $(ALIAS) \
	  couchdb
	@echo "NOTE: The 'python ./setup.py' command runs on the *host* (which first requires: 'pip3 install couchdb')"
	pip3 install couchdb
	export MY_COUCHDB_ADDRESS=$(MY_COUCHDB_ADDRESS) && \
	export MY_COUCHDB_PORT=$(MY_COUCHDB_PORT) && \
	export MY_COUCHDB_USER=$(MY_COUCHDB_USER) && \
	export MY_COUCHDB_PASSWORD=$(MY_COUCHDB_PASSWORD) && \
	python3 ./setup.py
	#@echo " "
	@echo "RAM CouchDB instance is ready. Relax."
	#@echo " "
	#@echo "Starting DISK instance on port $(HOST_DISK_INSTANCE_PORT)."
	#@echo "Storing couchdb data files in $(DISK_STORAGE_DIR)"
	#@echo " "
	#docker run -d --restart unless-stopped \
	#  --name couchdb_disk \
	#  --volume $(DISK_STORAGE_DIR):/data \
	#  --publish $(HOST_DISK_INSTANCE_PORT):$(MY_COUCHDB_PORT) \
	#  -e MY_COUCHDB_ADDRESS=$(MY_COUCHDB_ADDRESS) \
	#  -e MY_COUCHDB_PORT=$(MY_COUCHDB_PORT) \
	#  -e MY_COUCHDB_USER=$(MY_COUCHDB_USER) \
	#  -e MY_COUCHDB_PASSWORD=$(MY_COUCHDB_PASSWORD) \
	#  couchdb

runsync:
	#docker run ...
	# Put in a Dockerfile:  sync.sh

execdevram:
	docker exec -it couchdb /bin/bash

execdevdisk:
	docker exec -it couchdb_disk /bin/bash

stop:
	-docker rm -f couchdb 2>/dev/null || :
	-docker rm -f couchdb_disk 2>/dev/null || :
	sudo rm -rf $(RAM_STORAGE_DIR) || :
	sudo rm -rf $(DEV_STORAGE_DIR) || :

clean: stop
	-docker rmi couchdb 2>/dev/null || :

.PHONY: all build dev devram devdisk run runram rundisk runsync execdevram execdevdisk stop clean
