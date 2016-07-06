Jenkins
=======

The `Release Engineering Project <releng-wiki_>`_ consolidates the Jenkins jobs from
project-specific VMs to a single Jenkins server. Each OpenDaylight project
has a tab for their jobs on the `jenkins-master`_. The system utilizes
`Jenkins Job Builder <jjb-docs_>`_ for the creation and management of the
Jenkins jobs.

Sections:

.. contents::
   :depth: 3
   :local:

New Project Quick Start
-----------------------

.. note::

    We will be revamping releng/builder in the near future to simplify
    the below process.

This section attempts to provide details on how to get going as a new project
quickly with minimal steps. The rest of the guide should be read and understood
by those who need to create and contribute new job types that is not already
covered by the existing job templates provided by OpenDaylight's JJB repo.

As a new project you will be mainly interested in getting your jobs to appear
in the jenkins-master_ silo and this can be achieved by simply creating 2 files
project.cfg and project.yaml in the releng/builder project's jjb directory.

.. code-block:: bash

    git clone https://git.opendaylight.org/gerrit/releng/builder
    cd builder
    mkdir jjb/<new-project>

Where <new-project> should be the same name as your project's git repo in
Gerrit. So if your project is called "aaa" then create a new jjb/aaa directory.

Next we will create <new-project>.yaml as follows:

    # REMOVE THIS LINE IF YOU WANT TO CUSTOMIZE ANYTHING BELOW

That's right all you need is the above comment in this file. Jenkins will
automatically regenerate this file when your patch is merged so we do not need
to do anything special here.

Next we will create <new-project>.cfg as follows:

.. code-block:: yaml

    STREAMS:
        - boron:
            branch: master
            jdks: openjdk8
    DEPENDENCIES: odlparent,controller,yangtools

This is the minimal required CFG file contents and is used to auto-generate the
YAML file. If you'd like to explore the additional tweaking options available
please refer to the `Tuning Templates`_ section.

Finally we need to push these files to Gerrit for review by the releng/builder
team to push your jobs to Jenkins.

.. code-block:: bash

    git add jjb/<new-project>
    git commit -sm "Add <new-project> jobs to Jenkins"
    git review

This will push the jobs to Gerrit and your jobs will appear in Jenkins once the
releng/builder team has reviewed and merged your patch.

Jenkins Master
--------------

The `jenkins-master`_ is the home for all project's Jenkins jobs. All
maintenance and configuration of these jobs must be done via JJB through the
`releng-builder-repo`_. Project contributors can no longer edit the Jenkins jobs
directly on the server.

Build Minions
-------------

The Jenkins jobs are run on build minions (executors) which are created on an
as-needed basis. If no idle build minions are available a new VM is brought
up. This process can take up to 2 minutes. Once the build minion has finished a
job, it will remain online for 45 minutes before shutting down. Subsequent
jobs will use an idle build minion if available.

Our Jenkins master supports many types of dynamic build minions. If you are
creating custom jobs then you will need to have an idea of what type of minions
are available. The following are the current minion types and descriptions.
Minion Template Names are needed for jobs that take advantage of multiple
minions as they must be specifically called out by template name instead of
label.

Adding New Components to the Minions
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

If your project needs something added to one of the minions used during build
and test you can help us get things added faster by doing one of the following:

* Submit a patch to RelEng/Builder for the `spinup-scripts`_ that
  configures your new piece of software.
* Submit a patch to RelEng/Builder for the Vagrant template's bootstrap.sh in
  the `vagrant-definitions`_ directory that configures your new piece of
  software.

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

Please note that the combination of a Vagrant minion snapshot and a Jenkins
spinup script is what defines a given minion. For instance, a minion may be
defined by the `vagrant-basic-java-node`_ Vagrant definition
and the `spinup-scripts-controller.sh`_ Jenkins spinup script
(as the dynamic\_controller minion is). The pair provides the full definition of
the realized minion. Jenkins starts a minion using the last-spun Vagrant snapshot
for the specified definition. Once the base Vagrant instance is online Jenkins
checks out the RelEng/Builder repo on it and executes two scripts. The first is
`spinup-scripts-basic_settings.sh`_, which is a baseline for all of the minions.
The second is
the specialized spinup script, which handles any system updates, new software
installs or extra environment tweaks that don't make sense in a snapshot. After
all of these scripts have executed Jenkins will finally attach the minion as an
actual minion and start handling jobs on it.

