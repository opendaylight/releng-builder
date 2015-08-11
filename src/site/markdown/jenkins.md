The [Release Engineering project](https://wiki.opendaylight.org/view/RelEng:Main "Releng:Main") consolidates the Jenkins jobs from project-specific VMs to a single Jenkins server.  Each OpenDaylight project will have a tab on the RelEng Jenkins server.  The system utilizes [Jenkins Job Builder](http://ci.openstack.org/jenkins-job-builder/ "JJB") \(JJB\) for the creation and management of the Jenkins jobs.

Jenkins Master
==============

https://jenkins.opendaylight.org/releng/

The Jenkins Master server is the new home for all project Jenkins jobs.  All maintenance and configuration of these jobs must be done via JJB through the RelEng repo ([https://git.opendaylight.org/gerrit/gitweb?p=releng%2Fbuilder.git;a=summary RelEng/Builder gitweb]).  Project contributors can no longer edit the Jenkins jobs directly on the server.

Build Slaves
============

The Jenkins jobs are run on build slaves (executors) which are created on an as-needed basis.  If no idle build slaves are available a new VM is brought up.  This process can take up to 2 minutes.  Once the build slave has finished a job, it will remain online for 45 minutes before shutting down.  Subsequent jobs will use an idle build slave if available.

Our Jenkins master supports many types of dynamic build slaves. If you are creating custom jobs then you will need to have an idea of what type of slaves are available. The following are the current slave types and descriptions. Slave Template Names are needed for jobs that take advantage of multiple slaves as they must be specifically called out by template name instead of label.

Adding new components to the slaves
===================================

If your project needs something added to one of the slaves used during build and test you can help us get things added in faster by doing one of the following

* Submit a patch to releng/builder for the [Jenkins Spinup script](https://git.opendaylight.org/gerrit/gitweb?p=releng/builder.git;a=tree;f=jenkins-scripts;h=69252dd61ece511bd2018039b40e7836a8d49d21;hb=HEAD) that configures your new piece of software.

* Submit a patch to releng/builder for the [Vagrant template's bootstrap.sh](https://git.opendaylight.org/gerrit/gitweb?p=releng/builder.git;a=tree;f=vagrant;h=409a2915d48bbdeea9edc811e1661ae17ca28280;hb=HEAD) that configures your new piece of software.

Going the first route will be faster in the short term as we can inspect the changes and make test modifications in the sandbox to verify that it works.

The second route, however, is better for the community as a whole as it will allow others that utilize our vagrant startups to replicate our systems more closely. It is, however, more time consuming as an image snapshot needs to be created based on the updated vagrant definition before it can be attached to the sandbox for validation testing.

In either case, the changes must be validated in the sandbox with tests to make sure that we don't break current jobs but also that the new software features are operating as intended. Once this is done the changes will be merged and the updates applied to the releng Jenkins production silo.

Please note that the combination of the Vagrant slave snapshot and the Jenkins Spinup script is what defines a given slave. That means for instance that a slave that is defined using the releng/builder/vagrant/basic-java-node Vagrant and a Jenkins Spinup script of releng/builder/jenkins-script/controller.sh (as the dynamic_controller slave is) is the full definition of the realized slave. Jenkins starts a slave using the snapshot created that has been saved from when the vagrant was last run and once the instance is online it then checks out the releng/builder repo and executes two scripts. The first is the basic_settings.sh which is a baseline for all of the slaves and the second is the specialization script that does any syste updates, new software installs or extra environment tweaks that don't make sense in a snapshot. After all of these scripts have executed Jenkins will finally attach the slave as an actual slave and start handling jobs on it.

