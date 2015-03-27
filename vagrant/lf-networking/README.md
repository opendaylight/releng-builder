lf-networking is the final overlay that is run on images to make them
usable as Jenkins slaves in the OpenDaylight or ODLForge environments.

Please see the rackspace-convert-base vagrant setup for creation of the
needed base image or use one of the other vagrant configurations
(utilizing a convert base image) for the source image.

This vagrant expects (by default) a personal Rackspace image named

'CentOS 6.5 - Vagrant ready'

To spin up and utilize.

$ RSIMAGE='${baseimagename}' vagrant up --provider=rackspace

Will execute this vagrant against a differently named base image

This vagrant requires that an environment variable of RSSUBDOMAIN be
configured so that the networking configuration can be carried out
properly as the process used makes it difficult at best and impossible
at worst to detect what the final networking setups should be. This
needs to be detected before we create the base image due to how
cloud-init overwrites certain features we're trying to override and we
therefore 'chattr +i' certain configuration files to keep it from
breaking things.

RSSUBDOMAIN may be (currently) one of the following options:

dfw.opendaylight.org
dfw.odlforge.org
ord.opendaylight.org

NOTE: This vagrant will always execute the resealing operation. This
operation will intentially destroy current SSH pubkeys installed on the
system as well as reset log files and network configurations. You have
been warned.
