#!/bin/bash

##################
# Add admin user #
##################

if [ $KEYCLOAK_USER ] && [ $KEYCLOAK_PASSWORD ]; then
    keycloak/bin/add-user-keycloak.sh --sc /opt/jboss/keycloak/domain/servers/server-one/configuration --user $KEYCLOAK_USER --password $KEYCLOAK_PASSWORD
fi

keycloak/bin/add-user-keycloak.sh --sc /opt/jboss/keycloak/domain/servers/server-one/configuration --user --password 

##################
# Add admin management user #
##################
if [ $KEYCLOAK_MGMT_USER ] && [ $KEYCLOAK_MGMT_PASSWORD ]; then
    keycloak/bin/add-user.sh --user $KEYCLOAK_MGMT_USER --password $KEYCLOAK_MGMT_PASSWORD --enable
fi

##################
# Start Keycloak #
##################

exec /opt/jboss/keycloak/bin/domain.sh $@
exit $?
