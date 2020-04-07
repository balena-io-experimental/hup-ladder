#!/bin/bash

if [ -z "${UUID}" ]; then
    echo "need to assign \$UUID"
    exit 1
fi
if [ -z "${TOKEN}" ]; then
    echo "need to assign \$TOKEN"
    exit 1
fi

# TODO: uses staging by default
BALENA_URL="https://api.balena-staging.com"
BALENA_DEVICES_URL="https://actions.balena-staging-devices.com/v1"

device_data=$(curl -qs "${BALENA_URL}/v5/device?\$filter=uuid%20eq%20'${UUID}'&\$select=device_type,os_version,os_variant" -H "authorization: Bearer ${TOKEN}" | jq '.d[0]')

starting_ver=$(echo "${device_data}" | jq -r '.os_version' | awk '{print $NF}')
variant=$(echo "${device_data}" | jq -r '.os_variant')
device_type=$(echo "${device_data}" | jq -r '.device_type')
echo "Starting with: ${starting_ver} for device-type: ${device_type} and variant: ${variant}"

versions=$(curl -qs -H "Content-type: application/json" -H "Authorization: Bearer ${TOKEN}" "${BALENA_URL}/device-types/v1/${device_type}/images" | jq -r ".versions[] | match(\".*${variant}\"; \"g\").string" | sort -V)

if [[ ${RANDOM_ORDER} = true ]]; then
    versions=$(echo "${versions}" | shuf)
fi

skip=${SKIP:-0}
for v in ${versions}; do
    if dpkg --compare-versions "${v}" "gt" "${starting_ver}.${variant}"; then
        if [[ "${skip}" -gt 0 ]]; then
            skip=$(( skip - 1 ))
            echo "skipping ${starting_ver} (\$SKIP defined and > 0)"
        else
            echo "${v} gt ${starting_ver}.${variant}, sending HUP"
            hup=$(curl -qs -H "Content-type: application/json" -H "Authorization: Bearer ${TOKEN}" "${BALENA_DEVICES_URL}/${UUID}/resinhup" -d "{\"parameters\": {\"target_version\": \"${v}\"}}" | jq -r '.error')
            while [ "${hup}" == "Device is not online" ]; do
                sleep 10
                hup=$(curl -qs -H "Content-type: application/json" -H "Authorization: Bearer ${TOKEN}" "${BALENA_DEVICES_URL}/${UUID}/resinhup" -d "{\"parameters\": {\"target_version\": \"${v}\"}}" | jq -r '.error')
            done
            status=$(curl -qs -H "Content-type: application/json" -H "Authorization: Bearer ${TOKEN}" "${BALENA_DEVICES_URL}/${UUID}/resinhup" | jq -r '.status')
            while [ "${status}" != "error" ] && [ "${status}" != "done" ]; do
                sleep 60
                status=$(curl -qs -H "Content-type: application/json" -H "Authorization: Bearer ${TOKEN}" "${BALENA_DEVICES_URL}/${UUID}/resinhup" | jq -r '.status')
            done
            if [ "${status}" == "error" ]; then
                echo "HUP failed, ${starting_ver} to ${v}"
                exit 1
            fi
            new_starting_ver=$(curl -qs -k "${BALENA_URL}/v5/device?\$filter=uuid%20eq%20'${UUID}'&\$select=os_version" -H "authorization: Bearer ${TOKEN}" | jq -r '.d[0].os_version' | awk '{print $NF}')
            while [ "${new_starting_ver}" == "${starting_ver}" ]; do
                new_starting_ver=$(curl -qs -k "${BALENA_URL}/v5/device?\$filter=uuid%20eq%20'${UUID}'&\$select=os_version" -H "authorization: Bearer ${TOKEN}" | jq -r '.d[0].os_version' | awk '{print $NF}')
                sleep 60
            done
            starting_ver="${new_starting_ver}"
        fi
    fi
done