Pool: ODLRPC
^^^^^^^^^^^^^^^^^^^

.. raw:: html

    <table class="table table-bordered">
      <tr class="warning">
        <td><b>Jenkins Label</b><br/> dynamic_verify</td>
        <td><b>Minion Template name</b><br/> centos7-builder</td>
        <td><b>Vagrant Definition</b><br/> releng/builder/vagrant/basic-builder</td>
        <td><b>Spinup Script</b><br/> releng/builder/jenkins-scripts/builder.sh</td>
      </tr>
      <tr>
        <td colspan="4">
          A CentOS 7 huild minion. This system has OpenJDK 1.7 (Java7) and OpenJDK
          1.8 (Java8) installed on it along with all the other components and
          libraries needed for building any current OpenDaylight project. This is
          the label that is used for all basic -verify and -daily- builds for
          projects.
        </td>
      </tr>

      <tr class="warning">
        <td><b>Jenkins Label</b><br/> dynamic_merge</td>
        <td><b>Minion Template name</b><br/> centos7-builder</td>
        <td><b>Vagrant Definition</b><br/> releng/builder/vagrant/basic-builder</td>
        <td><b>Spinup Script</b><br/> releng/builder/jenkins-scripts/builder.sh</td>
      </tr>
      <tr>
        <td colspan="4">
          See dynamic_verify (same image on the back side). This is the label that
          is used for all basic -merge and -integration- builds for projects.
        </td>
      </tr>

      <tr class="warning">
        <td><b>Jenkins Label</b><br/> matrix_master</td>
        <td><b>Minion Template name</b><br/> centos7-matrix</td>
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

      <tr class="warning">
        <td><b>Jenkins Label</b><br/> dynamic_robot</td>
        <td><b>Minion Template name</b><br/> centos7-robot</td>
        <td><b>Vagrant Definition</b><br/> releng/builder/vagrant/integration-robotframework</td>
        <td><b>Spinup Script</b><br/> releng/builder/jenkins-scripts/robot.sh</td>
      </tr>
      <tr>
        <td colspan="4">
          A CentOS 7 minion that is configured with OpenJDK 1.7 (Java7), OpenJDK
          1.8 (Java8) and all the current packages used by the integration
          project for doing robot driven jobs. If you are executing robot
          framework jobs then your job should be using this as the minion that
          you are tied to. This image does not contain the needed libraries for
          building components of OpenDaylight, only for executing robot tests.
        </td>
      </tr>

      <tr class="warning">
        <td><b>Jenkins Label</b><br/> ubuntu_mininet</td>
        <td><b>Minion Template name</b><br/> ubuntu-trusty-mininet</td>
        <td><b>Vagrant Definition</b><br/> releng/builder/vagrant/ubuntu-mininet</td>
        <td><b>Spinup Script</b><br/> releng/builder/jenkins-scripts/mininet-ubuntu.sh</td>
      </tr>
      <tr>
        <td colspan="4">
          Basic Ubuntu system with ovs 2.0.2 and mininet 2.1.0
        </td>
      </tr>

      <tr class="warning">
        <td><b>Jenkins Label</b><br/> ubuntu_mininet_ovs_23</td>
        <td><b>Minion Template name</b><br/> ubuntu-trusty-mininet-ovs-23</td>
        <td><b>Vagrant Definition</b><br/> releng/builder/vagrant/ubuntu-mininet-ovs-23</td>
        <td><b>Spinup Script</b><br/> releng/builder/jenkins-scripts/mininet-ubuntu.sh</td>
      </tr>
      <tr>
        <td colspan="4">
          Basic Ubuntu system with ovs 2.3 and mininet 2.2.1
        </td>
      </tr>

      <tr class="warning">
        <td><b>Jenkins Label</b><br/> dynamic_controller</td>
        <td><b>Minion Template name</b><br/> centos7-java</td>
        <td><b>Vagrant Definition</b><br/> releng/builder/vagrant/basic-java-node</td>
        <td><b>Spinup Script</b><br/> releng/builder/jenkins-scripts/controller.sh</td>
      </tr>
      <tr>
        <td colspan="4">
          A CentOS 7 minion that has the basic OpenJDK 1.7 (Java7) and OpenJDK
          1.8 (Java8) installed and is capable of running the controller, not
          building.
        </td>
      </tr>

      <tr class="warning">
        <td><b>Jenkins Label</b><br/> dynamic_java</td>
        <td><b>Minion Template name</b><br/> centos7-java</td>
        <td><b>Vagrant Definition</b><br/> releng/builder/vagrant/basic-java-node</td>
        <td><b>Spinup Script</b><br/> releng/builder/jenkins-scripts/controller.sh</td>
      </tr>
      <tr>
        <td colspan="4">
          See dynamic_controller as it is currently the same image.
        </td>
      </tr>

      <tr class="warning">
        <td><b>Jenkins Label</b><br/> dynamic_java_8g</td>
        <td><b>Minion Template name</b><br/> centos7-java-8g</td>
        <td><b>Vagrant Definition</b><br/> releng/builder/vagrant/basic-java-node</td>
        <td><b>Spinup Script</b><br/> releng/builder/jenkins-scripts/controller.sh</td>
      </tr>
      <tr>
        <td colspan="4">
          See dynamic_controller as it is currently the same image but with 8G of RAM.
        </td>
      </tr>

      <tr class="warning">
        <td><b>Jenkins Label</b><br/> dynamic_devstack</td>
        <td><b>Minion Template name</b><br/> centos7-devstack</td>
        <td><b>Vagrant Definition</b><br/> releng/builder/vagrant/ovsdb-devstack</td>
        <td><b>Spinup Script</b><br/> releng/builder/jenkins-scripts/devstack.sh</td>
      </tr>
      <tr>
        <td colspan="4">
          A CentOS 7 system purpose built for doing OpenStack testing using
          DevStack. This minion is primarily targeted at the needs of the OVSDB
          project. It has OpenJDK 1.7 (aka Java7) and OpenJDK 1.8 (Java8) and
          other basic DevStack related bits installed.
        </td>
      </tr>

      <tr class="warning">
        <td><b>Jenkins Label</b><br/> dynamic_docker</td>
        <td><b>Minion Template name</b><br/> centos7-docker</td>
        <td><b>Vagrant Definition</b><br/> releng/builder/vagrant/ovsdb-docker</td>
        <td><b>Spinup Script</b><br/> releng/builder/jenkins-scripts/docker.sh</td>
      </tr>
      <tr>
        <td colspan="4">
          A CentOS 7 system that is configured with OpenJDK 1.7 (aka Java7),
          OpenJDK 1.8 (Java8) and Docker. This system was originally custom
          built for the test needs of the OVSDB project but other projects have
          expressed interest in using it.
        </td>
      </tr>

      <tr class="warning">
        <td><b>Jenkins Label</b><br/> gbp_trusty</td>
        <td><b>Minion Template name</b><br/> gbp_trusty</td>
        <td><b>Vagrant Definition</b><br/> releng/builder/vagrant/gbp-ubuntu-docker-ovs-node</td>
        <td><b>Spinup Script</b><br/> releng/builder/jenkins-scripts/ubuntu-docker-ovs.sh</td>
      </tr>
      <tr>
        <td colspan="4">
          A basic Ubuntu node with latest OVS and docker installed. Used by Group Based Policy.
        </td>
      </tr>
    </table>

