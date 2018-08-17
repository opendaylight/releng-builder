#!/bin/bash

# vim: ts=4 sw=4 sts=4 et tw=72 :

# force any errors to cause the script and job to end in failure
set -xeu -o pipefail

enable_service() {
    # Enable services for Ubuntu instances
    # We purposely want to allow globbing to build the package array
    # shellcheck disable=SC2206
    services=($@)

    for service in "${services[@]}"; do
        echo "---> Enable service: $service"
        FACTER_OS=$(/usr/bin/facter operatingsystem | tr '[:upper:]' '[:lower:]')
        FACTER_OSVER=$(/usr/bin/facter operatingsystemrelease)
        if [ "$FACTER_OS" == "centos" ]; then
            systemctl enable "$service"
            systemctl start "$service"
            systemctl status "$service"
        elif [ "$FACTER_OS" == "ubuntu" ]; then
            case "$FACTER_OSVER" in
                14.04)
                    service "$service" start
                    service "$service" status
                ;;
                16.04)
                    systemctl enable "$service"
                    systemctl start "$service"
                    systemctl status "$service"
                ;;
                *)
                    echo "---> Unknown Ubuntu version $FACTER_OSVER"
                    exit 1
                ;;
            esac
        else
            echo "---> Unknown OS $FACTER_OS"
            exit 1
        fi
    done
}

ensure_kernel_install() {
    # Workaround for mkinitrd failing on occassion.
    # On CentOS 7 it seems like the kernel install can fail it's mkinitrd
    # run quietly, so we may not notice the failure. This script retries for a
    # few times before giving up.
    initramfs_ver=$(rpm -q kernel | tail -1 | sed "s/kernel-/initramfs-/")
    grub_conf="/boot/grub/grub.conf"
    # Public cloud does not use /boot/grub/grub.conf and uses grub2 instead.
    if [ ! -e "$grub_conf" ]; then
        echo "$grub_conf not found. Using Grub 2 conf instead."
        grub_conf="/boot/grub2/grub.cfg"
    fi

    for i in $(seq 3); do
        if grep "$initramfs_ver" "$grub_conf"; then
            break
        fi
        echo "Kernel initrd missing. Retrying to install kernel..."
        yum reinstall -y kernel
    done
    if ! grep "$initramfs_ver" "$grub_conf"; then
        cat /boot/grub/grub.conf
        echo "ERROR: Failed to install kernel."
        exit 1
    fi
}

ensure_ubuntu_install() {
    # Workaround for mirrors occassionally failing to install a package.
    # On Ubuntu sometimes the mirrors fail to install a package. This wrapper
    # checks that a package is successfully installed before moving on.

    # We purposely want to allow globbing to build the package array
    # shellcheck disable=SC2206
    packages=($@)

    for pkg in "${packages[@]}"
    do
        # Retry installing package 5 times if necessary
        for i in {0..5}
        do

            # Wait for any background apt processes to finish before running apt
            while pgrep apt > /dev/null; do sleep 1; done

            echo "$i: Installing $pkg"
            if [ "$(dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -c "ok installed")" -eq 0 ]; then
                apt-cache policy "$pkg"
                apt-get install "$pkg"
                continue
            else
                echo "$pkg already installed."
                break
            fi
        done
    done
}

rh_systems() {
    # Handle the occurance where SELINUX is actually disabled
    SELINUX=$(grep -E '^SELINUX=(disabled|permissive|enforcing)$' /etc/selinux/config)
    MODE=$(echo "$SELINUX" | cut -f 2 -d '=')
    case "$MODE" in
        permissive)
            echo "************************************"
            echo "** SYSTEM ENTERING ENFORCING MODE **"
            echo "************************************"
            # make sure that the filesystem is properly labelled.
            # it could be not fully labeled correctly if it was just switched
            # from disabled, the autorelabel misses some things
            # skip relabelling on /dev as it will generally throw errors
            restorecon -R -e /dev /

            # enable enforcing mode from the very start
            setenforce enforcing

            # configure system for enforcing mode on next boot
            sed -i 's/SELINUX=permissive/SELINUX=enforcing/' /etc/selinux/config
        ;;
        disabled)
            sed -i 's/SELINUX=disabled/SELINUX=permissive/' /etc/selinux/config
            touch /.autorelabel

            echo "*******************************************"
            echo "** SYSTEM REQUIRES A RESTART FOR SELINUX **"
            echo "*******************************************"
        ;;
        enforcing)
            echo "*********************************"
            echo "** SYSTEM IS IN ENFORCING MODE **"
            echo "*********************************"
        ;;
    esac

    # Allow jenkins access to alternatives command to switch java version
    cat <<EOF >/etc/sudoers.d/89-jenkins-user-defaults
