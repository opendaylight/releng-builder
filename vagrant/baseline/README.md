baseline can be used for preparing basic test images. It's suitable for
use only as a verification that our baseline library script is working
as expected or for a very vanilla image.

This is controlled by the IMAGE environment variable

ex:

$ export RESEAL=true
$ IMAGE='CentOS 7' vagrant up --provider=openstack

If $RESEAL is not set then the system will not be cleaned up in
preparation for snapshotting. This is mostly useful for troubleshooting
a vagrant definition before you do your final creation and snapshot.