Creating Jenkins Jobs
---------------------

Jenkins Job Builder takes simple descriptions of Jenkins jobs in YAML format
and uses them to configure Jenkins.

* `Jenkins Job Builder (JJB) documentation <jjb-docs_>`_
* `RelEng/Builder Gerrit <releng-builder-gerrit_>`_
* `RelEng/Builder Git repository <releng-builder-repo_>`_

Getting Jenkins Job Builder
---------------------------

OpenDaylight uses Jenkins Job Builder to translate our in-repo YAML job
configuration into job descriptions suitable for consumption by Jenkins.
When testing new Jenkins Jobs in the `Jenkins Sandbox`_, you'll
need to use the `jenkins-jobs` executable to translate a set of jobs into
their XML descriptions and upload them to the sandbox Jenkins server.

We document `installing <Installing Jenkins Job Builder_>`_ `jenkins-jobs`
below. We also provide
a `pre-built Docker image <jjb-docker_>`_ with `jenkins-jobs` already installed.

Installing Jenkins Job Builder
------------------------------

For users who aren't already experienced with Docker or otherwise don't want
to use our `pre-built JJB Docker image <jjb-docker_>`_, installing JJB into a
virtual environment is an equally good option.

We recommend using `pip <Installing JJB using pip_>`_ to assist with JJB
installs, but we
also document `installing from a git repository manually
<Installing JJB Manually_>`_.
For both, we recommend using Python `Virtual Environments`_
to isolate JJB and its dependencies.

