# CouchDB Docker container for Raspberry Pi (2B, 2B+, 3B, 3B+, 4B)

The Makefile in this repo makes it easy to spawn containerized couchdb server on on your armhf Raspberry  Pi. That is, for any Raspberry Pi model except the first generation, or the Pi Zero series, all of which are armv6/armel. I am unable to get couchdb working on those machines.

If you just wish to create a single disk instance then see the section later in this document titled, **Create a stand-alone disk instance**.

I instead prefer to use a **dual instance** approach for deployment that I think you should consider for any Raspberry Pi implementation of couchdb. The primary instance runs strictly in RAM and never writes its data to the MicroSD flash drive. The secondary instance uses the flash drive for persistence across power outages and reboots. You sync from the RAM instance to the disk instance on your own schedule.

I use a script to spawn the couchdb server instances and then securely setup and configure them. Normally couchdb servers start up in "Admin Party" mode and that's not good. So use the `spawn.sh` script instead, and in true couchdb form, relax.

## Why 2 Instances?

Why would you want to use two couchdb instances? The short answer is that this approach will extend the life of the MicroSD flash drive on your Pi.

Flash drives are great. They are tiny and they are inexpensive. They can reliably preserve your data as a static charge for something like 7-10 years.  Howevere, they have one important weakness. Each cell in the drive can only be written about 100,000 times. If every update to your database is being written to your flash drive you need to be careful about how frequently you update it. For example, if you were to update your database every few seconds then you would perform 100,000 writes in about a week.

I designed this dual database approach to achieve a balance between usability of the database interface, data persistence, and flash drive wear. With this design, you can pound the RAM instance fast as you want without causing any flash disk writes at all. Then you can easily sync the RAM database to the disk instance at the rate you choose. This way you can precisely control the amount of writing that is done to the flash drive. You can strike your own balance between how frequently your data changes and how frequenttly you persist those changes to flash.

## More is better

I actually use a third database instance on another host to better ensure that I will preserve this data in the event that something happens to the host where the dual instances are running. The utilities here make it very easy to synch from RAM to disk, and from disk on this host to disk on a remote host. All of this was easy for me to implement because of the excellent replication tools built in to couchdb.

## Prerequisites

On the host you will need some basic tools:
 * `git` (to clone this repo),
 * `make` (so you can use the provided `Makefile` to simplify the steps to build and run the `couchdb` server, perform syncs, etc.), and
 * `curl` (so you can manually interact with couchdb REST APIs)

You also need to do a little preparation on the host if you wish to use the dual instance setup. That is, you need to configure a `tmpfs` RAM disk, and you should ideally also disable swapping. You may choose to keep swapping on if you wish to accept the consequences (more details below to help you make that decision).

#### Host RAM disk configuration

To configure a RAM disk for the RAM instance of the couchDB on debian type distros like Raspberry Pi OS add this line to your `/etc/fstab` file (as `root`):

```
tmpfs /ramdisk   tmpfs defaults,noatime,nosuid,size=100m,uid=pi,gid=pi,mode=1700 0 0
```

Then reboot (or make the change below to disable swapping, then reboot).

The above will create a 100MB file system owned by the `pi` user, mounted at `/ramdisk`. The `pi` user ownership enables you to (as the `pi` user) bind mount this RAM disk filesystem path into the RAM instance's container with a `rw` binding.

Unfortunately the "tmpfs" type of RAM disk created above will swap out to the flash disk **when RAM is full**. As noted above, this may cause premature wear of the flash drive. So you need to balance whether or not to allow swapping. Swapping enables you to run workloads with greater RAM requirements, but your flash drive will pay the price. I therefore always disable swapping for this configuration.

To disable swapping on a debian type distro like Raspberry Pi OS, edit the `/etc/dphys-swapfile` as `root`, and make sure that `CONF_SWAPSIZE` is set to `0`. Then save the file and reboot.

After making these changes you can freely write to an files under `/ramdisk` and be confident that nothing will be written to the flash drive. Of course that means that anything you write there will be volatile and as soon as the power is disconnected ot the Pi is rebooted, it will be lost forever.

## Credential configuration

