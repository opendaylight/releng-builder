#!/bin/bash -x

# vim: sw=4 ts=4 sts=4 et tw=72 :

# force any errors to cause the script and job to end in failure
set -xeu -o pipefail

# Ensure that necessary variables are set to enable noninteractive mode in
# commands.
export DEBIAN_FRONTEND=noninteractive

# To handle the prompt style that is expected all over the environment
# with how use use robotframework we need to make sure that it is
# consistent for any of the users that are created during dynamic spin
# ups
echo 'PS1="[\u@\h \W]> "' >> /etc/skel/.bashrc

echo "Quagga install procedure"
Nexus_url="https://nexus.opendaylight.org/content/repositories/thirdparty/quagga4"
c_capn="c-capnproto/1.0.2.75f7901.Ubuntu16.04/c-capnproto-1.0.2.75f7901.Ubuntu16.04"
thirft="thrift/1.0.0.b2a4d4a.Ubuntu16.04/thrift-1.0.0.b2a4d4a.Ubuntu16.04"
zmq="zmq/4.1.3.56b71af.Ubuntu16.04/zmq-4.1.3.56b71af.Ubuntu16.04"
quagga="quagga/1.1.0.837f143.Ubuntu16.04/quagga-1.1.0.837f143.Ubuntu16.04"
zrpc="zrpc/0.2.56d11ae.thriftv4.Ubuntu16.04/zrpc-0.2.56d11ae.thriftv4.Ubuntu16.04"

echo '---> Installing Quagga debian packages'
rm -rf /tmp/install-quagga
mkdir /tmp/install-quagga/
cd /tmp/install-quagga/
for pkg in \${c_capn} \${thirft} \${zmq} \${quagga} \${zrpc}
do
    wget \${Nexus_url}/\${pkg}.deb
done
dpkg -i thrift-1.0.0.b2a4d4a.Ubuntu16.04.deb
dpkg -i c-capnproto-1.0.2.75f7901.Ubuntu16.04.deb
dpkg -i zmq-4.1.3.56b71af.Ubuntu16.04.deb
dpkg -i quagga-1.1.0.837f143.Ubuntu16.04.deb
dpkg -i zrpc-0.2.56d11ae.thriftv4.Ubuntu16.04.deb
echo '---> Finished installing Quagga'