The `builder/jjb/requirements.txt <odl-jjb-requirements.txt_>`_ file contains the currently
recommended JJB version. Because JJB is fairly unstable, it may be necessary
to debug things by installing different versions. This is documented for both
`pip-assisted <Installing JJB using pip_>`_ and `manual
<Installing JJB Manually_>`_ installs.

Virtual Environments
--------------------

For both `pip-assisted <Installing JJB using pip_>`_ and `manual
<Installing JJB Manually_>`_ JJB
installs, we recommend using `Python Virtual Environments <python-virtualenv_>`_
to manage JJB and its
Python dependencies. The `python-virtualenvwrapper`_ tool can help you do so.

There are good docs for installing `python-virtualenvwrapper`_. On Linux systems
with pip (typical), they amount to:

.. code-block:: bash

    sudo pip install virtualenvwrapper

A virtual environment is simply a directory that you install Python programs
into and then append to the front of your path, causing those copies to be
found before any system-wide versions.

Create a new virtual environment for JJB.

.. code-block:: bash

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

.. code-block:: bash

    (jjb)$ deactivate
    $ command -v jenkins-jobs
    # No jenkins-jobs executable found
    $ workon jjb
    (jjb)$ command -v jenkins-jobs
    $WORKON_HOME/jjb/bin/jenkins-jobs

Installing JJB using pip
------------------------

The recommended way to install JJB is via pip.

First, clone the latest version of the `releng-builder-repo`_.

.. code-block:: bash

    $ git clone https://git.opendaylight.org/gerrit/p/releng/builder.git

Before actually installing JJB and its dependencies, make sure you've `created
and activated <Virtual Environments_>`_ a virtual environment for JJB.

.. code-block:: bash

    $ mkvirtualenv jjb

The recommended version of JJB to install is the version specified in the
`builder/jjb/requirements.txt <odl-jjb-requirements.txt_>`_ file.

.. code-block:: bash

    # From the root of the releng/builder repo
    (jjb)$ pip install -r jjb/requirements.txt

To validate that JJB was successfully installed you can run this command:

.. code-block:: bash

    (jjb)$ jenkins-jobs --version

To change the version of JJB specified by `builder/jjb/requirements.txt
<odl-jjb-requirements.txt_>`_
to install from the latest commit to the master branch of JJB's git repository:

.. code-block:: bash

    $ cat jjb/requirements.txt
    -e git+https://git.openstack.org/openstack-infra/jenkins-job-builder#egg=jenkins-job-builder

To install from a tag, like 1.4.0:

.. code-block:: bash

    $ cat jjb/requirements.txt
    -e git+https://git.openstack.org/openstack-infra/jenkins-job-builder@1.4.0#egg=jenkins-job-builder

Installing JJB Manually
-----------------------

This section documents installing JJB from its manually cloned repository.

Note that `installing via pip <Installing JJB using pip_>`_ is typically simpler.

Checkout the version of JJB's source you'd like to build.

For example, using master:

.. code-block:: bash

    $ git clone https://git.openstack.org/openstack-infra/jenkins-job-builder

Using a tag, like 1.4.0:

.. code-block:: bash

    $ git clone https://git.openstack.org/openstack-infra/jenkins-job-builder
    $ cd jenkins-job-builder
    $ git checkout tags/1.4.0

Before actually installing JJB and its dependencies, make sure you've `created
and activated <Virtual Environments_>`_ a virtual environment for JJB.

.. code-block:: bash

    $ mkvirtualenv jjb

You can then use JJB's `requirements.txt <jjb-requirements.txt_>`_ file to
install its
dependencies. Note that we're not using `sudo` to install as root, since we want
to make use of the venv we've configured for our current user.

.. code-block:: bash

    # In the cloned JJB repo, with the desired version of the code checked out
    (jjb)$ pip install -r requirements.txt

Then install JJB from the repo with:

.. code-block:: bash

    (jjb)$ pip install .

To validate that JJB was successfully installed you can run this command:

.. code-block:: bash

    (jjb)$ jenkins-jobs --version

JJB Docker Image
----------------

`Docker <docker-docs_>`_ is an open platform used to create virtualized Linux containers
for shipping self-contained applications. Docker leverages LinuX Containers
\(LXC\) running on the same operating system as the host machine, whereas a
traditional VM runs an operating system over the host.

.. code-block:: bash

    docker pull zxiiro/jjb-docker
    docker run --rm -v ${PWD}:/jjb jjb-docker

This `Dockerfile <jjb-dockerfile_>`_ created the
`zxiiro/jjb-docker image <jjb-docker_>`_.
By default it will run:

.. code-block:: bash

    jenkins-jobs test .

You'll need to use the `-v/--volume=[]` parameter to mount a directory
containing your YAML files, as well as a configured `jenkins.ini` file if you
wish to upload your jobs to the `Jenkins Sandbox`_.

Jenkins Job Templates
---------------------

The OpenDaylight `RelEng/Builder <releng-builder-wiki_>`_ project provides
`jjb-templates`_ that can be used to define basic jobs.

Verify Job Template
^^^^^^^^^^^^^^^^^^^

Trigger: **recheck**

The Verify job template creates a Gerrit Trigger job that will trigger when a
new patch is submitted to Gerrit.

Verify jobs can be retriggered in Gerrit by leaving a comment that says
**recheck**.

Merge Job Template
^^^^^^^^^^^^^^^^^^

Trigger: **remerge**

The Merge job template is similar to the Verify Job Template except it will
trigger once a Gerrit patch is merged into the repo. It also automatically
runs the Maven goals **source:jar** and **javadoc:jar**.

This job will upload artifacts to `OpenDaylight's Nexus <odl-nexus_>`_ on completion.

