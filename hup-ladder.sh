#!/bin/bash

BALENA_URL="https://api.balena-staging.com"
BALENA_DEVICES_URL="https://actions.balena-staging-devices.com/v1"

device_data=$(curl -qs "${BALENA_URL}/v5/device?\$filter=uuid%20eq%20'${uuid}'&\$select=device_type,os_version,os_variant" -H "authorization: Bearer ${token}" | jq '.d[0]')

starting_ver=$(echo "${device_data}" | jq -r '.os_version' | awk '{print $NF}')
variant=$(echo "${device_data}" | jq -r '.os_variant')
device_type=$(echo "${device_data}" | jq -r '.device_type')
echo "Starting with: ${starting_ver} for device-type: ${device_type} and variant: ${variant}"

versions=$(curl -qs -H "Content-type: application/json" -H "Authorization: Bearer ${token}" "${BALENA_URL}/device-types/v1/${device_type}/images" | jq -r ".versions[] | match(\".*${variant}\"; \"g\").string" | sort -V)

# TODO first sequential, then random
for v in ${versions}; do
    starting_ver=$(curl -qs -k "${BALENA_URL}/v5/device?\$filter=uuid%20eq%20'${uuid}'&\$select=os_version" -H "authorization: Bearer ${token}" | jq -r '.d[0].os_version' | awk '{print $NF}')
    if dpkg --compare-versions "${v}" "gt" "${starting_ver}.${variant}"; then
        echo "${v} gt ${starting_ver}.${variant}, sending HUP"
        hup=$(curl -qs -H "Content-type: application/json" -H "Authorization: Bearer ${token}" "${BALENA_DEVICES_URL}/${uuid}/resinhup" -d "{\"parameters\": {\"target_version\": \"${v}\"}}" | jq -r '.error')
        while [ "${hup}" == "Device is not online" ]; do
            sleep 5
            hup=$(curl -qs -H "Content-type: application/json" -H "Authorization: Bearer ${token}" "${BALENA_DEVICES_URL}/${uuid}/resinhup" -d "{\"parameters\": {\"target_version\": \"${v}\"}}" | jq -r '.error')
        done
        status=$(curl -qs -H "Content-type: application/json" -H "Authorization: Bearer ${token}" "${BALENA_DEVICES_URL}/${uuid}/resinhup" | jq -r '.status')
        while [ "${status}" != "error" ] && [ "${status}" != "done" ]; do
            sleep 60
            status=$(curl -qs -H "Content-type: application/json" -H "Authorization: Bearer ${token}" "${BALENA_DEVICES_URL}/${uuid}/resinhup" | jq -r '.status')
        done
        if [ "${status}" == "error" ]; then
            echo "HUP failed, ${starting_ver} to ${v}"
            exit 1
        fi
    fi
done
