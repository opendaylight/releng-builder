#  this script configures replication on a single ODL controller.
#  files touched are akka.conf modules-shards.conf

echo "##################################################"
echo "## include-raw-integration-configure-clustering ##"
echo "##################################################"




echo "##################################"
echo "##  Loop through controller IPs  #"
echo "##################################"

declare CONTROLLERIPS=($(cat slave_addresses.txt | grep CONTROLLER | awk -F = '{print $2}'))
declare -p CONTROLLERIPS

## Describe  the script run on guest vm (node) to configure clustering
SCRIPT='configuration-script.sh'
cat > ${WORKSPACE}/configuration-script.sh <<EOF

   source configuration-functions.sh
   # Functions used to edit akka.comf and module-shards
   # editakkaconf \$1
   # configuremoduleshardsconf \$1 
   testme \$1 
EOF


# Describe CONFIGURATION FUNCTIONS  available for the  script above
CONFIGURATIONFUNCTIONS='configuration-functions.sh'
cat > ${WORKSPACE}/configuration-functions.sh <<EOF

function testme
{
echo "lets see whats here"
echo "\$1" 
echo "\$2"
ls
ifconfig
}

EOF



set -x
for  i in "${!CONTROLLERIPS[@]}"
do
   echo "IP address of node is: $i and index is   ${CONTROLLERIPS[$i]}"
   scp -v ${WORKSPACE}/$SCRIPT  $CONTROLLERIP:/tmp
   scp -v ${WORKSPACE}/$CONFIGURATIONFUNCTIONS $CONTROLLERIP:/tmp
   echo "configure controller $CONTROLLERIP on $i" 
   ssh -v $CONTROLLERIP 'bash /tmp/$CONFIGURATIONFUNCTIONS'
   ssh -v $CONTROLLERIP 'bash /tmp/$SCRIPT'
  
done
set +x



echo "######################################################"
echo "## END include-raw-integration-configure-clustering ##"
echo "######################################################"