Merge jobs can be retriggered in Gerrit by leaving a comment that says
**remerge**.

Daily Job Template
^^^^^^^^^^^^^^^^^^

The Daily (or Nightly) Job Template creates a job which will run on a build on
a Daily basis as a sanity check to ensure the build is still working day to
day.

Sonar Job Template
^^^^^^^^^^^^^^^^^^

Trigger: **run-sonar**

This job runs Sonar analysis and reports the results to `OpenDaylight's Sonar
dashboard <odl-sonar_>`_.

The Sonar Job Template creates a job which will run against the master branch,
or if BRANCHES are specified in the CFG file it will create a job for the
**First** branch listed.

.. note:: Running the "run-sonar" trigger will cause Jenkins to remove its
          existing vote if it's already -1'd or +1'd a comment. You will need to
          re-run your verify job (recheck) after running this to get Jenkins to
          re-vote.

Integration Job Template
^^^^^^^^^^^^^^^^^^^^^^^^

The Integration Job Template creates a job which runs when a project that your
project depends on is successfully built. This job type is basically the same
as a verify job except that it triggers from other Jenkins jobs instead of via
Gerrit review updates. The dependencies that triger integration jobs are listed
in your project.cfg file under the **DEPENDENCIES** variable.

If no dependencies are listed then this job type is disabled by default.

Distribution Test Job
^^^^^^^^^^^^^^^^^^^^^

Trigger: **test-distribution**

This job builds a distrbution against your patch, passes distribution sanity test
and reports back the results to Gerrit. Leave a comment with trigger keyword above
to activate it for a particular patch.

This job is maintained by the Integration/Test (`integration-test-wiki`_) project.

.. note:: Running the "test-distribution" trigger will cause Jenkins to remove
          it's existing vote if it's already -1 or +1'd a comment. You will need
          to re-run your verify job (recheck) after running this to get Jenkins
          to put back the correct vote.

Patch Test Job
^^^^^^^^^^^^^^

Trigger: **test-integration**

This job runs a full integration test suite against your patch and reports
back the results to Gerrit. Leave a comment with trigger keyword above to activate it
for a particular patch.

This job is maintained by the Integration/Test (`integration-test-wiki`_) project.

.. note:: Running the "test-integration" trigger will cause Jenkins to remove
          it's existing vote if it's already -1 or +1'd a comment. You will need
          to re-run your verify job (recheck) after running this to get Jenkins
          to put back the correct vote.

Some considerations when using this job:

* The patch test verification takes some time (~2 hours) + consumes a lot of
  resources so it is not meant to be used for every patch.
* The system tests for master patches will fail most of the times because both
  code and test are unstable during the release cycle (should be good by the
  end of the cycle).