Begin by editing the last line of the `couchdb_ini` file in this directory to specify the password for the couchdb admin user. You will use this credential to setuo, configure, and use the couchdb instances once they are up. Keep this password secret. Keep it safe. And relax.

If you wish, edit other things in this file (which will become the `local.ini` file for the `couchdb`). Use Google to discover the myriad ways you can mess things up with this file. Alter other things at your own risk. Or just relax and only change the password.

## Building The Container

Within the directory containing this `README.dm` file, run the command:

```
make build
```

It will take a while to build, but not enough time to learn how to knit.

Sometimes the `erlang` servers go offline briefly, or are too slow to respond.  If that happens the image build will fail.  It happened twice to me during development.  If it happens to you, just run `make build` again (i.e., simply re-doing the build fixed the issue for me both times).

## Create the dual instances

When you are ready to start up the dual servers, edit the `creds` file to have your credentials, and `source it into your shell:

```
nano creds
source creds
```

Then run this command:

```
make run
```

This will start up, secure, and configure the RAM couchdb server instance, binding to the standard couchdb service port of `5984` on all of the host's interfaces. That is, the RAM instance will be accessible from other hosts on your LAN. It will also start up, secure and configure the flash drive instance of couchdb, binding it to the nonstandard service port of `5985` (standard port plus one) on the host loopback interface only. As a result, the flash instance will only be accessible **on the host**. you will not be able to interact with the flash instance from any other hosts on your LAN. These choices are intended to help you relax.

You can perform a quick check that both instances are correctly setup with this command:

```
make check
```

If that works then you can really relax. Both instances are ready to go.

When you wish to suncronize from the RAM instance to the disk instance, see the section later in this document titled, **Synchronizing instances**.

If you wish to create a single disk instance (e.g., to create third disk-based instance on a remote host, or just to create a stand-alone disk-based instance) see the section later in this document titled, **Create a stand-alone disk instance**.

## Using Your CouchDB

Google for CouchDB REST API details. Some basic REST API examples are below.

The Python bindings are really great. That how I use couchdb. Documentation for those bindings are here: [https://readthedocs.org/projects/couchdb-python/downloads/pdf/latest/](https://readthedocs.org/projects/couchdb-python/downloads/pdf/latest/):

### Use REST to create a DB

```
curl -X PUT http://admin:p4ssw0rd@127.0.0.1:5984/mycooldb
```

### Use REST to post a JSON Document to Your DB

```
curl -X POST http://admin:p4ssw0rd@127.0.0.1:5984/mycooldb -H "Content-Type: application/json" -d '{ "somekey": "some value", "anotherkey": "another value" }'
```

### Use REST to read All The Posted Documents From Your DB

```
curl -i -H "Accept: application/json" -X GET http://admin:p4ssw0rd@127.0.0.1:5984/mycooldb/_all_docs
```

### Use REST to delete Your DB

```
curl -X PUT http://admin:p4ssw0rd@127.0.0.1:5984/mycooldb
```

## Create a stand-alone disk instance

First make sure you have installed the prerequisite tools, configured a password for the admin user, and built the couchdb container. These things are covered above in **Prerequisites** (but skip the "Host RAM disk configuration" section), **Credential configuration**, and **Building The Container**, respectively.

Edit the `creds` file to have your credentials, and optionally modify the stand-alone configuration variables if desired. Then `source it into your shell:

```
nano creds
source creds
```

Then you can create the stand-alone instance with:

```
make remote
```

You can then check the stand-alone instance with:

```
make remotecheck
```

If that works, life is good. Relax. When you are ready to sync read the next section...


## Synchronizing instances

To synchronize the RAM instance to the disk instance in the dual setup, use:

```
source creds
make sync
```

To sync more generally, setup your creds with the appropriate client address of the remote (i.e., replace the initial setting of `127.0.0.1` with the address of your remote instance). Then run these commands:

```
source creds
make remotesync
```

## Manually using the `spawn.py` script

You can run the `spawn.py` script to create, secure and configure a couchdb instance if you wish. You must of course first build the container, setup and source the creds file.

Use this command to get brief usage information for the script:

```
./spawn.py -h
```

