#!/bin/bash


UPTIME=$(cat /proc/uptime | cut -d' ' -f1)
INSTANCE_TYPE=$(curl -s http://169.254.169.254/latest/meta-data/instance-type)
echo "---------------------"
echo "Estimated job cost"


API_RESPONSE0=$(curl -s https://pricing.vexxhost.net/v1/pricing/${VM_0_FLAVOR}/cost?seconds=${UPTIME%\.*})
API_RESPONSE1=$(curl -s https://pricing.vexxhost.net/v1/pricing/${VM_1_FLAVOR}/cost?seconds=${UPTIME%\.*})

cost0=$(echo $API_RESPONSE0 | grep -o -E "\"cost\":[0-9]+.[0-9]+" | awk -F\: '{print $2}')
cost1=$(echo $API_RESPONSE1 | grep -o -E "\"cost\":[0-9]+.[0-9]+" | awk -F\: '{print $2}')

#resource0=$(echo $API_RESPONSE0 | grep -o -E "\"resource\":^[a-zA-Z0-9_-]*$" | awk -F\: '{print $2}')
#resource1=$(echo $API_RESPONSE1 | grep -o -E "\"resource\":^[a-zA-Z0-9_-]*$" | awk -F\: '{print $2}')

cost_params="$WORKSPACE/estjobcost.log"

cat > "$cost_params" << EOF
time of job:  $UPTIME sec

vm_0_count: $VM_0_COUNT
vm_0_flavor: $VM_0_FLAVOR
vm_0_image: $VM_0_IMAGE
vm_0_cost: $ $cost0
vm_1_count: $VM_1_COUNT
vm_1_flavor: $VM_1_FLAVOR
vm_1_image: $VM_1_IMAGE
vm_1_cost: $ $cost1

Total cost : $ 0$(echo "$cost1 + $cost0" | bc)

EOF

cat "$cost_params" | sed 's/^/    /' 

echo "---------------------"


