#!/bin/bash

# vim: sw=2 ts=2 sts=2 et :

if [ -f /.autorelabel ]; then
  echo "**********************************************"
  echo "* SYSTEM REQUIRES RELABELING SKIPPING RESEAL *"
  echo "*     PLEASE RESTART SYSTEM AND RERUN        *"
  echo "*           PROVISIONING SCRIPTS             *"
  echo "**********************************************"
  exit 1;
fi

# clean-up from any prior cloud-init networking
rm -rf /etc/sysconfig/network-scripts/{ifcfg,route}-eth*

rm -rf /etc/Pegasus/*.cnf /etc/Pegasus/*.crt /etc/Pegasus/*.csr /etc/Pegasus/*.pem /etc/Pegasus/*.srl /root/anaconda-ks.cfg /root/anaconda-post.log /root/initial-setup-ks.cfg /root/install.log /root/install.log.syslog /var/cache/fontconfig/* /var/cache/gdm/* /var/cache/man/* /var/lib/AccountService/users/* /var/lib/fprint/* /var/lib/logrotate.status /var/log/*.log* /var/log/BackupPC/LOG /var/log/ConsoleKit/* /var/log/anaconda.syslog /var/log/anaconda/* /var/log/apache2/*_log /var/log/apache2/*_log-* /var/log/apt/* /var/log/aptitude* /var/log/audit/* /var/log/btmp* /var/log/ceph/*.log /var/log/chrony/*.log /var/log/cron* /var/log/cups/*_log /var/log/debug* /var/log/dmesg* /var/log/exim4/* /var/log/faillog* /var/log/gdm/* /var/log/glusterfs/*glusterd.vol.log /var/log/glusterfs/glusterfs.log /var/log/httpd/*log /var/log/installer/* /var/log/jetty/jetty-console.log /var/log/journal/* /var/log/lastlog* /var/log/libvirt/libvirtd.log /var/log/libvirt/lxc/*.log /var/log/libvirt/qemu/*.log /var/log/libvirt/uml/*.log /var/log/lightdm/* /var/log/mail/* /var/log/maillog* /var/log/messages* /var/log/ntp /var/log/ntpstats/* /var/log/ppp/connect-errors /var/log/rhsm/* /var/log/sa/* /var/log/secure* /var/log/setroubleshoot/*.log /var/log/spooler* /var/log/squid/*.log /var/log/syslog* /var/log/tallylog* /var/log/tuned/tuned.log /var/log/wtmp* /var/named/data/named.run

rm -rf ~/.viminfo /etc/ssh/ssh*key*

# kill any cloud-init related bits
rm -rf /var/lib/cloud/*

if [ -e /usr/bin/facter ]
then
  if [ `/usr/bin/facter operatingsystem` = 'Ubuntu' ]
  then
    rm -rf /etc/hostname* /etc/hosts /etc/network/interfaces /etc/network/interfaces.*.bak~
    cat <<EOINT >> /etc/network/interfaces
# Used by ifup(8) and ifdown(8). See the interfaces(5) manpage or
# /usr/share/doc/ifupdown/examples for more information.
# The loopback network interface
auto lo
iface lo inet loopback
EOINT
  fi
fi

echo "********************************************"
echo "*   PLEASE SNAPSHOT IMAGE AT THIS TIME     *"
echo "********************************************"
