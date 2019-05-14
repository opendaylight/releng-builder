#!/bin/bash

# Options:
#   -x: Echo commands
#   -e: Fail on errors
#   -o pipefail: Fail on errors in scripts this calls, give stacktrace
set -ex -o pipefail

# Ports that should be open after ODL is started with default features
# Port 1099: Karaf rmiRegistryPort
# Port 8101: Karaf SSH Shell port
# Port 44444: Karaf rmiServerPort
declare -a expected_ports=("1099" "8101" "44444")

# Ports that should only be open after odl-nevirt-openstack is installed
declare -a unexpected_ports=("2550" "6633" "6640" "6644" "6653" "8181" "8185")

# Make sure expected ports open
COUNT="0"
while true; do
    open_ports=()
    closed_ports=()
    for port in "${expected_ports[@]}"
    do
        if nmap -Pn -p"$port" localhost | grep -q open; then
            echo "Port $port is open"
            open_ports+=("$port")
        else
            echo "Port $port is not yet open"
            closed_ports+=("$port")
        fi
    done
    if [[ ${#open_ports[@]} -eq ${#expected_ports[@]} && ${#closed_ports[@]} -eq 0 ]]; then
        echo "All expected ports are open"
        echo "Open ports:"
        printf '%s\n' "${open_ports[@]}"
        echo "Closed ports:"
        printf '%s\n' "${closed_ports[@]}"
        break
    elif [ $COUNT -gt 300 ]; then
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

# Make sure unexpected ports are not open
open_ports=()
closed_ports=()
for port in "${unexpected_ports[@]}"
do
    if nmap -Pn -p"$port" localhost | grep -q open; then
        echo "Port $port is open"
        open_ports+=("$port")
    else
        echo "Port $port is not open"
        closed_ports+=("$port")
    fi
done
if [[ ${#closed_ports[@]} -eq ${#unexpected_ports[@]} && ${#open_ports[@]} -eq 0 ]]; then
    echo "No unexpected ports are open"
    echo "Open ports:"
    printf '%s\n' "${open_ports[@]}"
    echo "Closed ports:"
    printf '%s\n' "${closed_ports[@]}"
fi
