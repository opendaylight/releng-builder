The [Release Engineering project][0] consolidates the Jenkins jobs from
project-specific VMs to a single Jenkins server. Each OpenDaylight project
has a tab for their jobs on the [RelEng Jenkins server][3]. The system utilizes
[Jenkins Job Builder][7] \(JJB\) for the creation and management of the Jenkins
jobs.

Sections:

* [Jenkins Master](#jenkins_master)
* [Build Slaves](#build_slaves)
* [Creating Jenkins Jobs](#creating_jenkins_jobs)
    * [Jenkins Job Builder Installation](#jjb_install)
    * [Jenkins Job Templates](#jjb_templates)
    * [Jenkins Job Basic Configuration](#jjb_basic_configuration)
    * [Jenkins Job Maven Properties](#jjb_maven_properties)
* [Jenkins Sandbox](#jenkins_sandbox)

# <a name="jenkins_master">Jenkins Master</a>

https://jenkins.opendaylight.org/releng/

The Jenkins Master server is the home for all project's Jenkins jobs. All
maintenance and configuration of these jobs must be done via JJB through the
[RelEng repo][4]. Project contributors can no longer edit the Jenkins jobs
directly on the server.

# <a name="build_slaves">Build Slaves</a>

The Jenkins jobs are run on build slaves (executors) which are created on an
as-needed basis. If no idle build slaves are available a new VM is brought
up. This process can take up to 2 minutes. Once the build slave has finished a
job, it will remain online for 45 minutes before shutting down. Subsequent
jobs will use an idle build slave if available.

Our Jenkins master supports many types of dynamic build slaves. If you are
creating custom jobs then you will need to have an idea of what type of slaves
are available. The following are the current slave types and descriptions.
Slave Template Names are needed for jobs that take advantage of multiple
slaves as they must be specifically called out by template name instead of
label.

## Adding new components to the slaves

If your project needs something added to one of the slaves used during build
and test you can help us get things added faster by doing one of the following:

* Submit a patch to releng/builder for the [Jenkins Spinup script][5] that
  configures your new piece of software.

* Submit a patch to releng/builder for the [Vagrant template's bootstrap.sh][6]
  that configures your new piece of software.

Going the first route will be faster in the short term as we can inspect the
changes and make test modifications in the sandbox to verify that it works.

The second route, however, is better for the community as a whole as it will
allow others that utilize our Vagrant setups to replicate our systems more
closely. It is, however, more time consuming as an image snapshot needs to be
created based on the updated Vagrant definition before it can be attached to
the sandbox for validation testing.

In either case, the changes must be validated in the sandbox with tests to
make sure that we don't break current jobs and that the new software features
are operating as intended. Once this is done the changes will be merged and
the updates applied to the releng Jenkins production silo.

Please note that the combination of a Vagrant slave snapshot and a Jenkins
Spinup script is what defines a given slave. For instance, a slave may be
defined by the [`releng/builder/vagrant/basic-java-node/`][8] Vagrant definition
and the [`releng/builder/jenkins-script/controller.sh`][9] Jenkins Spinup script
(as the dynamic_controller slave is). The pair provides the full definition of
the realized slave. Jenkins starts a slave using the last-spun Vagrant snapshot
for the specified definition. Once the base Vagrant instance is online Jenkins
checks out the releng/builder repo on it and executes two scripts. The first is
[`basic_settings.sh`][10], which is a baseline for all of the slaves. The second is
the specialized Spinup script, which andles any system updates, new software
installs or extra environment tweaks that don't make sense in a snapshot. After
all of these scripts have executed Jenkins will finally attach the slave as an
actual slave and start handling jobs on it.

### Pool: Rackspace - Docker

<table class="table table-bordered">
  <tr>
    <td><b>Jenkins Label</b><br/> dynamic_docker</td>
    <td><b>Slave Template name</b><br/> rk-f20-docker</td>
    <td><b>Vagrant Definition</b><br/> releng/builder/vagrant/ovsdb-docker</td>
    <td><b>Spinup Script</b><br/> releng/builder/jenkins-scripts/docker.sh</td>
  </tr>
  <tr>
    <td colspan="4">
      A Fedora 20 system that is configured with OpenJDK 1.7 (aka Java7) and
      Docker. This system was originally custom built for the test needs of
      the OVSDB project but other projects have expressed interest in using
      it.
    </td>
  </tr>
</table>

### Pool: Rackspace DFW

<table class="table table-bordered">
  <tr>
    <td><b>Jenkins Label</b><br/> dynamic_verify</td>
    <td><b>Slave Template name</b><br/> rk-c-el65-build</td>
    <td><b>Vagrant Definition</b><br/> releng/builder/vagrant/basic-builder</td>
    <td><b>Spinup Script</b><br/> releng/builder/jenkins-scripts/builder.sh</td>
  </tr>
  <tr>
    <td colspan="4">
      A CentOS 6 build slave. This system has OpenJDK 1.7 (Java7) and OpenJDK
      1.8 (Java8) installed on it along with all the other components and
      libraries needed for building any current OpenDaylight project. This is
      the label that is used for all basic -verify and -daily- builds for
      projects.
    </td>
  </tr>
</table>

<table class="table table-bordered">
  <tr>
    <td><b>Jenkins Label</b><br/> dynamic_merge</td>
    <td><b>Slave Template name</b><br/> rk-c-el65-build</td>
    <td><b>Vagrant Definition</b><br/> releng/builder/vagrant/basic-builder</td>
    <td><b>Spinup Script</b><br/> releng/builder/jenkins-scripts/builder.sh</td>
  </tr>
  <tr>
    <td colspan="4">
      See dynamic_verify (same image on the back side). This is the label that
      is used for all basic -merge and -integration- builds for projects.
    </td>
  </tr>
</table>

### Pool: Rackspace DFW - Devstack

<table class="table table-bordered">
  <tr>
    <td><b>Jenkins Label</b><br/> dynamic_devstack</td>
    <td><b>Slave Template name</b><br/> rk-c7-devstack</td>
    <td><b>Vagrant Definition</b><br/> releng/builder/vagrant/ovsdb-devstack</td>
    <td><b>Spinup Script</b><br/> releng/builder/jenkins-scripts/devstack.sh</td>
  </tr>
  <tr>
    <td colspan="4">
      A CentOS 7 system purpose built for doing OpenStack testing using
      DevStack. This slave is primarily targeted at the needs of the OVSDB
      project. It has OpenJDK 1.7 (aka Java7) and other basic DevStack related
      bits installed.
    </td>
  </tr>
</table>

### Pool: Rackspace DFW - Integration

<table class="table table-bordered">
  <tr>
    <td><b>Jenkins Label</b><br/> dynamic_robot</td>
    <td><b>Slave Template name</b><br/> rk-c-el6-robot</td>
    <td><b>Vagrant Definition</b><br/> releng/builder/vagrant/integration-robotframework</td>
    <td><b>Spinup Script</b><br/> releng/builder/jenkins-scripts/robot.sh</td>
  </tr>
  <tr>
    <td colspan="4">
      A CentOS 6 slave that is configured with OpenJDK 1.7 (Java7) and all the
      current packages used by the integration project for doing robot driven
      jobs. If you are executing robot framework jobs then your job should be
      using this as the slave that you are tied to. This image does not
      contain the needed libraries for building components of OpenDaylight,
      only for executing robot tests.
    </td>
  </tr>
</table>

### Pool: Rackspace DFW - Integration Dynamic Lab

<table class="table table-bordered">
  <tr>
    <td><b>Jenkins Label</b><br/> dynamic_controller</td>
    <td><b>Slave Template name</b><br/> rk-c-el6-java</td>
    <td><b>Vagrant Definition</b><br/> releng/builder/vagrant/basic-java-node</td>
    <td><b>Spinup Script</b><br/> releng/builder/jenkins-scripts/controller.sh</td>
  </tr>
  <tr>
    <td colspan="4">
      A CentOS 6 slave that has the basic OpenJDK 1.7 (Java7) installed and is
      capable of running the controller, not building.
    </td>
  </tr>
</table>

<table class="table table-bordered">
  <tr>
    <td><b>Jenkins Label</b><br/> dynamic_java</td>
    <td><b>Slave Template name</b><br/> rk-c-el6-java</td>
    <td><b>Vagrant Definition</b><br/> releng/builder/vagrant/basic-java-node</td>
    <td><b>Spinup Script</b><br/> releng/builder/jenkins-scripts/controller.sh</td>
  </tr>
  <tr>
    <td colspan="4">
      See dynamic_controller as it is currently the same image.
    </td>
  </tr>
</table>

<table class="table table-bordered">
  <tr>
    <td><b>Jenkins Label</b><br/> dynamic_mininet</td>
    <td><b>Slave Template name</b><br/> rk-c-el6-mininet</td>
    <td><b>Vagrant Definition</b><br/> releng/builder/vagrant/basic-mininet-node</td>
    <td><b>Spinup Script</b><br/> releng/builder/jenkins-scripts/mininet.sh</td>
  </tr>
  <tr>
    <td colspan="4">
      A CentOS 6 image that has mininet, openvswitch v2.0.x, netopeer and
      PostgreSQL 9.3 installed. This system is targeted at playing the role of
      a mininet system for integration tests. Netopeer is installed as it is
      needed for various tests by Integration. PostgreSQL 9.3 is installed as
      the system is also capable of being used as a VTN project controller and
      VTN requires PostgreSQL 9.3.
    </td>
  </tr>
</table>

<table class="table table-bordered">
  <tr>
    <td><b>Jenkins Label</b><br/> dynamic_mininet_fedora</td>
    <td><b>Slave Template name</b><br/> rk-f21-mininet</td>
    <td><b>Vagrant Definition</b><br/> releng/builder/vagrant/basic-mininet-fedora-node</td>
    <td><b>Spinup Script</b><br/> releng/builder/jenkins-scripts/mininet-fedora.sh</td>
  </tr>
  <tr>
    <td colspan="4">
      Basic Fedora 21 system with ovs v2.3.x and mininet 2.2.1
    </td>
  </tr>
</table>

### Pool: Rackspace DFW - Matrix

<table class="table table-bordered">
  <tr>
    <td><b>Jenkins Label</b><br/> matrix_master</td>
    <td><b>Slave Template name</b><br/> rk-c-el6-matrix</td>
    <td><b>Vagrant Definition</b><br/> releng/builder/vagrant/basic-java-node</td>
    <td><b>Spinup Script</b><br/> releng/builder/jenkins-scripts/matrix.sh</td>
  </tr>
  <tr>
    <td colspan="4">
      This is a very minimal system that is designed to spin up with 2 build
      instances on it. The purpose is to have a location that is not the
      Jenkins master itself for jobs that are executing matrix operations
      since they need a director location. This image should not be used for
      anything but tying matrix jobs before the matrx defined label ties.
    </td>
  </tr>
</table>

# <a name="creating_jenkins_jobs">Creating Jenkins Jobs</a>

Jenkins Job Builder takes simple descriptions of Jenkins jobs in YAML format, and uses them to configure Jenkins.

* [Jenkins Job Builder][11] \(JJB\) documentation
* [releng/builder Gerrit][12]
* [releng/builder Git repository][13]

## <a name="jjb_install">Jenkins Job Builder Installation</a>

### Using Docker

[Docker][14] is an open platform used to create virtualized Linux containers
for shipping self-contained applications. Docker leverages LinuX Containers
\(LXC\) running on the same operating system as the host machine, whereas a
traditional VM runs an operating system over the host.

    docker pull zxiiro/jjb-docker
    docker run --rm -v ${PWD}:/jjb jjb-docker

The Dockerfile that created that image is [here][15]. By default it will run:

    jenkins-jobs test .

You'll need to use the "-v" parameter to mount a directory containing your YAML
files, as well as a configured `jenkins.ini` file if you wish to upload your
jobs to the Sandbox.

### Manual install

Jenkins Jobs in the releng silo use Jenkins Job Builder, so if you need to test
your Jenkins job against the Sandbox you will need to install JJB.

While some OSs do package JJB, it's typically too old to work correctly with
our RelEng templates. We recommend installing from source, either master or
the most recent release. This applies for both Linux and OSX.

For example, using 1.3.0:

    $ git clone https://git.openstack.org/openstack-infra/jenkins-job-builder
    $ cd jenkins-job-builder
    # Stop here if you want to use master
    $ git checkout tags/1.3.0

We [recommend using virtual environments][17] to manage JJB's Python
dependencies. The tool [Virtualenv][18] can help you do so. Once you have
Virtualenv [installed][19], create a new venv for JJB and install its
dependencies, as described in its [`requirements.txt`][20].

    # From your JJB clone's root dir
    $ virtualenv jjb
    $ source jjb/bin/activate
    (jjb)$ pip install -r requirements.txt

Now install JJB.

    (jjb)$ python setup.py install

Note that we're not using `sudo` to install as root, since we want to make
use of the venv we've configured for our current user.

If you may have a system-level install of JJB as well, you should verify you're
path is resolving to the one you'd expect.

    (jjb)$ command -v jenkins-jobs
    /home/daniel/jenkins-job-builder/jjb/bin/jenkins-jobs
    (jjb)$ jenkins-jobs --version
    Jenkins Job Builder version: 1.3.0

You can easily leave and return to your venv. Make sure you activate it before
each use of JJB.

    (jjb)$ deactivate
    $ command -v jenkins-jobs
    # No jenkins-jobs executable found
    $ source jjb/bin/activate
    (jjb)$ # JJB works again

Update: There was an issue with certain JJB versions. Workaround:
TODO: Is this still needed?
https://lists.opendaylight.org/pipermail/integration-dev/2015-October/005000.html

## <a name="jjb_templates">Jenkins Job Templates</a>

The ODL Releng project provides [JJB job templates][2] that can be used to
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
[OpenDaylight's Sonar dashboard](https://sonar.opendaylight.org).

**Note:** Running the "run-sonar" trigger will cause Jenkins to remove its
existing vote if it's already -1'd or +1'd a comment. You will need to re-run
your verify job (recheck) after running this to get Jenkins to put back the
correct vote.

The Sonar Job Template creates a job which will run against the master branch,
or if BRANCHES are specified in the CFG file it will create a job for the
**First** branch listed.

### Integration Job Template

The Integration Job Template creates a job which runs when a project that your
project depends on is successfully built. This job type is basically the same
as a verify job except that it triggers from other Jenkins jobs instead of via
Gerrit review updates. The dependencies that triger integration jobs are listed
in your project.cfg file under the **DEPENDENCIES** variable.

If no dependencies are listed then this job type is disabled by default.

### Patch Test Job

Trigger: **test-integration**

This job runs a full integration test suite against your patch and reports
back the results to Gerrit. Leave a comment with trigger keyword above to activate it
for a particular patch.

This job is maintained by the [Integration/Test][1] project.

**Note:** Running the "test-integration" trigger will cause Jenkins to remove
it's existing vote if it's already -1 or +1'd a comment. You will need to
re-run your verify job (recheck) after running this to get Jenkins to put back
the correct vote.

Some considerations when using this job:

* The patch test verification takes some time (~2 hours) + consumes a lot of
  resources so it is not meant to be used for every patch.
* The system tests for master patches will fail most of the times because both
  code and test are unstable during the release cycle (should be good by the
  end of the cycle).
* Because of the above, patch test results typically have to be interpreted by
  system test experts. The [Integration/Test][1] project can help with that.


## <a name="jjb_basic_configuration">Basic Job Configuration</a>

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

## <a name="jjb_maven_properties">Maven Properties</a>

We provide a properties which your job can take advantage of if you want to do
something different depending on the job type that is run. If you create a
profile that activates on a property listed blow. The JJB templated jobs will
be able to activate the profile during the build to run any custom code you
wish to run in your project.

    -Dmerge   : This flag is passed in our Merge job and is equivalent to the
                Maven property
                <merge>true</merge>.
    -Dsonar   : This flag is passed in our Sonar job and is equivalent to the
                Maven property
                <sonar>true</sonar>.

# <a name="jenkins_sandbox">Jenkins Sandbox</a>

[https://jenkins.opendaylight.org/sandbox](https://jenkins.opendaylight.org/sandbox/)

The Sandbox instance's purpose is to allow projects to test their JJB setups
before merging their code over to the Releng Master silo. It is configured
similarly to the Master instance above however it cannot publish or vote in
Gerrit.

If your project requires access to the Sandbox please open a Help Desk ticket
and provide us with your ODL ID.

## Notes regarding the Sandbox

* Jobs automatically deleted Saturday @ 08:00 UTC (12:00 AM PST / 01:00 AM PDT)
* Committers can login and configure Jenkins jobs directly here (unlike on the
master silo)
* Configuration mirrors the master silo when possible
* Can NOT upload artifacts to Nexus
* Can NOT vote on Gerrit

## Using the Sandbox

Before starting using the sandbox make sure you have Jenkins Job Builder
properly installed in your setup. Refer Jenkins Job Builder Installation
section of this guide.

If you do not already have access, open a helpdesk ticket to request access to
the sandbox instance (Integration committers will have access by default).

1. Clone a copy of the releng/builder repo from https://git.opendaylight.org/gerrit/#/admin/projects/releng/builder
2. cp jenkins.ini.example jenkins.ini
3. Edit the jenkins.ini file at the root of the repo
    * Set your ODL username and password (make sure to uncomment the lines)
    * Set the URL to https://jenkins.opendaylight.org/sandbox

It is good practice to test that your JJB files are valid before pushing using
the test command. If you see no Exceptions or Failures after running the
following command your templates should be good for pushing.

The last parameter is the name of the job you want to push to Jenkins so if
your job template name is **{project}-csit-3node-periodic-{functionality}-{install}-{stream}**
you will need to expand manually the variables {project}, {functionality},
{install}, and {stream} to the exact job you want created in the Sandbox for
example **openflowplugin-csit-1node-periodic-longevity-only-beryllium**. Please
do not push ALL jobs to the Sandbox and only jobs you actually intend to test.

**Note:** the below command examples are being executed from the root of the
builder repo, and assume the "jenkins.ini" file is located there.

    jenkins-jobs --conf jenkins.ini test jjb/ <job-name>
    jenkins-jobs --conf jenkins.ini test jjb/ openflowplugin-csit-periodic-1node-cds-longevity-only-master

Expect to see an XML file describing the build job in \</maven2-moduleset\> tags
on STOUT. If you dont see any XML check that you have assigned values to the
parameters between {} in the YAML files. For example {project}

Once this is complete you can push your JJB jobs to the sandbox with the
command:

    jenkins-jobs --conf jenkins.ini update jjb/ <job-name>
    jenkins-jobs --conf jenkins.ini update jjb/ openflowplugin-csit-periodic-1node-cds-longevity-only-beryllium

**Important Note:** When pushing with jenkins-jobs command it will print out a
message similar to the one below to inform you how many jobs JJB is pushing
online. If the number is greater than 1 (or the number of jobs you passed to
the command to push) then you are pushing too many jobs and should **ctrl+c**
to cancel the upload.

    INFO:jenkins_jobs.builder:Number of jobs generated:  1

If using Docker:

    # To test
    docker run --rm -v ${PWD}:/jjb zxiiro/jjb-docker

    # To upload jobs to the sandbox
    # Please ensure that you include a configured jenkins.ini in your volume mount
    docker run --rm -v ${PWD}:/jjb zxiiro/jjb-docker jenkins-jobs --conf jenkins.ini update . openflowplugin-csit-periodic-1node-cds-longevity-only-master

[0]: https://wiki.opendaylight.org/view/RelEng:Main "Releng:Main"
[1]: https://wiki.opendaylight.org/view/Integration/Test
[2]: https://git.opendaylight.org/gerrit/gitweb?p=releng/builder.git;a=tree;f=jenkins-scripts;h=371193b89f418de2ca0ffcb78be4a2d8046701ae;hb=refs/heads/master "JJB Templates Directory"
[3]: https://jenkins.opendaylight.org/releng "RelEng Jenkins"
[4]: https://git.opendaylight.org/gerrit/gitweb?p=releng%2Fbuilder.git;a=summary "RelEng/Builder gitweb"
[5]: https://git.opendaylight.org/gerrit/gitweb?p=releng/builder.git;a=tree;f=jenkins-scripts;h=69252dd61ece511bd2018039b40e7836a8d49d21;hb=HEAD
[6]: https://git.opendaylight.org/gerrit/gitweb?p=releng/builder.git;a=tree;f=vagrant;h=409a2915d48bbdeea9edc811e1661ae17ca28280;hb=HEAD
[7]: http://ci.openstack.org/jenkins-job-builder/ "JJB"
[8]: https://git.opendaylight.org/gerrit/gitweb?p=releng/builder.git;a=tree;f=vagrant/basic-java-node;h=7197b26b747deba38c08f30a569c233fd9636d72;hb=HEAD
[9]: https://git.opendaylight.org/gerrit/gitweb?p=releng/builder.git;a=blob;f=jenkins-scripts/controller.sh;h=893a04118a9bd9c55ae2a4a6af833fa089e0e0b4;hb=HEAD
[10]: https://git.opendaylight.org/gerrit/gitweb?p=releng/builder.git;a=blob;f=jenkins-scripts/basic_settings.sh;h=9f6d2a89948d0a25a8a4a24102630ada494e8623;hb=HEAD
[11]: http://ci.openstack.org/jenkins-job-builder/
[12]: https://git.opendaylight.org/gerrit/#/admin/projects/releng/builder
[13]: https://git.opendaylight.org/gerrit/gitweb?p=releng/builder.git;a=summary
[14]: https://www.docker.com/whatisdocker/
[15]: https://github.com/zxiiro/jjb-docker/blob/master/Dockerfile
[16]: https://github.com/openstack-infra/jenkins-job-builder
[17]: https://lists.opendaylight.org/pipermail/integration-dev/2015-April/003016.html
[18]: https://virtualenv.readthedocs.org/en/latest/
[19]: http://virtualenv.readthedocs.org/en/latest/installation.html
[20]: https://github.com/openstack-infra/jenkins-job-builder/blob/master/requirements.txt