Defaults:jenkins !requiretty
jenkins ALL = NOPASSWD: /usr/sbin/alternatives
EOF

    echo "---> Updating operating system"
    yum clean all
    yum install -y deltarpm
    yum update -y

    ensure_kernel_install

    # add in components we need or want on systems
    echo "---> Installing base packages"
    yum install -y @base https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
    # separate group installs from package installs since a non-existing
    # group with dnf based systems (F21+) will fail the install if such
    # a group does not exist
    yum install -y unzip xz git git-review perl-XML-XPath

    # facter is not installed by default on the base image and facter package
    # gets removed when puppet4 is updated. To fix this use version of facter
    # shipped with puppet4.
    yum install -y facter

    # ensure facter is available in $PATH avoid failures in retry loop
    export PATH="/opt/puppetlabs/bin/:$PATH"

    # Install puppet4
    rpm -ivh https://yum.puppetlabs.com/puppetlabs-release-pc1-el-7.noarch.rpm
    yum -y install -y puppet-agent

    # Create symlink for facter and puppet
    ln -sf /opt/puppetlabs/bin/facter /usr/bin/facter
    ln -sf /opt/puppetlabs/puppet/bin/puppet /usr/bin/puppet

    # All of our systems require Java (because of Jenkins)
    # Install all versions of the OpenJDK devel but force 1.7.0 to be the
    # default

    echo "---> Configuring OpenJDK"
    yum install -y 'java-*-openjdk-devel'

    FACTER_OS=$(/usr/bin/facter operatingsystem | tr '[:upper:]' '[:lower:]')
    FACTER_OSVER=$(/usr/bin/facter operatingsystemrelease)
    case "$FACTER_OS" in
        fedora)
            if [ "$FACTER_OSVER" -ge "21" ]
            then
                echo "---> not modifying java alternatives as OpenJDK 1.7.0 does not exist"
            else
                alternatives --set java /usr/lib/jvm/jre-1.7.0-openjdk.x86_64/bin/java
                alternatives --set java_sdk_openjdk /usr/lib/jvm/java-1.7.0-openjdk.x86_64
            fi
        ;;
        redhat|centos)
            if [ "$(echo "$FACTER_OSVER" | cut -d'.' -f1)" -ge "7" ]
            then
                echo "---> not modifying java alternatives as OpenJDK 1.7.0 does not exist"
            else
                alternatives --set java /usr/lib/jvm/jre-1.7.0-openjdk.x86_64/bin/java
                alternatives --set java_sdk_openjdk /usr/lib/jvm/java-1.7.0-openjdk.x86_64
            fi
        ;;
        *)
            alternatives --set java /usr/lib/jvm/jre-1.7.0-openjdk.x86_64/bin/java
            alternatives --set java_sdk_openjdk /usr/lib/jvm/java-1.7.0-openjdk.x86_64
        ;;
    esac

    ########################
    # --- START LFTOOLS DEPS

    # Used by various scripts to push patches to Gerrit
    yum install -y git-review

    # Needed to parse OpenStack commands used by opendaylight-infra stack commands
    # to initialize Heat template based systems.
    yum install -y jq

    # Used py lftools to speend up some scripts
    #wget http://ftp.riken.jp/Linux/cern/centos/7/cern/x86_64/Packages/parallel-20150522-1.el7.cern.noarch.rpm
    #yum localinstall -y parallel-20150522-1.el7.cern.noarch.rpm

    # Used by lftools scripts to parse XML
    yum install -y xmlstarlet

    # Haskel Packages
    # Cabal update fails on a 1G system so workaround that with a swap file
    dd if=/dev/zero of=/tmp/swap bs=1M count=1024
    mkswap /tmp/swap
    swapon /tmp/swap

    yum install -y cabal-install
    cabal update
    cabal install "Cabal<1.18"  # Pull Cabal version that is capable of building shellcheck
    cabal install --bindir=/usr/local/bin "shellcheck-0.4.6"  # Pin shellcheck version

    # NLTK_DATA Cache: many jobs that use coala pull down nltk_data
    wget -nv -O /opt/nltk_data.zip https://github.com/nltk/nltk_data/archive/gh-pages.zip

    # --- END LFTOOLS DEPS
    ######################

    # install haveged to avoid low entropy rejecting ssh connections
    yum install -y haveged
    systemctl enable haveged.service

    # Install sysstat
    yum install -y sysstat
    enable_service sysstat

    # Install python3 and dependencies, needed for Coala linting at least
    yum install -y python34
    yum install -y python34-{devel,virtualenv,setuptools,pip}

    # Install python dependencies, useful generally
    yum install -y python-{devel,virtualenv,setuptools,pip}
}

