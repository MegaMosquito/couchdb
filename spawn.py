#!/usr/bin/python3

# Spawn, secure, and configure a single instance of my couchdb container

import os
import sys
import time

# Don't forget to `pip install couchdb`!
import couchdb

# Get variable (v) value from environment or return the default (d) if given
def get_from_env(v, d = None):
  if v in os.environ and '' != os.environ[v]:
    return os.environ[v]
  elif d:
    return d
  else:
    sys.exit('ERROR: Variable, "' + v + '" not found in environment!')

# Get configuration from the environment (see the Makefile for typical usage)
MY_COUCHDB_NAME            = get_from_env('MY_COUCHDB_NAME', 'couchdb')
MY_COUCHDB_PUBLISH_ADDRESS = get_from_env('MY_COUCHDB_PUBLISH_ADDRESS',
                               '127.0.0.1')
MY_COUCHDB_CLIENT_ADDRESS  = get_from_env('MY_COUCHDB_CLIENT_ADDRESS',
                               MY_COUCHDB_PUBLISH_ADDRESS)
MY_COUCHDB_HOST_PORT       = int(get_from_env('MY_COUCHDB_HOST_PORT', '5984'))
MY_COUCHDB_USER            = get_from_env('MY_COUCHDB_USER')
MY_COUCHDB_PASSWORD        = get_from_env('MY_COUCHDB_PASSWORD')
MY_COUCHDB_STORAGE_DIR     = get_from_env('MY_COUCHDB_STORAGE_DIR',
                               '/home/' + os.environ['USER'] + '/_couchdb_data')
MY_COUCHDB_NETWORK         = get_from_env('MY_COUCHDB_NETWORK', 'couchdbnet')
MY_COUCHDB_EXTRAS          = get_from_env('MY_COUCHDB_EXTRAS', ' ')
MY_COUCHDB_COMMAND         = get_from_env('MY_COUCHDB_COMMAND', ' ')
print('-----  Creating couchdb instance "' + MY_COUCHDB_NAME + '"...  -----')

# Process any command line arguments
restart = True
create = True
connect = True
for i, arg in enumerate(sys.argv[1:]):
  if '-rm' == arg:
    print('Removing everything from ' + MY_COUCHDB_STORAGE_DIR + '...')
    os.system('/bin/rm -rf ' + MY_COUCHDB_STORAGE_DIR + '/* >/dev/null 2>&1')
  elif '-nr' == arg:
    print('*** Will *not* set "--restart=unless-stopped" on the container.')
    restart = False
  elif '-nc' == arg:
    print('*** Will not connect to and secure/configure the couchdb instance!')
    connect = False
  elif '-co' == arg:
    print('*** Will only connect and secure/configure the couchdb instance!')
    create = False
  else:
    print('Usage:')
    print('  ' + sys.argv[0] + ' [options]')
    print('Options:')
    print('  -h    display this help message')
    print('  -rm   remove the contents of the storage directory')
    print('  -nr   do not setup a docker run restart policy')
    print('  -nc   do not connect to the DB to secure and configure')
    print('  -co   do not create the DB, only connect, secure and configure')
    print('Environment environment variables used by this script:')
    print('  MY_COUCHDB_NAME            Instance name (also used as net alias)')
    print('  MY_COUCHDB_PUBLISH_ADDRESS Host address where container will bind')
    print('  MY_COUCHDB_CLIENT_ADDRESS  Address clients can use to connect')
    print('  MY_COUCHDB_HOST_PORT       Host port where container will bind')
    print('  MY_COUCHDB_USER            Admin user name for this instance')
    print('  MY_COUCHDB_PASSWORD        Admin password for this instance')
    print('  MY_COUCHDB_STORAGE_DIR     File system couchdb storage path')
    print('  MY_COUCHDB_NETWORK         Docker bridge network for couchdb')
    print('  MY_COUCHDB_EXTRAS          `docker run` extras (e.g., mount pwd)')
    print('  MY_COUCHDB_COMMAND         Optional command for `docker run`')
    sys.exit()

