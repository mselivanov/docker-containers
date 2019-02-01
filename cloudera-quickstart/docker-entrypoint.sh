#! /usr/bin/env bash

DAEMONS="\
    mysqld \
    cloudera-quickstart-init"

if [ -e /var/lib/cloudera-quickstart/.kerberos ]; then
    DAEMONS="${DAEMONS} \
        krb5kdc \
        kadmin"
fi

for daemon in ${DAEMONS}; do
    sudo service ${daemon} start
done

cd /home/cloudera

CM_API=/home/cloudera/cm_api.py
CM_CLUSTER_NAME='Cloudera QuickStart'

function fix_ntp() {
    /etc/init.d/ntpd stop
    ntpdate ntp.org
    /etc/init.d/ntpd start
    chkconfig --add ntpd
    chkconfig ntpd on
}

function terminate() {
    if [ "${PAUSE}" == 'true' ]; then
        echo ""
        read -p "Press [Enter] to exit..."
    fi
    exit ${1}
}

function ensure_user_is_root() {
    if [[ "$EUID" -ne "0" ]]; then
        echo "You must run this script as root. Try 'sudo ${0} ${@}'."
        terminate 1
    fi
}

function parse_arguments() {
    for argument in ${@}; do
        if [ "${argument}" == '--force' ]; then
            export FORCE='true'
        elif [ "${argument}" == '--pause' ]; then
            export PAUSE='true'
        elif [ "${argument}" == '--express' ]; then
            export FLAVOR='express'
        elif [ "${argument}" == '--enterprise' ]; then
            export FLAVOR='enterprise'
        else
            echo "Unknown option: ${argument}"
            terminate 1
        fi
    done
    if [ -z "${FLAVOR}" ]; then
        echo "You must specify --express or --enterprise"
        terminate 1
    fi
}

function check_status_and_hardware() {
    if service cloudera-scm-server status > /dev/null 2>&1; then
        cat <<EOF

NOTE: Cloudera Manager is already launched. If you cannot connect, it may still
be starting. Please wait a few minutes.

EOF
        FAIL='true'
    fi

    RAM=$(free -m | head -2 | tail -1 | awk '{ print $2 }')
    # MIN_MB is what is reported in a VirtualBox guest with 8,000 or 10,000 MB, respectively

    MIN_MB=7870
    MIN_GB=8
    PRODUCT='Express'

    if [ "${RAM}" -lt "${MIN_MB}" ]; then
        cat <<EOF

WARNING: It is highly recommended that you run Cloudera ${PRODUCT} in a VM with
at least ${MIN_GB} GB of RAM.

EOF
        FAIL='true'
    fi

    #vCPUs=`expr $(cat /proc/cpuinfo | grep 'processor\s\+:\s' | tail -1 | awk '{ print $3 }') + 1`
    vCPUs=`nproc`
    MIN_vCPUs=2
    if [ "${vCPUs}" -lt "${MIN_vCPUs}" ]; then
        cat <<EOF

WARNING: It is highly recommended that you run Cloudera Manager in a VM with at
least 2 Virtual CPUs or cores. Please shutdown the VM, add an additional CPU or
CPU core in your hypervisor, and restart the VM.

EOF
        FAIL='true'
    fi

    if [ "${FAIL}" == 'true' ]; then
        cat <<EOF

You can override these checks by passing in the --force option,
e.g:

    sudo ${0} --force
EOF
        terminate 1
    fi
}

function log() {
    echo "[QuickStart] ${1}"
}

# Shutdown order in the Sys V init system (reverse of the Startup order)
CDH_SERVICES="impala-server impala-catalog sqoop-metastore solr-server oozie impala-state-store hue flume-ng-agent hbase-regionserver sqoop2-server spark-history-server sentry-store hive-server2 hive-metastore hbase-thrift hbase-rest hbase-master hadoop-yarn-resourcemanager hadoop-yarn-proxyserver hadoop-yarn-nodemanager hadoop-mapreduce-historyserver hadoop-httpfs hadoop-hdfs-secondarynamenode hadoop-hdfs-namenode hadoop-hdfs-journalnode hadoop-hdfs-datanode hbase-solr-indexer zookeeper-server"
CM_SERVICES="cloudera-scm-server cloudera-scm-agent"

ensure_user_is_root
parse_arguments ${@}
if [ "${FORCE}" != 'true' ]; then
    check_status_and_hardware
fi

touch /var/tmp/cm_api.log
chmod +rw /var/tmp/cm_api.log

log 'Fixing ntp...'
fix_ntp

log 'Shutting down CDH services via init scripts...'
for service in ${CDH_SERVICES}; do service ${service} stop 2>&1 > /dev/null; done

log 'Disabling CDH services on boot...'
for service in ${CDH_SERVICES}; do chkconfig ${service} off; done

touch /var/lib/cloudera-quickstart/.cloudera-manager

CONFIG_JS=/var/lib/cloudera-quickstart/tutorial/js/config.js
sed -i -e "s/^var managed.\\+=.*/var managed = '${PRODUCT,,}';/" ${CONFIG_JS}

log 'Starting Cloudera Manager server...'
service cloudera-scm-server start 2>&1 > /dev/null

log 'Waiting for Cloudera Manager API...'
${CM_API} live-echo > /dev/null

log 'Starting Cloudera Manager agent...'
service cloudera-scm-agent start 2>&1 > /dev/null

log 'Configuring deployment...'
${CM_API} live-deployment < ${FLAVOR}-deployment.json > /dev/null
${CM_API} --method POST "clusters/${CM_CLUSTER_NAME}/services/sqoop/commands/sqoopCreateDatabaseTables" > /dev/null

log 'Deploying client configuration...'
${CM_API} --method POST "clusters/${CM_CLUSTER_NAME}/commands/deployClientConfig" > /dev/null

log 'Starting Cloudera Management Service...'
${CM_API} --method POST '/cm/service/commands/start' > /dev/null

log 'Enabling Cloudera Manager daemons on boot...'
for service in ${CM_SERVICES}; do chkconfig ${service} on;  done

log 'Starting ZooKeeper...'
${CM_API} --method=POST "clusters/${CM_CLUSTER_NAME}/services/zookeeper/commands/start" #> /dev/null

log 'Starting HDFS...'
${CM_API} --method=POST "clusters/${CM_CLUSTER_NAME}/services/hdfs/commands/start" #> /dev/null

#log 'Starting HBASE...'
#${CM_API} --method=POST "clusters/${CM_CLUSTER_NAME}/services/hbase/commands/start" #> /dev/null

log 'Starting Yarn...'
${CM_API} --method=POST "clusters/${CM_CLUSTER_NAME}/services/yarn/commands/start" #> /dev/null

#log 'Starting Hive...'
#${CM_API} --method=POST "clusters/${CM_CLUSTER_NAME}/services/hive/commands/start" #> /dev/null

#log 'Starting Hue...'
#${CM_API} --method=POST "clusters/${CM_CLUSTER_NAME}/services/hue/commands/start" #> /dev/null

cat <<EOF
________________________________________________________________________________

Success! You can now log into Cloudera Manager from the QuickStart VM's browser:

    http://quickstart.cloudera:7180

    Username: cloudera
    Password: cloudera

EOF

log 'Sleeping...'
while true
do 
    sleep 32767
done
