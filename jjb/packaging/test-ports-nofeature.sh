#!/bin/bash

# Options:
#   -x: Echo commands
#   -e: Fail on errors
#   -o pipefail: Fail on errors in scripts this calls, give stacktrace
set -ex -o pipefail

# Ports that should only be open after odl-nevirt-openstack is installed
# 8080 is Nitrogen and Carbon only, not Oxygen
# TODO: Add checks that account for these
# shellcheck disable=SC2034
declare -a unexpected_ports=("2550" "6633" "6640" "6644" "6653" "8080" "8181" "8185")

# Ports that should be open after ODL is started with default features
# Port 1099: Karaf rmiRegistryPort
# Port 8101: Karaf SSH Shell port
# Port 34551: ???
# Port 35710: ???
# Port 44444: Karaf rmiServerPort
declare -a expected_ports=("1099" "8101" "34551" "35710" "44444")

COUNT="0"
while true; do
    open_ports=()
    closed_ports=()
    for port in "${expected_ports[@]}"
    do
        if nmap -Pn -p$port localhost | grep -q open; then
            echo "Port $port is open"
            open_ports+=($port)
        else
            echo "Port $port is not yet open"
            closed_ports+=($port)
        fi
    done
    if [[ ${#open_ports[@]} -eq ${#expected_ports[@]} && ${#closed_ports[@]} -eq 0 ]]; then
        echo "All expected ports are open"
        echo "Open ports:"
        printf '%s\n' "${open_ports[@]}"
        echo "Closed ports:"
        printf '%s\n' "${closed_ports[@]}"
        break
    elif [ $COUNT -gt 120 ]; then
        echo "Timeout waiting ports to open"
        echo "Open ports:"
        printf '%s\n' "${open_ports[@]}"
        echo "Closed ports:"
        printf '%s\n' "${closed_ports[@]}"
        exit 1
    else
        ((COUNT+=5))
        sleep 5
    fi
done

netstat -pnatu