ubuntu_systems() {
    # Ignore SELinux since slamming that onto Ubuntu leads to
    # frustration

    # Allow jenkins access to update-alternatives command to switch java version
    cat <<EOF >/etc/sudoers.d/89-jenkins-user-defaults
Defaults:jenkins !requiretty
jenkins ALL = NOPASSWD: /usr/bin/update-alternatives
EOF

    export DEBIAN_FRONTEND=noninteractive
    cat <<EOF >> /etc/apt/apt.conf
APT {
  Get {
    Assume-Yes "true";
    allow-change-held-packages "true";
    allow-downgrades "true";
    allow-remove-essential "true";
  };
};

Dpkg::Options {
  "--force-confdef";
  "--force-confold";
};

EOF

    echo "---> Updating operating system"

    # add additional repositories
    sudo add-apt-repository "deb http://us.archive.ubuntu.com/ubuntu $(lsb_release -sc) main universe restricted multiverse"

    echo "---> Installing base packages"
    apt-get clean
    apt-get update -m
    apt-get upgrade -m
    apt-get dist-upgrade -m
    apt-get install facter

    # facter is not installed by default on the base image and facter package
    # gets removed when puppet4 is updated. To fix this use version of facter
    # shipped with puppet4.
    # ensure facter is available in $PATH avoid failures in retry loop
    export PATH="/opt/puppetlabs/bin/:$PATH"

    ensure_ubuntu_install unzip xz-utils git libxml-xpath-perl

    # Install python3 and dependencies, needed for Coala linting
    ensure_ubuntu_install python3
    ensure_ubuntu_install python3-{dev,setuptools,pip}

    # Install python and dependencies
    ensure_ubuntu_install python-{dev,virtualenv,setuptools,pip}

    FACTER_OSVER=$(facter operatingsystemrelease)
    case "$FACTER_OSVER" in
        14.04)
            echo "---> Installing OpenJDK"
            apt-get install openjdk-7-jdk
            # make jdk8 available
            add-apt-repository -y ppa:openjdk-r/ppa
            apt-get update
            # We need to force openjdk-8-jdk to install
            apt-get install openjdk-8-jdk
            echo "---> Configuring OpenJDK"
            # make sure that we still default to openjdk 7
            update-alternatives --set java /usr/lib/jvm/java-7-openjdk-amd64/jre/bin/java
            update-alternatives --set javac /usr/lib/jvm/java-7-openjdk-amd64/bin/javac

            echo "---> Install puppet repository for 14.04"
            apt-get purge puppet puppet-common
            wget https://apt.puppetlabs.com/puppetlabs-release-pc1-trusty.deb
            dpkg -i puppetlabs-release-pc1-trusty.deb

            echo "---> Installing puppet"
            apt-get update -m
            ensure_ubuntu_install puppet-agent
            # Create symlink for facter and puppet
            ln -sf /opt/puppetlabs/bin/facter /usr/bin/facter
            ln -sf /opt/puppetlabs/puppet/bin/puppet /usr/bin/puppet
        ;;
        16.04)
            echo "---> Installing OpenJDK"
            apt-get install openjdk-8-jdk

            echo "---> Install puppet4 repository for 16.04"
            apt-get purge puppet puppet-common
            wget https://apt.puppetlabs.com/puppetlabs-release-pc1-xenial.deb
            dpkg -i puppetlabs-release-pc1-xenial.deb

            echo "---> Installing puppet"
            apt-get update -m
            ensure_ubuntu_install puppet-agent

            # Create symlink for facter and puppet
            ln -sf /opt/puppetlabs/bin/facter /usr/bin/facter
            ln -sf /opt/puppetlabs/puppet/bin/puppet /usr/bin/puppet

            echo "---> Installing python3 virtualenv"
            # python3-virtualenv is available starting with 16.04.
            ensure_ubuntu_install python3-virtualenv
        ;;
        *)
            echo "---> Unknown Ubuntu version $FACTER_OSVER"
            exit 1
        ;;
    esac

    ########################
    # --- START LFTOOLS DEPS

    # Used by various scripts to push patches to Gerrit
    ensure_ubuntu_install git-review

    # Needed to parse OpenStack commands used by opendaylight-infra stack commands
    # to initialize Heat template based systems.
    ensure_ubuntu_install jq

    # Used py lftools to speend up some scripts
    ensure_ubuntu_install parallel

    # Used by lftools scripts to parse XML
    ensure_ubuntu_install xmlstarlet

    # Haskel Packages
    # Cabal update fails on a 1G system so workaround that with a swap file
    dd if=/dev/zero of=/tmp/swap bs=1M count=1024
    mkswap /tmp/swap
    swapon /tmp/swap

    ensure_ubuntu_install cabal-install
    cabal update
    cabal install --bindir=/usr/local/bin "shellcheck-0.4.6"  # Pin shellcheck version

    # NLTK_DATA Cache: many jobs that use coala pull down nltk_data
    wget -nv -O /opt/nltk_data.zip https://github.com/nltk/nltk_data/archive/gh-pages.zip

    # --- END LFTOOLS DEPS
    ######################

    # Install sysstat
    ensure_ubuntu_install sysstat
    sed -i 's/ENABLED="false"/ENABLED="true"/' /etc/default/sysstat
    enable_service sysstat

    # Install haveged to avoid low entropy rejecting ssh connections
    apt-get install haveged
    update-rc.d haveged defaults

    # Disable unattended upgrades & daily updates
    echo '---> Disabling automatic daily upgrades'
    sed -ine 's/"1"/"0"/g' /etc/apt/apt.conf.d/10periodic
    echo 'APT::Periodic::Unattended-Upgrade "0";' >> /etc/apt/apt.conf.d/10periodic

    # Install packaging job dependencies for building debs
    ensure_ubuntu_install  build-essential devscripts equivs dh-systemd python-yaml \
                    python-jinja2 gdebi
}

