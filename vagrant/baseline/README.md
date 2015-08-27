basline can be used to prepare systems in the Rackspace (or potentially
other environments) for following vagrant layers.

While the base image that is looked for is
'Fedora 20 (Heisenbug) (PVHVM)' which is no longer even offered, the
variable is being left in place so to prompt selection of a proper base
image to spin up against.

This is controlled by the RSIMAGE environment variable

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

If you are bringing up an Ubuntu system you _must_ also set
RSPTY='default' or the bring up will hang indefinitely during the OS
upgrade phase.
