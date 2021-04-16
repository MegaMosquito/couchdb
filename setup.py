#!/usr/bin/python3
import os
import time

# Don't forget to `pip install couchdb`
import couchdb

# Configure all of these "MY_" environment variables for your situation
MY_COUCHDB_ADDRESS        = os.environ['MY_COUCHDB_ADDRESS']
MY_COUCHDB_PORT           = int(os.environ['MY_COUCHDB_PORT'])
MY_COUCHDB_USER           = os.environ['MY_COUCHDB_USER']
MY_COUCHDB_PASSWORD       = os.environ['MY_COUCHDB_PASSWORD']

# Store the DB handle here
couchdbserver = None

# Try forever to connect
print("Attempting to connect to CouchDB server at " + MY_COUCHDB_ADDRESS + ":" + str(MY_COUCHDB_PORT) + "...")
while True:
  try:
    couchdbserver = couchdb.Server('http://%s:%s@%s:%d/' % ( \
      MY_COUCHDB_USER, \
      MY_COUCHDB_PASSWORD, \
      MY_COUCHDB_ADDRESS, \
      MY_COUCHDB_PORT))
    if couchdbserver:
      break
  except:
    pass
  print("... CouchDB server not accessible. Will retry ...")
  time.sleep(2)

# Connected!
print("Connected to CouchDB server.")

# Do the basic setup
print('Performing initial database creation and configuration...')
users = couchdbserver.create('_users')
replicator = couchdbserver.create('_replicator')
global_changes = couchdbserver.create('_global_changes')

# Done!
print("CouchDB server setup completed successully.")
