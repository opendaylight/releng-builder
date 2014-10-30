rackspace-convert-base can be used to convert a RackSpace native base
image into a Vagrant compatible one. The default image to convert is the
'Fedora 20 (Heisenbug) (PVHVM)' image but this can be overridden just by
setting the RSIMAGE environment variable before calling the vagrant up.

ex:

$ RSIMAGE='CentOS 7 (PVHVM)' vagrant up --provider=rackspace

This vagrant will just set the instance up at the most basic to be
Vagrant capable and also SELinux enforcing. It will then "reseal" itself
and state the the system is ready for imaging. Any further RackSpace
specific Vagrant definitions will expect a base system of the form
"$DISTRO - Vagrant ready" for the base image name

ex:

Fedora 20 (Heisenbug) - Vagrant ready

or

CentOS 7 - Vagrant ready

NOTE: The reseal operation _destroys_ the SSH keys that were used to
bring the Vagrant system up effectively making the system unable to
perform SSH based logins again. This is intentional.
