echo "Install other Coordinator dependencies"
sudo yum install -q -y uuid libxslt libcurl unixODBC json-c

cd "/tmp"
CTR_IP="${CONTROLLER0}"

USER=`id -nu`
GROUP=`id -ng`

echo "USER is ${USER}"
echo "GROUP is ${GROUP}"
echo "Installing the VTN Coordinator..."
sudo chown "${USER}":"${GROUP}" "/usr/local/vtn"
echo "Clearing the /usr/local/vtn"
rm -rf /usr/local/vtn/*
tar -C/ -jxvf ${BUNDLEFOLDER}/externalapps/*vtn-coordinator*.bz2

echo "Starting VTN Coordinator daemon..."
/usr/local/vtn/sbin/db_setup
/usr/local/vtn/bin/vtn_start

echo "Checking if VTN Coordinator is up and running..."
COUNT="0"
while true; do
    RESP="$( curl --user admin:adminpass -sL -w "%{http_code} %{url_effective}\\n" http://127.0.0.1:8083/vtn-webapi/api_version.json -o /dev/null )"
    echo $RESP
    echo $RESP
    if [[ $RESP == *"200"* ]]; then
        echo VTN Coordinator is UP
        break
    elif (( "$COUNT" > "60" )); then
        echo Timeout VTN Coordinator is DOWN
        exit 1
    else
        COUNT=$(( ${COUNT} + 5 ))
        sleep 5
        echo waiting $COUNT secs...
    fi
done
    echo "CTRP is $CTR_IP"
    RESP_CTR="$( curl --user admin:admin -sL -w "%{http_code} %{url_effective}\\n" http://\$CTR_IP:8282/controller/nb/v2/vtn/version -o /dev/null )"
    echo "$RESP_CTR"
