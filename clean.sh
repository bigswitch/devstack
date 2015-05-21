#!/bin/bash

# **clean.sh**

# ``clean.sh`` does its best to eradicate traces of a Grenade
# run except for the following:
# - both base and target code repos are left alone
# - packages (system and pip) are left alone

# This means that all data files are removed.  More??

# Keep track of the current devstack directory.
TOP_DIR=$(cd $(dirname "$0") && pwd)

# Import common functions
source $TOP_DIR/functions

FILES=$TOP_DIR/files

# Load local configuration
source $TOP_DIR/openrc

# Get the variables that are set in stack.sh
if [[ -r $TOP_DIR/.stackenv ]]; then
    source $TOP_DIR/.stackenv
fi

# Determine what system we are running on.  This provides ``os_VENDOR``,
# ``os_RELEASE``, ``os_UPDATE``, ``os_PACKAGE``, ``os_CODENAME``
# and ``DISTRO``
GetDistro

# Import apache functions
source $TOP_DIR/lib/apache
source $TOP_DIR/lib/ldap

# Import database library
source $TOP_DIR/lib/database
source $TOP_DIR/lib/rpc_backend

source $TOP_DIR/lib/tls

source $TOP_DIR/lib/oslo
source $TOP_DIR/lib/horizon
source $TOP_DIR/lib/keystone
source $TOP_DIR/lib/glance
source $TOP_DIR/lib/nova
source $TOP_DIR/lib/cinder
source $TOP_DIR/lib/swift
source $TOP_DIR/lib/ceilometer
source $TOP_DIR/lib/heat
source $TOP_DIR/lib/neutron-legacy
source $TOP_DIR/lib/ironic


# Extras Source
# --------------

# Phase: source
if [[ -d $TOP_DIR/extras.d ]]; then
    for i in $TOP_DIR/extras.d/*.sh; do
        [[ -r $i ]] && source $i source
    done
fi

# See if there is anything running...
# need to adapt when run_service is merged
SESSION=$(screen -ls | awk '/[0-9].stack/ { print $1 }')
if [[ -n "$SESSION" ]]; then
    # Let unstack.sh do its thing first
    $TOP_DIR/unstack.sh --all
fi

# Run extras
# ==========

# Phase: clean
load_plugin_settings
run_phase clean

if [[ -d $TOP_DIR/extras.d ]]; then
    for i in $TOP_DIR/extras.d/*.sh; do
        [[ -r $i ]] && source $i clean
    done
fi

# Clean projects

# BUG: cinder tgt doesn't exit cleanly if it's not running.
cleanup_cinder || /bin/true

cleanup_glance
cleanup_keystone
cleanup_nova
cleanup_neutron
cleanup_swift

if is_service_enabled ldap; then
    cleanup_ldap
fi

# Do the hypervisor cleanup until this can be moved back into lib/nova
if is_service_enabled nova && [[ -r $NOVA_PLUGINS/hypervisor-$VIRT_DRIVER ]]; then
    cleanup_nova_hypervisor
fi

# Clean out /etc
sudo rm -rf /etc/keystone /etc/glance /etc/nova /etc/cinder /etc/swift /etc/heat /etc/neutron

# Clean out tgt
sudo rm -f /etc/tgt/conf.d/*

# Clean up the message queue
cleanup_rpc_backend
cleanup_database

# Clean out data and status
sudo rm -rf $DATA_DIR $DEST/status

# Clean out the log file and log directories
if [[ -n "$LOGFILE" ]] && [[ -f "$LOGFILE" ]]; then
    sudo rm -f $LOGFILE
fi
if [[ -n "$LOGDIR" ]] && [[ -d "$LOGDIR" ]]; then
    sudo rm -rf $LOGDIR
fi
if [[ -n "$SCREEN_LOGDIR" ]] && [[ -d "$SCREEN_LOGDIR" ]]; then
    sudo rm -rf $SCREEN_LOGDIR
fi

# Clean up venvs
DIRS_TO_CLEAN="$WHEELHOUSE ${PROJECT_VENV[@]} .config/openstack"
rm -rf $DIRS_TO_CLEAN

# Clean up files

FILES_TO_CLEAN=".localrc.auto docs/files docs/html shocco/ stack-screenrc test*.conf* test.ini*"
FILES_TO_CLEAN+=".stackenv .prereqs"

for file in $FILES_TO_CLEAN; do
    rm -rf $TOP_DIR/$file
done
