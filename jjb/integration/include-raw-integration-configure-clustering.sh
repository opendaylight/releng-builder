echo "##################################################"
echo "## include-raw-integration-configure-clustering ##"
echo "##################################################"

#  this script configures replication on a single ODL controller.
#  files touched are akka.conf modules-shards.conf



echo "##################################"
echo "##  Loop through controller IPs  #"
echo "##################################"

declare CONTROLLERIPS=($(cat slave_addresses.txt | grep CONTROLLER | awk -F = '{print $2}'))
declare -p CONTROLLERIPS




## Describe  the script run on guest vm (node) to configure clustering


cat > ${WORKSPACE}/configuration-script.sh <<EOF
   source /tmp/configuration-functions.sh
   # Functions used to edit akka.comf and module-shards
   editakkaconf \$1
   configuremoduleshardsconf \$1 

EOF



# Describe CONFIGURATION FUNCTIONS  available for the  script above
CONFIGURATIONFUNCTIONS='configuration-functions.sh'

set -x
for  i in "${!CONTROLLERIPS[@]}"
do
   echo "IP address of node is: $i and index is   ${CONTROLLERIPS[$i]}"
   scp -v ${WORKSPACE}/slave_addresses.txt  ${CONTROLLERIPS[$i]}:/tmp

   scp -v ${WORKSPACE}/configuration-functions.sh ${CONTROLLERIPS[$i]}:/tmp
   scp -v ${WORKSPACE}/configuration-script.sh    ${CONTROLLERIPS[$i]}:/tmp

   echo "configure controller $CONTROLLERIP on $i" 


   ssh -v ${CONTROLLERIPS[$i]} 'bash /tmp/configuration-script.sh'  
done
set +x


echo "######################################################"
echo "## END include-raw-integration-configure-clustering ##"
echo "######################################################"

