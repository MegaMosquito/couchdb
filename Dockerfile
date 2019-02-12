FROM ubuntu:latest

# Based on: https://andyfelong.com/2016/12/couchdb-2-0-on-raspberry-pi/

# Basic setup
RUN apt-get update
RUN apt-get install -y vim curl wget jq gnupg

# Install Mozilla JS API and its dev package
RUN apt-get install -y libnspr4 libnspr4-dev libffi-dev
RUN wget http://http.us.debian.org/debian/pool/main/m/mozjs/libmozjs185-1.0_1.8.5-1.0.0+dfsg-6_armhf.deb
RUN dpkg -i libmozjs185-1.0_1.8.5-1.0.0+dfsg-6_armhf.deb
RUN apt-get install -f
RUN rm libmozjs185-1.0_1.8.5-1.0.0+dfsg-6_armhf.deb
RUN wget http://http.us.debian.org/debian/pool/main/m/mozjs/libmozjs185-dev_1.8.5-1.0.0+dfsg-6_armhf.deb
RUN dpkg -i libmozjs185-dev_1.8.5-1.0.0+dfsg-6_armhf.deb
RUN apt-get install -f
RUN rm libmozjs185-dev_1.8.5-1.0.0+dfsg-6_armhf.deb

# Install Erlang
RUN curl -L http://packages.erlang-solutions.com/debian/erlang_solutions.asc | apt-key add -
RUN apt-get update
RUN apt-get --no-install-recommends install -y erlang erlang-reltool

# Install remining couchdb dependencies
RUN apt-get --no-install-recommends -y install build-essential pkg-config libicu-dev libcurl4-openssl-dev

# Download couchdb source and build it
RUN wget http://apache.mirrors.pair.com/couchdb/source/2.3.0/apache-couchdb-2.3.0.tar.gz
RUN tar zxvf apache-couchdb-2.3.0.tar.gz
RUN cd /apache-couchdb-2.3.0; ./configure
RUN make -C /apache-couchdb-2.3.0 release
RUN rm apache-couchdb-2.3.0.tar.gz

# Setup the couchdb user as a home for couchdb files
RUN useradd -d /home/couchdb couchdb
RUN mkdir /home/couchdb

# Copy the (just built) release code to /home/couchdb
RUN cp -Rp /apache-couchdb-2.3.0/rel/couchdb/* /home/couchdb/

# Copy over the init file
COPY ./couchdb_ini /home/couchdb/etc/local.ini

# Symlink in the bound host volume to `data` (to persist the database data)
# Note that the `docker run` command must mount a volume to `/data` for this!
# See the Makefile STORAGE_DIR assignment for more details on this.
RUN ln -s /data /home/couchdb/data

# Fixup all permissions
RUN chown -R couchdb:couchdb /home/couchdb

# Start it up!
# 5984: Main CouchDB endpoint
# 4369: Erlang portmap daemon (epmd)
# 9100: CouchDB cluster communication port
EXPOSE 5984 4369 9100
CMD ["/home/couchdb/bin/couchdb"]