* Because of the above, patch test results typically have to be interpreted by
  system test experts. The Integration/Test (`integration-test-wiki`_) project
  can help with that.


Autorelease Validate Job
^^^^^^^^^^^^^^^^^^^^^^^^

Trigger: **revalidate**

This job runs the PROJECT-validate-autorelease-BRANCH job which is used as a
quick sanity test to ensure that a patch does not depend on features that do
not exist in the current release.

The **revalidate** trigger is useful in cases where a project's verify job
passed however validate failed due to infra problems or intermittent issues.
It will retrigger just the validate-autorelease job.

Python Verify Job
^^^^^^^^^^^^^^^^^

Trigger: **recheck** | **revalidate**

This job template can be used by a project that is Python based. It simply
installs a python virtualenv and uses tox to run tests. When using the template
you need to provide a {toxdir} which is the path relative to the root of the
project repo containing the tox.ini file.

Node Verify Job
^^^^^^^^^^^^^^^^^

Trigger: **recheck** | **revalidate**

This job template can be used by a project that is NodeJS based. It simply
installs a python virtualenv and uses that to install nodeenv which is then
used to install another virtualenv for nodejs. It then calls **npm install**
and **npm test** to run the unit tests. When using this template you need to
provide a {nodedir} and {nodever} containing the directory relative to the
project root containing the nodejs package.json and version of node you wish to
run tests with.

Basic Job Configuration
-----------------------

To create jobs based on existing `templates <Jenkins Job Templates_>`_, use the
`jjb-init-project.py`_ helper script. When run from the root of
`RelEng/Builder's repo <releng-builder-repo_>`_, it will produce a file in
`jjb/<project>/<project>.yaml` containing your project's base template.

.. code-block:: bash

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

Auto-Update Job Templates
^^^^^^^^^^^^^^^^^^^^^^^^^

The first line of the job YAML file produced by the `jjb-init-project.py`_ script will
contain the words `# REMOVE THIS LINE IF...`. Leaving this line will allow the
RelEng/Builder `jjb-autoupdate-project.py`_ script to maintain this file for your project,
should the base templates ever change. It is a good idea to leave this line if
you do not plan to create any complex jobs outside of the provided template.

However, if your project needs more control over your jobs or if you have any
additional configuration outside of the standard configuration provided by the
template, then this line should be removed.

