
all: build run

build:
	docker build -t couchdb .

# Maybe use this instead of `--privileged`:  `--device /dev/gpiomem`
dev: build
	-docker rm -f couchdb 2> /dev/null || :
	docker run -it --name couchdb --volume `pwd`:/outside --volume `pwd`/../_couchdb_data:/data --publish 5984:5984 couchdb /bin/bash

run:
	-docker rm -f couchdb 2>/dev/null || :
	docker run -d --name couchdb --volume `pwd`:/outside --volume `pwd`/../_couchdb_data:/data --publish 5984:5984 couchdb

exec:
	docker exec -it couchdb /bin/bash

stop:
	-docker rm -f couchdb 2>/dev/null || :

clean: stop
	-docker rmi couchdb 2>/dev/null || :

.PHONY: all build dev run exec stop clean
