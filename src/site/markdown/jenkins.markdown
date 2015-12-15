The [Release Engineering project][0] consolidates the Jenkins jobs from
project-specific VMs to a single Jenkins server. Each OpenDaylight project
has a tab for their jobs on the [RelEng Jenkins server][3]. The system utilizes
[Jenkins Job Builder][11] \(JJB\) for the creation and management of the
Jenkins jobs.

Sections:

* [Jenkins Master](#jenkins_master)
* [Build Slaves](#build_slaves)
* [Creating Jenkins Jobs](#creating_jenkins_jobs)
    * [Getting Jenkins Job Builder](#jjb)
        * [Installing Jenkins Job Builder](#jjb_install)
            * [Virtual Environments](#jjb_install_venv)
            * [Installing JJB using pip](#jjb_install_pip)
            * [Installing JJB Manually](#jjb_install_manual)
        * [Jenkins Job Builder Docker Image](#jjb_install_docker)
    * [Jenkins Job Templates](#jjb_templates)
    * [Jenkins Job Basic Configuration](#jjb_basic_configuration)
    * [Jenkins Job Maven Properties](#jjb_maven_properties)
* [Jenkins Sandbox](#jenkins_sandbox)
    * [Configuration](#sandbox_config)
    * [Manual Method](#jjb_use_manual)
    * [Docker Method](#jjb_use_docker)

# <a name="jenkins_master">Jenkins Master</a>

The [Jenkins master server][3] is the home for all project's Jenkins jobs. All
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

## Adding New Components to the Slaves

If your project needs something added to one of the slaves used during build
and test you can help us get things added faster by doing one of the following:

* Submit a patch to RelEng/Builder for the [Jenkins spinup script][5] that
  configures your new piece of software.
* Submit a patch to RelEng/Builder for the [Vagrant template's bootstrap.sh][6]
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
the updates applied to the RelEng Jenkins production silo.

Please note that the combination of a Vagrant slave snapshot and a Jenkins
spinup script is what defines a given slave. For instance, a slave may be
defined by the [`releng/builder/vagrant/basic-java-node/`][8] Vagrant definition
and the [`releng/builder/jenkins-script/controller.sh`][9] Jenkins spinup script
(as the dynamic\_controller slave is). The pair provides the full definition of
the realized slave. Jenkins starts a slave using the last-spun Vagrant snapshot
for the specified definition. Once the base Vagrant instance is online Jenkins
checks out the RelEng/Builder repo on it and executes two scripts. The first is
[`basic_settings.sh`][10], which is a baseline for all of the slaves. The second is
the specialized spinup script, which handles any system updates, new software
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

Jenkins Job Builder takes simple descriptions of Jenkins jobs in YAML format
and uses them to configure Jenkins.

* [Jenkins Job Builder][11] \(JJB\) documentation
* [RelEng/Builder Gerrit][12]
* [RelEng/Builder Git repository][13]

## <a name="jjb">Getting Jenkins Job Builder</a>

OpenDaylight uses Jenkins Job Builder to translate our in-repo YAML job
configuration into job descriptions suitable for consumption by Jenkins.
When testing new Jenkins Jobs in the [sandbox](#jenkins_sandbox), you'll
need to use the `jenkins-jobs` executable to translate a set of jobs into
their XML descriptions and upload them to the sandbox Jenkins server.

We document [installing](#jjb_install) `jenkins-jobs` below. We also provide
a [pre-built Docker image](#jjb_docker) with `jenkins-jobs` already installed.

### <a name="jjb_install">Installing Jenkins Job Builder</a>

For users who aren't already experienced with Docker or otherwise don't want
to use our [pre-built JJB Docker image](#jjb_docker), installing JJB into a
virtual environment is an equally good option.

We recommend using [pip](#jjb_install_pip) to assist with JJB installs, but we
also document [installing from a git repository manually](#jjb_install_manual).
For both, we [recommend][17] using [virtual environments](#jjb_install_venv)
to isolate JJB and its dependencies.

The [`builder/jjb/requirements.txt`][33] file contains the currently
recommended JJB version. Because JJB is fairly unstable, it may be necessary
to debug things by installing different versions. This is documented for both
[pip-assisted](#jjb_install_pip) and [manual](#jjb_install_manual) installs.

#### <a name="jjb_install_venv">Virtual Environments</a>

For both [pip-assisted](#jjb_install_pip) and [manual](#jjb_install_manual) JJB
installs, we [recommend using virtual environments][17] to manage JJB and its
Python dependencies. The [Virtualenvwrapper][30] tool can help you do so.

There are good docs for [installing Virtualenvwrapper][31]. On Linux systems
with pip (typical), they amount to:

    sudo pip install virtualenvwrapper

A virtual environment is simply a directory that you install Python programs
into and then append to the front of your path, causing those copies to be
found before any system-wide versions.

Create a new virtual environment for JJB.

    # Virtaulenvwrapper uses this dir for virtual environments
    $ echo $WORKON_HOME
    /home/daniel/.virtualenvs
    # Make a new virtual environment
    $ mkvirtualenv jjb
    # A new venv dir was created
    (jjb)$ ls -rc $WORKON_HOME | tail -n 1
    jjb
    # The new venv was added to the front of this shell's path
    (jjb)$ echo $PATH
    /home/daniel/.virtualenvs/jjb/bin:<my normal path>
    # Software installed to venv, like pip, is found before system-wide copies
    (jjb)$ command -v pip
    /home/daniel/.virtualenvs/jjb/bin/pip

With your virtual environment active, you should install JJB. Your install will
be isolated to that virtual environment's directory and only visible when the
virtual environment is active.

You can easily leave and return to your venv. Make sure you activate it before
each use of JJB.

    (jjb)$ deactivate
    $ command -v jenkins-jobs
    # No jenkins-jobs executable found
    $ workon jjb
    (jjb)$ command -v jenkins-jobs
    $WORKON_HOME/jjb/bin/jenkins-jobs

#### <a name="jjb_install_pip">Installing JJB using pip</a>

The recommended way to install JJB is via pip.

Clone the latest version of the [`releng/builder`][4] repo.

    $ git clone https://git.opendaylight.org/gerrit/p/releng/builder.git

Before actually installing JJB and its dependencies, make sure you've [created
and activated](#jjb_install_venv) a virtual environment for JJB.

    $ mkvirtualenv jjb

When in doubt, the best version of JJB to attempt to use is the version
specified in the [`builder/jjb/requirements.txt`][33] file.

    # From the root of the releng/builder repo
    (jjb)$ pip install -r jjb/requirements.txt

To change the version of JJB specified by [`builder/jjb/requirements.txt`][33]
to install from the latest commit to the master branch of JJB's git repository:

    $ cat jjb/requirements.txt
    -e git+https://git.openstack.org/openstack-infra/jenkins-job-builder#egg=jenkins-job-builder

To install from a tag, like 1.3.0:

    $ cat jjb/requirements.txt
    -e git+https://git.openstack.org/openstack-infra/jenkins-job-builder@1.3.0#egg=jenkins-job-builder

#### <a name="jjb_install_manual">Installing JJB Manually</a>

This section documents installing JJB from its manually cloned repository.

Note that [installing via pip](#jjb_install_pip) is typically simpler.

Checkout the version of JJB's source you'd like to build.

For example, using master:

    $ git clone https://git.openstack.org/openstack-infra/jenkins-job-builder

Using a tag, like 1.3.0:

    $ git clone https://git.openstack.org/openstack-infra/jenkins-job-builder
    $ cd jenkins-job-builder
    $ git checkout tags/1.3.0

Before actually installing JJB and its dependencies, make sure you've [created
and activated](#jjb_install_venv) a virtual environment for JJB.

    $ mkvirtualenv jjb

You can then use [JJB's `requirements.txt`][20] file to install its
dependences.

    # In the cloned JJB repo, with the desired version of the code checked out
    (jjb)$ pip install -r requirements.txt

Finally, install JJB.

    # In the cloned JJB repo, with the desired version of the code checked out
    (jjb)$ python setup.py install

Note that we're not using `sudo` to install as root, since we want to make
use of the venv we've configured for our current user.

### <a name="jjb_install_docker">JJB Docker Image</a>

[Docker][14] is an open platform used to create virtualized Linux containers
for shipping self-contained applications. Docker leverages LinuX Containers
\(LXC\) running on the same operating system as the host machine, whereas a
traditional VM runs an operating system over the host.

    docker pull zxiiro/jjb-docker
    docker run --rm -v ${PWD}:/jjb jjb-docker

[This Dockerfile][15] created the [zxiiro/jjb-docker image][29]. By default it
will run:

    jenkins-jobs test .

You'll need to use the `-v/--volume=[]` parameter to mount a directory
containing your YAML files, as well as a configured `jenkins.ini` file if you
wish to upload your jobs to the [sandbox](#jenkins_sandbox).

## <a name="jjb_templates">Jenkins Job Templates</a>

The OpenDaylight [RelEng/Builder][21] project provides [JJB job templates][2]
that can be used to define basic jobs.

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

This job will upload artifacts to [OpenDaylight's Nexus][22] on completion.

Merge jobs can be retriggered in Gerrit by leaving a comment that says
**remerge**.

### Daily Job Template

The Daily (or Nightly) Job Template creates a job which will run on a build on
a Daily basis as a sanity check to ensure the build is still working day to
day.

### Sonar Job Template

Trigger: **run-sonar**

This job runs Sonar analysis and reports the results to [OpenDaylight's Sonar
dashboard][23].

**Note:** Running the "run-sonar" trigger will cause Jenkins to remove its
existing vote if it's already -1'd or +1'd a comment. You will need to re-run
your verify job (recheck) after running this to get Jenkins to re-vote.

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

### <a name="patch_test_job">Patch Test Job</a>

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


### Autorelease Validate Job

Trigger: **revalidate**

This job runs the PROJECT-validate-autorelease-BRANCH job which is used as a
quick sanity test to ensure that a patch does not depend on features that do
not exist in the current release.

The **revalidate** trigger is useful in cases where a project's verify job
passed however validate failed due to infra problems or intermittent issues.
It will retrigger just the validate-autorelease job.

## <a name="jjb_basic_configuration">Basic Job Configuration</a>

To create jobs based on existing [templates](#jjb_templates), use the
[`jjb-init-project.py`][24] helper script. When run from the root of
[RelEng/Builder's repo][13], it will produce a file in
`jjb/<project>/<project>.yaml` containing your project's base template.

    $ python scripts/jjb-init-project.py --help
    usage: jjb-init-project.py [-h] [-c CONF] [-d DEPENDENCIES] [-t TEMPLATES]
                               [-s STREAMS] [-p POM] [-g MVN_GOALS] [-o MVN_OPTS]
                               [-a ARCHIVE_ARTIFACTS]
                               project

    positional arguments:
      project               project

    optional arguments:
      -h, --help            show this help message and exit
      -c CONF, --conf CONF  Config file
      -d DEPENDENCIES, --dependencies DEPENDENCIES
                            Project dependencies A comma-seperated (no spaces)
                            list of projects your project depends on. This is used
                            to create an integration job that will trigger when a
                            dependent project-merge job is built successfully.
                            Example: aaa,controller,yangtools
      -t TEMPLATES, --templates TEMPLATES
                            Job templates to use
      -s STREAMS, --streams STREAMS
                            Release streams to fill with default options
      -p POM, --pom POM     Path to pom.xml to use in Maven build (Default:
                            pom.xml
      -g MVN_GOALS, --mvn-goals MVN_GOALS
                            Maven Goals
      -o MVN_OPTS, --mvn-opts MVN_OPTS
                            Maven Options
      -a ARCHIVE_ARTIFACTS, --archive-artifacts ARCHIVE_ARTIFACTS
                            Comma-seperated list of patterns of artifacts to
                            archive on build completion. See:
                            http://ant.apache.org/manual/Types/fileset.html

If all your project requires is the basic verify, merge, and daily jobs then
using the job template should be all you need to configure for your jobs.

### Auto-Update Job Templates

The first line of the job YAML file produced by the [init script][24] will
contain the words `# REMOVE THIS LINE IF...`. Leaving this line will allow the
RelEng/Builder [auto-update script][25] to maintain this file for your project,
should the base templates ever change. It is a good idea to leave this line if
you do not plan to create any complex jobs outside of the provided template.

However, if your project needs more control over your jobs or if you have any
additional configuration outside of the standard configuration provided by the
template, then this line should be removed.

#### Tuning Templates

Allowing the auto-updated to manage your templates doesn't prevent you from
doing some configuration changes. Parameters can be passed to templates via
a `<project>.cfg` in your `builder/jjb/<project>` directory. An example is
provided below, others can be found in the repos of other projects. Tune as
necessary. Unnecessary paramaters can be removed or commented out with a "#"
sign.

    JOB_TEMPLATES: verify,merge,sonar
    STREAMS:
    - beryllium:
        branch: master
        jdks: openjdk7,openjdk8
        autorelease: true
    - stable-lithium:
        branch: stable/lithium
        jdks: openjdk7
    POM: dfapp/pom.xml
    MVN_GOALS: clean install javadoc:aggregate -DrepoBuild -Dmaven.repo.local=$WORKSPACE/.m2repo -Dorg.ops4j.pax.url.mvn.localRepository=$WORKSPACE/.m2repo
    MVN_OPTS: -Xmx1024m -XX:MaxPermSize=256m
    DEPENDENCIES: aaa,controller,yangtools
    ARCHIVE_ARTIFACTS: *.logs, *.patches

Note: [STREAMS][26] is a list of branches you want JJB to generate jobs for.
The first branch will be the branch that reports Sonar analysis. Each branch
must define a "jdks:" section listing the JDKs the verify jobs should run tests
against for the branch. The first JDK listed will be used as the default JDK
for non-verify type jobs.

Note: Projects that are participating in the simultanious release should set
"autorelease: true" under the streams they are participating in autorelease
for. This enables a new job type validate-autorelease which is used to help
identify if Gerrit patches might break autorelease or not.

#### Advanced

It is also possible to take advantage of both the auto-updater and creating
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

The [sandbox instance][27]'s purpose is to allow projects to test their JJB
setups before merging their code over to the RelEng master silo. It is
configured similarly to the master instance, although it cannot publish
artifacts or vote in Gerrit.

If your project requires access to the sandbox please open an OpenDaylight
Helpdesk ticket (<helpdesk@opendaylight.org>) and provide your ODL ID.

## Notes Regarding the Sandbox

* Jobs are automatically deleted every Saturday at 08:00 UTC
* Committers can login and configure Jenkins jobs in the sandbox directly
  (unlike with the master silo)
* Sandbox configuration mirrors the master silo when possible
* Sandbox jobs can NOT upload artifacts to Nexus
* Sandbox jobs can NOT vote on Gerrit

## <a name="sandbox_config">Configuration</a>

Make sure you have Jenkins Job Builder [properly installed](#jjb_install).

If you do not already have access, open an OpenDaylight Helpdesk ticket
(<helpdesk@opendaylight.org>) to request access to ODL's sandbox instance.
[Integration/Test][1] committers have access by default.

JJB reads user-specific configuration from a [`jenkins.ini` file][7]. An
example is provided at [`builder/jenkins.ini.example`][28].

    # If you don't have RelEng/Builder's repo, clone it
    $ git clone https://git.opendaylight.org/gerrit/p/releng/builder.git
    # Make a copy of the example JJB config file (in the builder/ directory)
    $ cp jenkins.ini.example jenkins.ini
    # Edit jenkins.ini with your username, API token and ODL's sandbox URL
    $ cat jenkins.ini
    <snip>
    [jenkins]
    user=<your ODL username>
    password=<your ODL Jenkins sandbox API token>
    url=https://jenkins.opendaylight.org/sandbox
    <snip>

To get your API token, [login to the Jenkins **sandbox** instance][32] (_not
the main master Jenkins instance, different tokens_), go to your user page (by
clicking on your username, for example), click "Configure" and then "Show API
Token".

## <a name="jjb_use_manual">Manual Method</a>

If you [installed JJB locally into a virtual environment](#jjb_install),
you should now activate that virtual environment to access the `jenkins-jobs`
executable.

    $ workon jjb
    (jjb)$

You'll want to work from the root of the RelEng/Builder repo, and you should
have your `jenkins.ini` file [properly configured](#sandbox_config).

### <a name="jjb_manual_test">Testing Jobs</a>

It's good practice to use the `test` command to validate your JJB files before
pushing them.

    jenkins-jobs --conf jenkins.ini test jjb/ <job-name>

If the job you'd like to test is a template with variables in its name, it
must be manually expanded before use. For example, the commonly used template
`{project}-csit-verify-1node-{functionality}` might expand to
`ovsdb-csit-verify-1node-netvirt`.

    jenkins-jobs --conf jenkins.ini test jjb/ ovsdb-csit-verify-1node-netvirt

Successful tests output the XML description of the Jenkins job described by
the specified JJB job name.

### <a name="jjb_manual_push">Pushing Jobs</a>

Once you've [configured your `jenkins.ini`](#sandbox_config) and [verified your
JJB jobs](#jjb_manual_test) produce valid XML descriptions of Jenkins jobs you
can push them to the Jenkins sandbox.

> _**Important Note:** When pushing with `jenkins-jobs`, a log message with
> the number of jobs you're pushing will be issued, typically to stdout.
> **If the number is greater than 1** (or the number of jobs you passed to
> the command to push) then you are pushing too many jobs and should **`ctrl+c`
> to cancel the upload**. Else you will flood the system with jobs._

>       INFO:jenkins_jobs.builder:Number of jobs generated:  1

> _**Failing to provide the final `<job-name>` param will push all jobs!**_

    # Don't push all jobs by omitting the final param! (ctrl+c to abort)
    jenkins-jobs --conf jenkins.ini update jjb/ <job-name>

## <a name="jjb_use_docker">Docker Method</a>

If [using Docker](#jjb_install_docker):

    # To test
    docker run --rm -v ${PWD}:/jjb zxiiro/jjb-docker

> _**Important Note:** When pushing with `jenkins-jobs`, a log message with
> the number of jobs you're pushing will be issued, typically to stdout.
> **If the number is greater than 1** (or the number of jobs you passed to
> the command to push) then you are pushing too many jobs and should **`ctrl+c`
> to cancel the upload**. Else you will flood the system with jobs._

>       INFO:jenkins_jobs.builder:Number of jobs generated:  1

> _**Failing to provide the final `<job-name>` param will push all jobs!**_

    # To upload jobs to the sandbox
    # Please ensure that you include a configured jenkins.ini in your volume mount
    # Making sure not to push more jobs than expected, ctrl+c to abort
    docker run --rm -v ${PWD}:/jjb zxiiro/jjb-docker jenkins-jobs --conf jenkins.ini update . openflowplugin-csit-periodic-1node-cds-longevity-only-master

[0]: https://wiki.opendaylight.org/view/RelEng:Main "ODL RelEng parent project wiki"
[1]: https://wiki.opendaylight.org/view/Integration/Test "ODL Integration/Test wiki"
[2]: https://git.opendaylight.org/gerrit/gitweb?p=releng/builder.git;a=tree;f=jenkins-scripts;h=371193b89f418de2ca0ffcb78be4a2d8046701ae;hb=refs/heads/master "JJB Templates Directory"
[3]: https://jenkins.opendaylight.org/releng "RelEng Jenkins"
[4]: https://git.opendaylight.org/gerrit/gitweb?p=releng%2Fbuilder.git;a=summary "RelEng/Builder gitweb"
[5]: https://git.opendaylight.org/gerrit/gitweb?p=releng/builder.git;a=tree;f=jenkins-scripts;h=69252dd61ece511bd2018039b40e7836a8d49d21;hb=HEAD "Directory of Jenkins slave spinup scripts"
[6]: https://git.opendaylight.org/gerrit/gitweb?p=releng/builder.git;a=tree;f=vagrant;h=409a2915d48bbdeea9edc811e1661ae17ca28280;hb=HEAD "Directory of Jenkins slave Vagrant definitions"
[7]: http://docs.openstack.org/infra/jenkins-job-builder/execution.html#configuration-file "JJB config file docs"
[8]: https://git.opendaylight.org/gerrit/gitweb?p=releng/builder.git;a=tree;f=vagrant/basic-java-node;h=7197b26b747deba38c08f30a569c233fd9636d72;hb=HEAD "Example Jenkins slave Vagrant defition"
[9]: https://git.opendaylight.org/gerrit/gitweb?p=releng/builder.git;a=blob;f=jenkins-scripts/controller.sh;h=893a04118a9bd9c55ae2a4a6af833fa089e0e0b4;hb=HEAD "Jenkins spinup script specialized for a slave"
[10]: https://git.opendaylight.org/gerrit/gitweb?p=releng/builder.git;a=blob;f=jenkins-scripts/basic_settings.sh;h=9f6d2a89948d0a25a8a4a24102630ada494e8623;hb=HEAD "Jenkins spinup script common to all slaves"
[11]: http://ci.openstack.org/jenkins-job-builder/ "JJB docs"
[12]: https://git.opendaylight.org/gerrit/#/admin/projects/releng/builder "ODL RelEng/Builder Gerrit"
[13]: https://git.opendaylight.org/gerrit/gitweb?p=releng/builder.git;a=summary "ODL RelEng/Builder repo"
[14]: https://www.docker.com/whatisdocker/ "Docker docs"
[15]: https://github.com/zxiiro/jjb-docker/blob/master/Dockerfile "Custom ODL JJB Dockerfile"
[16]: https://github.com/openstack-infra/jenkins-job-builder "JJB repo"
[17]: https://lists.opendaylight.org/pipermail/integration-dev/2015-April/003016.html "Recommendation to use venvs"
[18]: https://virtualenv.readthedocs.org/en/latest/ "Virtualenv docs"
[19]: http://virtualenv.readthedocs.org/en/latest/installation.html "Virtualenv install docs"
[20]: https://github.com/openstack-infra/jenkins-job-builder/blob/master/requirements.txt "JJB Python dependencies"
[21]: https://wiki.opendaylight.org/view/RelEng/Builder "ODL RelEng/Builder wiki"
[22]: https://nexus.opendaylight.org "OpenDaylight's Nexus portal"
[23]: https://sonar.opendaylight.org "OpenDaylight's Sonar portal"
[24]: https://git.opendaylight.org/gerrit/gitweb?p=releng/builder.git;a=blob;f=scripts/jjb-init-project.py;h=2133475a4ff9e1f4b18cc288654a4dc050bf808f;hb=refs/heads/master "JJB project config init helper script"
[25]: https://git.opendaylight.org/gerrit/gitweb?p=releng/builder.git;a=blob;f=scripts/jjb-autoupdate-project.py;h=56769bdb7ad5149404f4f50923f4d10af98d8248;hb=refs/heads/master "JJB project config auto-update helper script"
[26]: https://lists.opendaylight.org/pipermail/release/2015-July/003139.html "STREAMS vs BRANCHES design background"
[27]: https://jenkins.opendaylight.org/sandbox/ "OpenDaylight JJB Sandbox"
[28]: https://git.opendaylight.org/gerrit/gitweb?p=releng/builder.git;a=blob;f=jenkins.ini.example;h=c8486f89af99741f4706c23cd6717df9b417ae10;hb=refs/heads/master "JJB sandbox user config example"
[29]: https://hub.docker.com/r/zxiiro/jjb-docker/ "Custom JJB Docker image"
[30]: https://virtualenvwrapper.readthedocs.org/en/latest/ "Virtualenvwrapper docs"
[31]: https://virtualenvwrapper.readthedocs.org/en/latest/install.html "Virtualenvwrapper install docs"
[32]: https://jenkins.opendaylight.org/sandbox/login "ODL Jenkins sandbox login"
[33]: https://git.opendaylight.org/gerrit/gitweb?p=releng/builder.git;a=blob;f=jjb/requirements.txt;h=0a4df2c2a575eb10d3abddb0fb2f4d048645e378;hb=refs/heads/master "ODL JJB requirements.txt file"