# Setup the storage directory if appropriate
if '' == MY_COUCHDB_STORAGE_DIR:
  sys.exit('Variable "MY_COUCHDB_STORAGE_DIR" must not be empty.')
if not os.path.isdir(MY_COUCHDB_STORAGE_DIR):
  print('Creating ' + MY_COUCHDB_STORAGE_DIR + ' since it does not exist...')
  os.system('/bin/mkdir -p ' + MY_COUCHDB_STORAGE_DIR + ' >/dev/null 2>&1')

# Store the DB handle here
couchdbserver = None

# Start up the couchdb container instance
def create():

  # Terminate any existing container with this name
  print('Removing any existing container named, "' + MY_COUCHDB_NAME + '"...')
  terminate = 'docker rm -f ' + MY_COUCHDB_NAME + ' >/dev/null 2>&1'
  print('Running: ' + terminate)
  os.system(terminate)

  # Create the docker virtual private bridge network (in case is does not exist)
  print('Creating docker bridge network, "' + MY_COUCHDB_NETWORK + '"...')
  net = 'docker network create ' + MY_COUCHDB_NETWORK + ' >/dev/null 2>&1'
  print('Running: ' + net)
  os.system(net)

  # Create an automatic restart policy, if appropriate
  restart_policy = ''
  if restart:
    restart_policy = '--restart unless-stopped'

  # Run the couchdb container with this configuration
  publish_address = MY_COUCHDB_PUBLISH_ADDRESS + ':' + str(MY_COUCHDB_HOST_PORT)
  print('Starting couchdb server bound to ' + publish_address)
  run = \
    'docker run -d ' + \
      MY_COUCHDB_EXTRAS + ' ' + \
      '--name ' + MY_COUCHDB_NAME + ' ' + \
      restart_policy + ' ' + \
      '--publish ' + publish_address + ':5984 ' + \
      '--volume ' + MY_COUCHDB_STORAGE_DIR + ':/data ' + \
      '--net ' + MY_COUCHDB_NETWORK + ' ' + \
      '--net-alias ' + MY_COUCHDB_NAME + ' ' + \
      'couchdb ' + MY_COUCHDB_COMMAND
  print('Running: ' + run.strip())
  os.system(run.strip())
  print('The couchdb container has been started. Relax...')
  time.sleep(3)

# Open or create a database in this instance
def get_db(database):
  print('Attempting to open database "' + database + '"...')
  if database in couchdbserver:
    print('Database "' + database + '" already exists.')
    return couchdbserver[database]
  else:
    print('Creating database "' + database + '".')
    return couchdbserver.create(database)

# Connect to the couchdb instance, secure it and configure it
def connect():

  global couchdbserver

  # Try forever to connect
  client_address = MY_COUCHDB_CLIENT_ADDRESS + ':' + str(MY_COUCHDB_HOST_PORT)
  print('Attempting to connect to CouchDB server at ' + client_address + '...')
  while True:
    try:
      couchdbserver = couchdb.Server('http://%s:%s@%s/' % ( \
        MY_COUCHDB_USER, \
        MY_COUCHDB_PASSWORD, \
        client_address))
      if couchdbserver:
        break
    except:
      pass
    print('... CouchDB server not accessible. Will retry ...')
    time.sleep(2)

  # Connected!
  print('Connected to CouchDB server container.')

  # Do the basic setup
  print('Securing couchdb and performing initial configuration...')
  users = get_db('_users')
  replicator = get_db('_replicator')
  global_changes = get_db('_global_changes')

  # Couchdb is setup
  print('CouchDB server is secured and configred. Relax.')
  print('The "Futon" web UI is available at "/_utils"')

if create:
  create()

if connect:
  connect()

print('Done.')

