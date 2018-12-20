# CouchDB Docker Container for armhf (e.g., Raspberry Pi 2B, 2B+, 3B, 3B+)

This container builds and starts a `couchdb` server. But relax, it won't start up in "Admin Party" mode.

## Prerequisites

On the host you will need:
 * `git` (to clone this repo),
 * `make` (so you can use the provided `Makefile` to simplify the steps to build and run the `couchdb` server), and
 * `curl` (to interact with the `couchdb` instance to configure it once it is up and running.
but you should need nothing else on the host.

## Initial Configuration

Edit the last 2 lines of the `couchdb_ini` file in this directory to specify the name of the first user that has administrative privileges, and a password for that user. You will use these credentials to configure the `couchdb` once it is up. Keep them secret. Keep them safe. And relax.

If you wish, edit other things in this file (which will become the `local.ini` file for the `couchdb`). Google to discover the myriad ways you can mess things up with this file. Or just relax.

## Building The Container

Within the directory containing this `README.dm` file, run the command:

```
make build
```

It will take a while to build, but not enough time to learn how to knit.

Sometimes the `erlang` servers go offline briefly, or are too slow to respond.  If that happens the image build will fail.  It happened twice to me during development.  If it happens, just run `make build` again (i.e., simply re-doing the build fixed the issue for me both times).

## Make It So

When you are ready to start up the server, run this command from the same directory:

```
make run
```

This will start up the `couchdb` server on its standard port of `5984` (unless you edited that in the `couchdb_ini` file. It will bind to all interfaces (since the bind address is set to `0.0.0.0` in that same file, unless you edited it). Running the container should only take a few seconds. When the container has staryed up, pleae complete the basic setup before you relax.

## Complete The Setup

First let's verify that the `couchdb` server is up.  Run this command on the host:

```
curl -X GET http://127.0.0.1:5984/_all_dbs
```

That command should return an empty json list `[]` of databases (since none exist yet). If the `curl` command fails, then something went wrong in building or starting up the container.

Now try to create a database, by using the following command:

```
curl -X PUT http://127.0.0.1:5984/no_worky
```

That will fail, because this puppy was secured with the credentials you edited in the `couchdb_ini` file. All REST API invocations that will change the state of the `couchdb` require authentication with those credentials (or others you will subsequently create using them).  So relax.

To complete the setup, create the 3 core databases, by using the commands below, with your credentials. In the commands below I used the original unedited credentials (user: `admin`, and password: `p4ssw0rd`).

```
curl -X PUT http://admin:p4ssw0rd@127.0.0.1:5984/_users
curl -X PUT http://admin:p4ssw0rd@127.0.0.1:5984/_replicator
curl -X PUT http://admin:p4ssw0rd@127.0.0.1:5984/_global_changes

```

*Now* you can relax.  Everything is ready to go.

## Using Your CouchDB

Google for CouchDB REST API details, but here are some basic commands:

### Create a DB

```
curl -X PUT http://admin:p4ssw0rd@127.0.0.1:5984/mycooldb
```

### Post a JSON Document to Your DB

```
curl -X POST http://admin:p4ssw0rd@127.0.0.1:5984/mycooldb -H "Content-Type: application/json" -d '{ "somekey": "some value", "anotherkey": "another value" }'
```

### Read All The Posted Documents From Your DB

```
curl -i -H "Accept: application/json" -X GET http://admin:p4ssw0rd@127.0.0.1:5984/mycooldb/_all_docs
```

### Delete Your DB

```
curl -X PUT http://admin:p4ssw0rd@127.0.0.1:5984/mycooldb
```