Tuning Templates
""""""""""""""""

Allowing the auto-updated to manage your templates doesn't prevent you from
doing some configuration changes. Parameters can be passed to templates via
a `<project>.cfg` in your `builder/jjb/<project>` directory. An example is
provided below, others can be found in the repos of other projects. Tune as
necessary. Unnecessary paramaters can be removed or commented out with a "#"
sign.

.. code-block:: yaml

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

.. note:: `STREAMS <streams-design-background_>`_ is a list of branches you want
          JJB to generate jobs for.
          The first branch will be the branch that reports Sonar analysis. Each
          branch must define a "jdks:" section listing the JDKs the verify jobs
          should run tests against for the branch. The first JDK listed will be
          used as the default JDK for non-verify type jobs.

.. note:: Projects that are participating in the simultanious release should set
          "autorelease: true" under the streams they are participating in
          autorelease for. This enables a new job type validate-autorelease
          which is used to help identify if Gerrit patches might break
          autorelease or not.

Advanced
""""""""

It is also possible to take advantage of both the auto-updater and creating
your own jobs. To do this, create a YAML file in your project's sub-directory
with any name other than \<project\>.yaml. The auto-update script will only
search for files with the name \<project\>.yaml. The normal \<project\>.yaml
file can then be left in tact with the "# REMOVE THIS LINE IF..." comment so
it will be automatically updated.

Maven Properties
----------------

We provide a properties which your job can take advantage of if you want to do
something different depending on the job type that is run. If you create a
profile that activates on a property listed blow. The JJB templated jobs will
be able to activate the profile during the build to run any custom code you
wish to run in your project.

.. code-block:: bash

    -Dmerge   : This flag is passed in our Merge job and is equivalent to the
                Maven property
                <merge>true</merge>.
    -Dsonar   : This flag is passed in our Sonar job and is equivalent to the
                Maven property
                <sonar>true</sonar>.

Jenkins Sandbox
---------------

The `jenkins-sandbox`_ instance's purpose is to allow projects to test their JJB
setups before merging their code over to the RelEng master silo. It is
configured similarly to the master instance, although it cannot publish
artifacts or vote in Gerrit.

If your project requires access to the sandbox please open an OpenDaylight
Helpdesk ticket (<helpdesk@opendaylight.org>) and provide your ODL ID.

Notes Regarding the Sandbox
^^^^^^^^^^^^^^^^^^^^^^^^^^^

* Jobs are automatically deleted every Saturday at 08:00 UTC
* Committers can login and configure Jenkins jobs in the sandbox directly
  (unlike with the master silo)
* Sandbox configuration mirrors the master silo when possible
* Sandbox jobs can NOT upload artifacts to Nexus
* Sandbox jobs can NOT vote on Gerrit

Configuration
^^^^^^^^^^^^^

Make sure you have Jenkins Job Builder [properly installed](#jjb_install).

If you do not already have access, open an OpenDaylight Helpdesk ticket
(<helpdesk@opendaylight.org>) to request access to ODL's sandbox instance.
Integration/Test (`integration-test-wiki`_) committers have access by default.

JJB reads user-specific configuration from a `jenkins.ini`_. An
example is provided by releng/builder at `example-jenkins.ini`_.

.. code-block:: bash

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

To get your API token, `login to the Jenkins **sandbox** instance
<jenkins-sandbox-login_>`_ (*not
the main master Jenkins instance, different tokens*), go to your user page (by
clicking on your username, for example), click "Configure" and then "Show API
Token".

Manual Method
^^^^^^^^^^^^^

If you `installed JJB locally into a virtual environment
<Installing Jenkins Job Builder_>`_,
you should now activate that virtual environment to access the `jenkins-jobs`
executable.

.. code-block:: bash

    $ workon jjb
    (jjb)$

You'll want to work from the root of the RelEng/Builder repo, and you should
have your `jenkins.ini` file [properly configured](#sandbox_config).

Testing Jobs
^^^^^^^^^^^^

It's good practice to use the `test` command to validate your JJB files before
pushing them.

.. code-block:: bash

    jenkins-jobs --conf jenkins.ini test jjb/ <job-name>

If the job you'd like to test is a template with variables in its name, it
must be manually expanded before use. For example, the commonly used template
`{project}-csit-verify-1node-{functionality}` might expand to
`ovsdb-csit-verify-1node-netvirt`.

.. code-block:: bash

    jenkins-jobs --conf jenkins.ini test jjb/ ovsdb-csit-verify-1node-netvirt

Successful tests output the XML description of the Jenkins job described by
the specified JJB job name.

Pushing Jobs
^^^^^^^^^^^^

Once you've `configured your \`jenkins.ini\` <Configuration_>`_ and `verified your
JJB jobs <Testing Jobs_>`_ produce valid XML descriptions of Jenkins jobs you
can push them to the Jenkins sandbox.

.. important::

    When pushing with `jenkins-jobs`, a log message with the number
    of jobs you're pushing will be issued, typically to stdout.
    **If the number is greater than 1** (or the number of jobs you
    passed to the command to push) then you are pushing too many
    jobs and should **`ctrl+c` to cancel the upload**. Else you will
    flood the system with jobs.

    .. code-block:: bash

        INFO:jenkins_jobs.builder:Number of jobs generated:  1

    **Failing to provide the final `<job-name>` param will push all
    jobs!**

    .. code-block:: bash

        # Don't push all jobs by omitting the final param! (ctrl+c to abort)
        jenkins-jobs --conf jenkins.ini update jjb/ <job-name>

Running Jobs
^^^^^^^^^^^^

Once you have your Jenkins job configuration `pushed to the
Sandbox <Pushing Jobs_>`_ you can trigger it to run.

Find your newly-pushed job on the `Sandbox's web UI <jenkins-sandbox_>`_. Click
on its name to see the job's details.

Make sure you're `logged in <jenkins-sandbox-login_>`_ to the Sandbox.

Click "Build with Parameters" and then "Build".

Wait for your job to be scheduled and run. Click on the job number to see
details, including console output.

Make changes to your JJB configuration, re-test, re-push and re-run until
your job is ready.

Docker Method
^^^^^^^^^^^^^

If `using Docker <JJB Docker image_>`_:

.. code-block:: bash

    # To test
    docker run --rm -v ${PWD}:/jjb zxiiro/jjb-docker

.. important::

    When pushing with `jenkins-jobs`, a log message with
    the number of jobs you're pushing will be issued, typically to stdout.
    **If the number is greater than 1** (or the number of jobs you passed to
    the command to push) then you are pushing too many jobs and should **`ctrl+c`
    to cancel the upload**. Else you will flood the system with jobs.

    .. code-block:: bash

          INFO:jenkins_jobs.builder:Number of jobs generated:  1

    **Failing to provide the final `<job-name>` param will push all jobs!**

    .. code-block:: bash

        # To upload jobs to the sandbox
        # Please ensure that you include a configured jenkins.ini in your volume mount
        # Making sure not to push more jobs than expected, ctrl+c to abort
        docker run --rm -v ${PWD}:/jjb zxiiro/jjb-docker jenkins-jobs --conf jenkins.ini update . openflowplugin-csit-periodic-1node-cds-longevity-only-master

.. _docker-docs: https://www.docker.com/whatisdocker/
.. _example-jenkins.ini: https://git.opendaylight.org/gerrit/gitweb?p=releng/builder.git;a=blob;f=jenkins.ini.example
.. _integration-test-wiki: https://wiki.opendaylight.org/view/Integration/Test
.. _jenkins-master: https://jenkins.opendaylight.org/releng
.. _jenkins-sandbox: https://jenkins.opendaylight.org/sandbox
.. _jenkins-sandbox-login: https://jenkins.opendaylight.org/sandbox/login
.. _jenkins.ini: http://docs.openstack.org/infra/jenkins-job-builder/execution.html#configuration-file
.. _jjb-autoupdate-project.py: https://git.opendaylight.org/gerrit/gitweb?p=releng/builder.git;a=blob;f=scripts/jjb-autoupdate-project.py
.. _jjb-docker: https://hub.docker.com/r/zxiiro/jjb-docker/
.. _jjb-dockerfile: https://github.com/zxiiro/jjb-docker/blob/master/Dockerfile
.. _jjb-docs: http://ci.openstack.org/jenkins-job-builder/
.. _jjb-init-project.py: https://git.opendaylight.org/gerrit/gitweb?p=releng/builder.git;a=blob;f=scripts/jjb-init-project.py
.. _jjb-repo: https://github.com/openstack-infra/jenkins-job-builder
.. _jjb-requirements.txt: https://github.com/openstack-infra/jenkins-job-builder/blob/master/requirements.txt
.. _jjb-templates: https://git.opendaylight.org/gerrit/gitweb?p=releng/builder.git;a=tree;f=jjb
.. _odl-jjb-requirements.txt: https://git.opendaylight.org/gerrit/gitweb?p=releng/builder.git;a=blob;f=jjb/requirements.txt
.. _odl-nexus: https://nexus.opendaylight.org
.. _odl-sonar: https://sonar.opendaylight.org
.. _python-virtualenv: https://virtualenv.readthedocs.org/en/latest/
.. _python-virtualenvwrapper: https://virtualenvwrapper.readthedocs.org/en/latest/
.. _releng-wiki: https://wiki.opendaylight.org/view/RelEng:Main
.. _releng-builder-gerrit: https://git.opendaylight.org/gerrit/#/admin/projects/releng/builder
.. _releng-builder-repo: https://git.opendaylight.org/gerrit/gitweb?p=releng%2Fbuilder.git;a=summary
.. _releng-builder-wiki: https://wiki.opendaylight.org/view/RelEng/Builder
.. _streams-design-background: https://lists.opendaylight.org/pipermail/release/2015-July/003139.html
.. _spinup-scripts: https://git.opendaylight.org/gerrit/gitweb?p=releng/builder.git;a=tree;f=jenkins-scripts
.. _spinup-scripts-basic_settings.sh: https://git.opendaylight.org/gerrit/gitweb?p=releng/builder.git;a=blob;f=jenkins-scripts/basic_settings.sh
.. _spinup-scripts-controller.sh: https://git.opendaylight.org/gerrit/gitweb?p=releng/builder.git;a=blob;f=jenkins-scripts/controller.sh
.. _vagrant-basic-java-node: https://git.opendaylight.org/gerrit/gitweb?p=releng/builder.git;a=tree;f=vagrant/basic-java-node
.. _vagrant-definitions: https://git.opendaylight.org/gerrit/gitweb?p=releng/builder.git;a=tree;f=vagrant
