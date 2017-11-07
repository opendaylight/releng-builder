#!/bin/bash
source ${ROBOT_VENV}/bin/activate
echo "---> installing the quagga on centos and ubuntu16 "
set +e
thirft_v=${QUAGGA_VERSION}
echo "print quagga version : \$qv"
cat > ${WORKSPACE}/quagga_script.sh <<EOF
#FACTER_OS=$(/usr/bin/facter operatingsystem | tr '[:upper:]' '[:lower:]')
Nexus_url="https://nexus.opendaylight.org/content/repositories/thirdparty/quagga\${thirft_v}"
HOST_NAME=\`hostname\`
case \$HOST_NAME in
    *java*)
        # install the QBGP packages on centos host
        if [ -d "/tmp/install-quagga" ]; then
              sudo rm -rf /tmp/install-quagga
        fi
        sudo mkdir /tmp/install-quagga/
        cd /tmp/install-quagga/
        c_capn="c-capnproto/1.0.2.75f7901.CentOS7.4.1708-0.x86_64/c-capnproto-1.0.2.75f7901.CentOS7.4.1708-0.x86_64"
        thirft="thrift/1.0.0.b2a4d4a.CentOS7.4.1708-0.x86_64/thrift-1.0.0.b2a4d4a.CentOS7.4.1708-0.x86_64"
        zmq="zmq/4.1.3.56b71af.CentOS7.4.1708-0.x86_64/zmq-4.1.3.56b71af.CentOS7.4.1708-0.x86_64"
        quagga="quagga/1.1.0.837f143.CentOS7.4.1708-0.x86_64/quagga-1.1.0.837f143.CentOS7.4.1708-0.x86_64"
        zrpc="zrpc/0.2.56d11ae.thriftv\${thirft_v}.CentOS7.4.1708-0.x86_64/zrpc-0.2.56d11ae.thriftv\${thirft_v}.CentOS7.4.1708-0.x86_64"
        for pkg in \$c_capn \$thirft \$zmq \$quagga \$zrp
	   do
              sudo wget \$Nexus_url/\$pkg.rpm
           done
	for rpms in thrift zmq c-capnproto quagga zrp
	   do 
	      sudo rpm -Uvh \$rpms*.rpm
           done
;;
    *devstack*)
	echo "6wind quagga is not supported on devstack"
;;

    *)
        # install the QBGP packages on ubuntu host
        if [ -d "/tmp/install-quagga" ]; then
           sudo rm -rf /tmp/install-quagga
        fi
        sudo mkdir -p /tmp/install-quagga/
        cd /tmp/install-quagga/
        c_capn="c-capnproto/1.0.2.75f7901.Ubuntu16.04/c-capnproto-1.0.2.75f7901.Ubuntu16.04"
        thirft="thrift/1.0.0.b2a4d4a.Ubuntu16.04/thrift-1.0.0.b2a4d4a.Ubuntu16.04"
        zmq="zmq/4.1.3.56b71af.Ubuntu16.04/zmq-4.1.3.56b71af.Ubuntu16.04"
        quagga="quagga/1.1.0.837f143.Ubuntu16.04/quagga-1.1.0.837f143.Ubuntu16.04"
        zrpc="zrpc/0.2.56d11ae.thriftv\${thirft_v}.Ubuntu16.04/zrpc-0.2.56d11ae.thriftv\${thirft_v}.Ubuntu16.04"
        for pkg in \$c_capn \$thirft \$zmq \$quagga \$zrpc
          do
            sudo wget \$Nexus_url/\$pkg.deb
          done
        for rpms in thrift zmq c-capnproto quagga zrpc
          do
            sudo dpkg -i  \$rpms*.deb
          done
;;
esac

EOF

# Copy quagga-install-script to controller and execute it.
for i in `seq 1 ${NUM_ODL_SYSTEM}`
do
    CONTROLLERIP=ODL_SYSTEM_${i}_IP
    echo "$CONTROLLERIP"
    echo "Execute the quagga-install-script on controller ${!CONTROLLERIP}"
    scp ${WORKSPACE}/quagga_script.sh ${!CONTROLLERIP}:/tmp
    ssh ${!CONTROLLERIP} "bash /tmp/quagga_script.sh"
done

# Copy quagga-install-script to mininets and execute it.
for i in `seq 1 ${NUM_TOOLS_SYSTEM}`
do
    MININETIP=TOOLS_SYSTEM_${i}_IP
    echo "Execute the quagga-install script on mininet ${!MININETIP}"
    scp ${WORKSPACE}/quagga_script.sh ${!MININETIP}:/tmp
    ssh ${!MININETIP} 'bash /tmp/quagga_script.sh'
done