all_systems() {
    # To handle the prompt style that is expected all over the environment
    # with how use use robotframework we need to make sure that it is
    # consistent for any of the users that are created during dynamic spin
    # ups
    echo 'PS1="[\u@\h \W]> "' >> /etc/skel/.bashrc

    # Do any Distro specific installations here
    echo "Checking distribution"
    FACTER_OS=$(/usr/bin/facter operatingsystem | tr '[:upper:]' '[:lower:]')
    case "$FACTER_OS" in
        redhat|centos)
            if [ "$(/usr/bin/facter operatingsystemrelease | /bin/cut -d '.' -f1)" = "7" ]; then
                echo
                echo "---> CentOS 7"
                echo "No extra steps currently for CentOS 7"
                echo
            else
                echo "---> CentOS 6"
                echo "Installing ODL YUM repo"
                yum install -y https://nexus.opendaylight.org/content/repositories/opendaylight-yum-epel-6-x86_64/rpm/opendaylight-release/0.1.0-1.el6.noarch/opendaylight-release-0.1.0-1.el6.noarch.rpm
            fi
        ;;
        *)
            echo "---> $FACTER_OS found"
            echo "No extra steps for $FACTER_OS"
        ;;
    esac

    # Update /etc/nss-switch.conf to map hostname with IP instead of using `localhost`
    # from /etc/hosts which is required by some of the Java API's to avoid
    # Java UnknownHostException: "Name or service not known" error.
    sed -i "/^hosts:/s/$/ myhostname/" /etc/nsswitch.conf
}

echo "---> Attempting to detect OS"
# upstream cloud images use the distro name as the initial user
ORIGIN=$(if [ -e /etc/redhat-release ]
    then
        echo redhat
    else
        echo ubuntu
    fi)
#ORIGIN=$(logname)

case "${ORIGIN}" in
    fedora|centos|redhat)
        echo "---> RH type system detected"
        rh_systems
    ;;
    ubuntu)
        echo "---> Ubuntu system detected"
        ubuntu_systems
    ;;
    *)
        echo "---> Unknown operating system"
    ;;
esac

# execute steps for all systems
all_systems
