The [Release Engineering project](https://wiki.opendaylight.org/view/RelEng:Main "Releng:Main")
consolidates the Jenkins jobs from project-specific VMs to a single Jenkins
server. Each OpenDaylight project will have a tab on the RelEng Jenkins
server. The system utilizes
[Jenkins Job Builder](http://ci.openstack.org/jenkins-job-builder/ "JJB")
\(JJB\) for the creation and management of the Jenkins jobs.

# Jenkins Master

https://jenkins.opendaylight.org/releng/

The Jenkins Master server is the new home for all project Jenkins jobs.  All
maintenance and configuration of these jobs must be done via JJB through the
RelEng repo ([https://git.opendaylight.org/gerrit/gitweb?p=releng%2Fbuilder.git;a=summary RelEng/Builder gitweb]).
Project contributors can no longer edit the Jenkins jobs directly on the
server.

# Build Slaves

The Jenkins jobs are run on build slaves (executors) which are created on an
as-needed basis.  If no idle build slaves are available a new VM is brought
up. This process can take up to 2 minutes. Once the build slave has finished a
job, it will remain online for 45 minutes before shutting down.  Subsequent
jobs will use an idle build slave if available.

Our Jenkins master supports many types of dynamic build slaves. If you are
creating custom jobs then you will need to have an idea of what type of slaves
are available. The following are the current slave types and descriptions.
Slave Template Names are needed for jobs that take advantage of multiple
slaves as they must be specifically called out by template name instead of
label.

# Adding new components to the slaves

If your project needs something added to one of the slaves used during build
and test you can help us get things added in faster by doing one of the
following:

* Submit a patch to releng/builder for the
  [Jenkins Spinup script](https://git.opendaylight.org/gerrit/gitweb?p=releng/builder.git;a=tree;f=jenkins-scripts;h=69252dd61ece511bd2018039b40e7836a8d49d21;hb=HEAD)
  that configures your new piece of software.

* Submit a patch to releng/builder for the
  [Vagrant template's bootstrap.sh](https://git.opendaylight.org/gerrit/gitweb?p=releng/builder.git;a=tree;f=vagrant;h=409a2915d48bbdeea9edc811e1661ae17ca28280;hb=HEAD)
  that configures your new piece of software.

Going the first route will be faster in the short term as we can inspect the
changes and make test modifications in the sandbox to verify that it works.

The second route, however, is better for the community as a whole as it will
allow others that utilize our vagrant startups to replicate our systems more
closely. It is, however, more time consuming as an image snapshot needs to be
created based on the updated vagrant definition before it can be attached to
the sandbox for validation testing.

In either case, the changes must be validated in the sandbox with tests to
make sure that we don't break current jobs but also that the new software
features are operating as intended. Once this is done the changes will be
merged and the updates applied to the releng Jenkins production silo.

Please note that the combination of the Vagrant slave snapshot and the Jenkins
Spinup script is what defines a given slave. That means for instance that a
slave that is defined using the releng/builder/vagrant/basic-java-node Vagrant
and a Jenkins Spinup script of releng/builder/jenkins-script/controller.sh
(as the dynamic_controller slave is) is the full definition of the realized
slave. Jenkins starts a slave using the snapshot created that has been saved
from when the vagrant was last run and once the instance is online it then
checks out the releng/builder repo and executes two scripts. The first is the
basic_settings.sh which is a baseline for all of the slaves and the second is
the specialization script that does any syste updates, new software installs
or extra environment tweaks that don't make sense in a snapshot. After all of
these scripts have executed Jenkins will finally attach the slave as an actual
slave and start handling jobs on it.


| JClouds Pool | Jenkins Label | Slave Template Name | Description | Vagrant definition | Jenkins Spinup |
| --- | --- | --- | --- | --- | --- | --- |
| Rackspace - Docker | dynamic_docker | rk-f20-docker | A Fedora 20 system that is configured with OpenJDK 1.7 (aka Java7) and docker. This system was originally custom built for the test needs of the OVSDB project but other projects have expressed interest in using it. | releng/builder/vagrant/ovsdb-docker | releng/builder/jenkins-scripts/docker.sh |
| Rackspace DFW | dynamic_verify | rk-c-el65-build | A CentOS 6 build slave. This system has OpenJDK 1.7 (Java7) and OpenJDK 1.8 (Java8) installed on it along with all the other components and libraries needed for building any current OpenDaylight project. This is the label that is used for all basic -verify and -daily- builds for projects. | releng/builder/vagrant/basic-builder | releng/builder/jenkins-scripts/builder.sh |
| Rackspace DFW | dynamic_merge | rk-c-el65-build | See dynamic_verify (same image on the back side). This is the label that is used for all basic -merge and -integration- builds for projects. | releng/builder/vagrant/basic-builder | releng/builder/jenkins-scripts/builder.sh |
| Rackspace DFW - Devstack | dynamic_devstack | rk-c7-devstack | A CentOS 7 system purpose built for doing OpenStack testing using DevStack. This slave is primarily targeted at the needs of the OVSDB project. It has OpenJDK 1.7 (aka Java7) and other basic DevStack related bits installed. | releng/builder/vagrant/ovsdb-devstack | releng/builder/jenkins-scripts/devstack.sh |
| Rackspace DFW - Integration | dynamic_robot | rk-c-el6-robot | A CentOS 6 slave that is configured with OpenJDK 1.7 (Java7) and all the current packages used by the integration project for doing robot driven jobs. If you are executing robot framework jobs then your job should be using this as the slave that you are tied to. This image does not contain the needed libraries for building components of OpenDaylight, only for executing robot tests. | releng/builder/vagrant/integration-robotframework | releng/builder/jenkins-scripts/robot.sh |
| Rackspace DFW - Integration Dynamic Lab | dynamic_controller | rk-c-el6-java | A CentOS 6 slave that has the basic OpenJDK 1.7 (Java7) installed and is capable of running the controller, not building. | releng/builder/vagrant/basic-java-node | releng/builder/jenkins-scripts/controller.sh |
| Rackspace DFW - Integration Dynamic Lab | dynamic_java | rk-c-el6-java | See dynamic_controller as it is currently the same image. | releng/builder/vagrant/basic-java-node | releng/builder/jenkins-scripts/controller.sh |
| Rackspace DFW - Integration Dynamic Lab | dynamic_mininet | rk-c-el6-mininet | A CentOS 6 image that has mininet, openvswitch v2.0.x, netopeer and PostgreSQL 9.3 installed. This system is targeted at playing the role of a mininet system for integration tests. Netopeer is installed as it is needed for various tests by Integration. PostgreSQL 9.3 is installed as the system is also capable of being used as a VTN project controller and VTN requires PostgreSQL 9.3. | releng/builder/vagrant/basic-mininet-node | releng/builder/jenkins-scripts/mininet.sh |
| Rackspace DFW - Integration Dynamic Lab | dynamic_mininet_fedora | rk-f21-mininet | Basic Fedora 21 system with ovs v2.3.x and mininet 2.2.1 | releng/builder/vagrant/basic-mininet-fedora-node | releng/builder/jenkins-scripts/mininet-fedora.sh |
| Rackspace DFW - Matrix | matrix_master | rk-c-el6-matrix | This is a very minimal system that is designed to spin up with 2 build instances on it. The purpose is to have a location that is not the Jenkins master itself for jobs that are executing matrix operations since they need a director location. This image should not be used for anything but tying matrix jobs before the matrx defined label ties. | releng/builder/vagrant/basic-java-node | releng/builder/jenkins-scripts/matrix.sh |


# Creating Jenkins Jobs

Jenkins Job Builder takes simple descriptions of Jenkins jobs in YAML format, and uses them to configure Jenkins.

* [Jenkins Job Builder](http://ci.openstack.org/jenkins-job-builder/) \(JJB\)
  documentation

OpenDaylight releng/builder gerrit project

* [releng/builder](https://git.opendaylight.org/gerrit/#/admin/projects/releng/builder)
  Git repo

## Jenkins Job Builder Installation

### Using Docker
[Docker](https://www.docker.com/whatisdocker/) is an open platform used to
create virtualized Linux containers for shipping self-contained applications.
Docker leverages LinuX Containers \(LXC\) running on the same operating system
as the host machine, whereas a traditional VM runs an operating system over
the host.

    docker pull zxiiro/jjb-docker
    docker run --rm -v ${PWD}:/jjb jjb-docker

The Dockerfile that created that image is
[here](https://github.com/zxiiro/jjb-docker/blob/master/Dockerfile).
By default it will run:

    jenkins-jobs test .

Using the volume mount "-v" parameter you need to mount a directory containing
your YAML files as well as a configured jenkins.ini file if you wish to upload
your jobs to the Sandbox.

### Manual install

Jenkins Jobs in the releng silo use Jenkins Job Builder so if you need to test
your Jenkins job against the Sandbox you will need to install JJB.

The templates below depend on a modified JJB version to add support for some
missing features needed by our Jenkins instance. You can download JJB from
OpenStack:

    git clone https://git.openstack.org/openstack-infra/jenkins-job-builder

Before installing JJB make sure following python modules are installed (see
requirements.txt):

* argparse
* ordereddict
* six>=1.5.2
* PyYAML
* python-jenkins>=0.4.1
* pbr>=0.8.2,<1.0

Follow steps in README.rst to install JJB:

   sudo python setup.py install

Notes for Mac: [instructions here](https://github.com/openstack-infra/jenkins-job-builder).
The <tt>sudo python setup.py install</tt> seems to work better than the
version using brew and pip.

Note: Some Linux distributions already contain a JJB package, usually with
version too low to work correctly with Releng templates. You may need to
uninstall the corresponding Linux package (or find another workaround) before
proceeding with steps from *README.rst*.

Update: Here is a link to e-mail with suggestions on how to install and
upgrade JJB properly:
https://lists.opendaylight.org/pipermail/integration-dev/2015-April/003016.html

## Jenkins Job Templates

The ODL Releng project provides 4 job templates which can be used to
define basic jobs.

### Verify Job Template

Trigger: **recheck**

The Verify job template creates a Gerrit Trigger job that will trigger when a
new patch is submitted to Gerrit.

Verify jobs can be retriggered in Gerrit by leaving a comment that says
**recheck**.

### Merge Job Template

Trigger: **remerge**

The Merge job template is similar to the Verify Job Template except it will
trigger once a Gerrit patch is merged into the repo. It also automatically
runs the Maven goals **source:jar** and **javadoc:jar**.

This job will upload artifacts to https://nexus.opendaylight.org on
completion.

Merge jobs can be retriggered in Gerrit by leaving a comment that says
**remerge**.

### Daily Job Template

The Daily (or Nightly) Job Template creates a job which will run on a build on
a Daily basis as a sanity check to ensure the build is still working day to
day.

### Sonar Job Template

Trigger: **run-sonar**

This job runs Sonar analysis and reports the results to
[OpenDaylight's Sonar dashboard(https://sonar.opendaylight.org).

**Note:** Running the "run-sonar" trigger will cause Jenkins to remove it's
existing vote if it's already -1 or +1'd a comment. You will need to re-run
your verify job (recheck) after running this to get Jenkins to put back the
correct vote.

The Sonar Job Template creates a job which will run against the master branch,
or if BRANCHES are specified in the CFG file it will create a job for the
**First** branch listed.

### Integration Job Template

The Integration Job Template create a job which runs when a project that your
project depends on is successfully built. This job type is basically the same
as a verify job except that it triggers from other jenkins jobs instead of via
Gerrit review update. The dependencies are listed in your project.cfg file
under the **DEPENDENCIES** variable.

If no dependencies are listed then this job type is disabled by default.

### Patch Test Job

Trigger: **test-integration**

This job runs a full integration test suite against your patch and reports
back the results to Gerrit. This job is maintained by the integration project
and you just need to leave a comment with trigger keyword above to activate it
for a particular patch.

**Note:** Running the "test-integration" trigger will cause Jenkins to remove
it's existing vote if it's already -1 or +1'd a comment. You will need to
re-run your verify job (recheck) after running this to get Jenkins to put back
the correct vote.

Some considerations when using this job:

* The patch test verification takes some time (~ 2 hours) + consumes a lot of
  resources so it is not meant to be used for every patch
* The system test for master patches will fail most of the times because both
  code and test are unstable during the release cycle (should be good by the
  end of the cycle)
* Because of the above, patch test results has to be interpreted most of the
  times by a system test knowable person, the integration group can help with
  that

## Basic Job Configuration

To create jobs based on the above templates you can use the example
template which will create 6 jobs (verify, merge, and daily jobs for both
master and stable/helium branch).

Run the following steps from the repo (i.e. releng/builder) root to create
initial job config. This script will produce a file in
jjb/\<project\>/\<project\>.yaml containing your project's base template.

    python scripts/jjb-init-project.py <project-name>

    # Example
    python scripts/jjb-init-project.py aaa

    # Note: The optional options below require you to remove the 1st line
    #       comment in the produced template file otherwise the auto
    #       update script will overwrite the customization next time it
    #       is run. See Auto Update Job Templates section below for more
    #       details.
    #
    # Optionally pass the following options:
    #
    # -s / --streams        : List of release streams you want to create jobs for. The
    #                         first in the list will be used for the Sonar job.
    #                         (defaults to "beryllium")
    # -p / --pom            : Path to pom.xml to use in Maven build (defaults to pom.xml)
    # -g / --mvn-goals      : With your job's Maven Goals necessary to build
    #                         (defaults to "clean install")
    #          Example      : -g "clean install"
    #
    # -o / --mvn-opts       : With your job's Maven Options necessary to build
    #                         (defaults to empty)
    #          Example      : -o "-Xmx1024m"
    #
    # -d / --dependencies   : A comma-seperated (no spaces) list of projects
    #                         your project depends on.
    #                         This is used to create an integration job that
    #                         will trigger when a dependent project-merge job
    #                         is built successfully.
    #          Example      : aaa,controller,yangtools
    #
    # -t / --templates      : Job templates to use
    #                         (defaults: verify,merge,daily,integration,sonar)
    #
    #          Example      : verify,merge,daily,integration

If all your project requires is the basic verify, merge, and
daily jobs then using the job template should be all you need to
configure for your jobs.

### Auto Update Job Templates

The first line of the job YAML file produced by the script will contain
the words # REMOVE THIS LINE IF... leaving this line will allow the
releng/builder autoupdate script to maintain this file for your project
should the base template ever change. It is a good idea to leave this
line if you do not plan to create any complex jobs outside of the
provided template.

However if your project needs more control over your jobs or if you have
any additional configuration outside of the standard configuration
provided by the template then this line should be removed.

#### Tuning templates

Additionally the auto-updater does allow some small tweaks to the template
so that you can take advantage of the template while at the same time
tuning small aspects of your jobs. To take advantage of this simply create
a file in your project's jjb directory called **project.cfg** with the
following contents and tune as necessary. If there is a parameter you do
NOT want to tune simply remove the parameter or comment out the line with a
"#"" sign.

    JOB_TEMPLATES: verify,merge,sonar
    STREAMS:
    - beryllium:
        jdks: openjdk7,openjdk8
    - stable/lithium:
        jdks: openjdk7
    POM: dfapp/pom.xml
    MVN_GOALS: clean install javadoc:aggregate -DrepoBuild -Dmaven.repo.local=$WORKSPACE/.m2repo -Dorg.ops4j.pax.url.mvn.localRepository=$WORKSPACE/.m2repo
    MVN_OPTS: -Xmx1024m -XX:MaxPermSize=256m
    DEPENDENCIES: aaa,controller,yangtools
    ARCHIVE_ARTIFACTS: *.logs, *.patches

Note: BRANCHES is a list of branches you want JJB to generate jobs for, the
first branch will be the branch that reports Sonar analysis. Each branch must
additionally define a "jdks:" section listing the jdks the verify jobs should
run tests against for the branch; additionally the first jdk listed will be
used as the default jdk for non-verify type jobs.

#### Advanced

It is also possible to take advantage of both the auto updater and creating
your own jobs. To do this, create a YAML file in your project's sub-directory
with any name other than \<project\>.yaml. The auto-update script will only
search for files with the name \<project\>.yaml. The normal \<project\>.yaml
file can then be left in tact with the "# REMOVE THIS LINE IF..." comment so
it will be automatically updated.
