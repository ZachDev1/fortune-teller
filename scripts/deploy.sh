#!/usr/bin/env bash

# Build apps
./mvnw clean package

# Deploy services
CF_API=`cf api | head -1 | cut -c 25-`

if [ ! -z "`cf m | grep "p\.config-server"`" ]; then
  export service_name="p.config-server"
  export config_json="{\"git\": { \"uri\": \"https://github.com/ZachDev1/fortune-teller\", \"searchPaths\": \"configuration\" } }"
elif [ ! -z "`cf m | grep "p-config-server"`" ]; then
  export service_name="p-config-server"
  export config_json="{\"skipSslValidation\": true, \"git\": { \"uri\": \"https://github.com/ZachDev1/fortune-teller\", \"searchPaths\": \"configuration\" } }"
else
  echo "Can't find SCS Config Server in marketplace. Have you installed the SCS Tile?"
  exit 1;
fi

cf cs p.mysql db-small fortunes-db
cf cs $service_name standard fortunes-config-server -c "$config_json"
cf cs p-service-registry standard fortunes-service-registry
cf cs p-rabbitmq standard fortunes-cloud-bus


# Prepare config file to set TRUST_CERTS value
echo "cf_trust_certs: $CF_API" > vars.yml

# Wait until services are ready
while cf services | grep 'create in progress'
do
  sleep 20
  echo "Waiting for services to initialize..."
done

# Check to see if any services failed to create
if cf services | grep 'create failed'; then
  echo "Service initialization - failed. Exiting."
  return 1
fi
echo "Service initialization - successful"

# Push apps
cf push -f manifest.yml --vars-file vars.yml





