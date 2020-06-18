.. _odl-jenkins:

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

This section attempts to provide details on how to get going as a new project
quickly with minimal steps. The rest of the guide should be read and understood
by those who need to create and contribute new job types that is not already
covered by the existing job templates provided by OpenDaylight's JJB repo.

As a new project you will be mainly interested in getting your jobs to appear
in the jenkins-master_ silo and this can be achieved by simply creating a
<project>.yaml in the releng/builder project's jjb directory.

.. code-block:: bash

    git clone --recursive https://git.opendaylight.org/gerrit/releng/builder
    cd builder
    mkdir jjb/<new-project>

.. note:

    releng/global-jjb is a submodule of releng/builder repository which
    requires a git submodule update --init or using --recursive with git clone.
    `releng-global-jjb`_

Where <new-project> should be the same name as your project's git repo in
Gerrit. If your project is called "aaa" then create a new jjb/aaa directory.

Next we will create <new-project>.yaml as follows:

.. code-block:: yaml

    ---
    - project:
        name: <NEW_PROJECT>-carbon
        jobs:
          - '{project-name}-clm-{stream}'
          - '{project-name}-integration-{stream}'
          - '{project-name}-merge-{stream}'
          - '{project-name}-verify-{stream}-{maven}-{jdks}'

        project: '<NEW_PROJECT>'
        project-name: '<NEW_PROJECT>'
        stream: carbon
        branch: 'master'
        jdk: openjdk8
        jdks:
          - openjdk8
        maven:
          - mvn33:
              mvn-version: 'mvn33'
        mvn-settings: '<NEW_PROJECT>-settings'
        mvn-goals: 'clean install -Dmaven.repo.local=/tmp/r -Dorg.ops4j.pax.url.mvn.localRepository=/tmp/r'
        mvn-opts: '-Xmx1024m -XX:MaxPermSize=256m'
        dependencies: 'odlparent-merge-{stream},yangtools-merge-{stream},controller-merge-{stream}'
        email-upstream: '[<NEW_PROJECT>] [odlparent] [yangtools] [controller]'
        archive-artifacts: ''

    - project:
        name: <NEW_PROJECT>-sonar
        jobs:
          - '{project-name}-sonar'

        project: '<NEW_PROJECT>'
        project-name: '<NEW_PROJECT>'
        branch: 'master'
        mvn-settings: '<NEW_PROJECT>-settings'
        mvn-goals: 'clean install -Dmaven.repo.local=/tmp/r -Dorg.ops4j.pax.url.mvn.localRepository=/tmp/r'
        mvn-opts: '-Xmx1024m -XX:MaxPermSize=256m'

Replace all instances of <new-project> with the name of your project. This will
create the jobs with the default job types we recommend for Java projects. If
your project is participating in the simultanious-release and ultimately will
be included in the final distribution, it is required to add the following job
types into the job list for the release you are participating.


.. code-block:: yaml

    - '{project-name}-distribution-check-{stream}'
    - '{project-name}-validate-autorelease-{stream}'

If you'd like to explore the additional tweaking options available
please refer to the `Jenkins Job Templates`_ section.

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
job, it will be destroyed.

Our Jenkins master supports many types of dynamic build minions. If you are
creating custom jobs then you will need to have an idea of what type of minions
are available. The following are the current minion types and descriptions.
Minion Template Names are needed for jobs that take advantage of multiple
minions as they must be specifically called out by template name instead of
label.

Adding New Components to the Minions
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

If your project needs something added to one of the minions, you can help us
get things added faster by doing one of the following:

* Submit a patch to RelEng/Builder for the appropriate `jenkins-scripts`
  definition which configure software during minion boot up.
* Submit a patch to RelEng/Builder for the `packer/provision` scripts that
  configures software during minion instance imaging.
* Submit a patch to RelEng/Builder for the Packer's templates  in
  the `packer/templates` directory that configures a new instance definition
  along with changes in `packer/provision`.

Going the first route will be faster in the short term as we can inspect the
changes and make test modifications in the sandbox to verify that it works.

.. note::

   The first route may add additional setup time considering this is run every
   time the minion is booted.

The second and third routes, however, is better for the community as a whole as
it will allow others to utilize our Packer setups to replicate our systems more
closely. It is, however, more time consuming as an image snapshot needs to be
created based on the updated Packer definitions before it can be attached to the
Jenkins configuration on sandbox for validation testing.

In either case, the changes must be validated in the sandbox with tests to
make sure that we don't break current jobs and that the new software features
are operating as intended. Once this is done the changes will be merged and
the updates applied to the RelEng Jenkins production silo. Any changes to
files under `releng/builder/packer` will be validated and images would be built
triggered by verify-packer and merge-packer jobs.

Please note that the combination of a Packer definitions from `vars`, `templates`
and the `provision` scripts is what defines a given minion. For instance, a minion
may be defined as `centos7-builder` which is a combination of Packer OS image
definitions from `vars/centos.json`, Packer template definitions from
`templates/builder.json` and spinup scripts from `provision/builder.sh`.
This combination provides the full definition of the realized minion.

Jenkins starts a minion using the latest image which is built and linked into the
Jenkins configuration. Once the base instance is online Jenkins checks out the
RelEng/Builder repo on it and executes two scripts. The first is
`provision/baseline.sh`, which is a baseline for all of the minions.

The second is the specialized script, which handles any system updates,
new software installs or extra environment tweaks that don't make sense in a
snapshot. Examples could include installing new package or setting up a virtual
environment. Its imperative to ensure modifications to these spinup scripts have
considered time taken to install the packages, as this could increase the build
time for every job which runs on the image. After all of these scripts have
executed Jenkins will finally attach the minion as an actual minion and start
handling jobs on it.

Flavors
^^^^^^^

Performance flavors come with dedicated CPUs and are not shared with other
accounts in the cloud so should ensure consistent performance.

.. list-table:: Flavors
   :widths: auto
   :header-rows: 1

   * - Instance Type
     - CPUs
     - Memory

   * - odl-standard-1
     - 1
     - 4

   * - odl-standard-2
     - 2
     - 8

   * - odl-standard-4
     - 4
     - 16

   * - odl-standard-8
     - 8
     - 32

   * - odl-standard-16
     - 16
     - 64

   * - odl-highcpu-2
     - 2
     - 2

   * - odl-highcpu-4
     - 4
     - 4

   * - odl-highcpu-8
     - 8
     - 8

Pool: ODLVEX
^^^^^^^^^^^^

.. raw:: html

    <table class="table table-bordered">
      <tr class="warning">
        <td><b>Jenkins Labels</b><br/>
          centos7-builder-2c-1g,<br/>
          centos7-builder-2c-2g,<br/>
          centos7-builder-2c-8g,<br/>
          centos7-builder-4c-4g,<br/>
          centos7-builder-8c-8g,<br/>
          centos7-autorelease-4c-16g
        </td>
        <td><b>Minion Template names</b><br/>
          prd-centos7-builder-2c-1g,<br/>
          prd-centos7-builder-2c-2g,<br/>
          prd-centos7-builder-2c-8g,<br/>
          prd-centos7-builder-4c-4g,<br/>
          prd-centos7-builder-8c-8g,<br/>
          prd-centos7-autorelease-4c-16g
        <td><b>Packer Template</b><br/>
        releng/builder/packer/templates/builder.json</td>
        <td><b>Playbook</b><br/>
        releng/builder/packer/common-packer/provision/baseline.yaml</td>
      </tr>
      <tr>
        <td colspan="4">
          CentOS 7 build minion configured with OpenJDK 1.7 (Java7) and OpenJDK
          1.8 (Java8) along with all the other components and libraries needed
          for building any current OpenDaylight project. This is the label that
          is used for all basic verify, merge and daily builds for
          projects.
        </td>
      </tr>

      <tr class="warning">
        <td><b>Jenkins Labels</b><br/> centos7-robot-2c-2g</td>
        <td><b>Minion Template names</b><br/> centos7-robot-2c-2g</td>
        <td><b>Packer Template</b><br/>
        releng/builder/packer/templates/robot.json</td>
        <td><b>Playbook</b><br/> releng/builder/packer/provision/robot.yaml</td>
      </tr>
      <tr>
        <td colspan="4">
          CentOS 7 minion configured with OpenJDK 1.7 (Java7), OpenJDK
          1.8 (Java8) and all the current packages used by the integration
          project for doing robot driven jobs. If you are executing robot
          framework jobs then your job should be using this as the minion that
          you are tied to. This image does not contain the needed libraries for
          building components of OpenDaylight, only for executing robot tests.
        </td>
      </tr>

      <tr class="warning">
        <td><b>Jenkins Labels</b><br/> ubuntu1604-mininet-ovs-25-2c-2g</td>
        <td><b>Minion Template names</b><br/> ubuntu1604-mininet-ovs-25-2c-2g</td>
        <td><b>Packer Template</b><br/> releng/builder/packer/templates/mininet-ovs-2.5.json</td>
        <td><b>Playbook</b><br/> releng/builder/packer/provision//mininet-ovs-2.5.yaml</td>
      </tr>
      <tr>
        <td colspan="4">
          Basic Ubuntu 16.04 (Xenial) system with ovs 2.5 and mininet 2.2.1
        </td>
      </tr>

      <tr class="warning">
        <td><b>Jenkins Labels</b><br/> ubuntu1604-mininet-ovs-26-2c-2g</td>
        <td><b>Minion Template names</b><br/> ubuntu1604-mininet-ovs-26-2c-2g</td>
        <td><b>Packer Template</b><br/> releng/builder/packer/templates/mininet-ovs-2.6.json</td>
        <td><b>Playbook</b><br/> releng/builder/packer/provision//mininet-ovs-2.6.yaml</td>
      </tr>
      <tr>
        <td colspan="4">
          Ubuntu 16.04 (Xenial) system with ovs 2.6 and mininet 2.2.1
        </td>
      </tr>

      <tr class="warning">
        <td><b>Jenkins Labels</b><br/> ubuntu1604-mininet-ovs-28-2c-2g</td>
        <td><b>Minion Template names</b><br/> ubuntu1604-mininet-ovs-28-2c-2g</td>
        <td><b>Packer Template</b><br/> releng/builder/packer/templates/mininet-ovs-2.8.json</td>
        <td><b>Playbook</b><br/> releng/builder/packer/provision//mininet-ovs-2.8.yaml</td>
      </tr>
      <tr>
        <td colspan="4">
          Ubuntu 16.04 (Xenial) system with ovs 2.8 and mininet 2.2.1
        </td>
      </tr>

      <tr class="warning">
        <td><b>Jenkins Labels</b><br/> centos7-devstack-2c-4g</td>
        <td><b>Minion Template names</b><br/> centos7-devstack-2c-4g</td>
        <td><b>Packer Template</b><br/> releng/builder/packer/templates/devstack.json</td>
        <td><b>Playbook</b><br/> releng/builder/packer/provision/devstack.yaml</td>
      </tr>
      <tr>
        <td colspan="4">
          CentOS 7 system purpose built for doing OpenStack testing using
          DevStack. This minion is primarily targeted at the needs of the OVSDB
          project. It has OpenJDK 1.7 (aka Java7) and OpenJDK 1.8 (Java8) and
          other basic DevStack related bits installed.
        </td>
      </tr>

      <tr class="warning">
        <td><b>Jenkins Labels</b><br/> centos7-docker-2c-4g</td>
        <td><b>Minion Template names</b><br/> centos7-docker-2c-4g</td>
        <td><b>Packer Template</b><br/> releng/builder/packer/templates/docker.json</td>
        <td><b>Playbook</b><br/> releng/builder/packer/common-packer/provision/docker.yaml</td>
      </tr>
      <tr>
        <td colspan="4">
          CentOS 7 system configured with OpenJDK 1.7 (aka Java7),
          OpenJDK 1.8 (Java8) and Docker. This system was originally custom
          built for the test needs of the OVSDB project but other projects have
          expressed interest in using it.
        </td>
      </tr>

      <tr class="warning">
        <td><b>Jenkins Labels</b><br/> ubuntu1604-gbp-2c-2g</td>
        <td><b>Minion Template names</b><br/> ubuntu1604-gbp-2c-2g</td>
        <td><b>Packer Template</b><br/> releng/builder/packer/templates/gbp.json</td>
        <td><b>Spinup Script</b><br/> releng/builder/jenkins-scripts/gpb.sh</td>
      </tr>
      <tr>
        <td colspan="4">
          Ubuntu 16.04 (Xenial) node with latest OVS and docker installed. Used by Group Based Policy.
        </td>
      </tr>

    </table>

Pool: ODLVEX - HOT (Heat Orchestration Templates)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

HOT integration enables to spin up integration labs servers for CSIT jobs
using heat, rathar than using jclouds (deprecated). Image names are updated
on the project specific job templates using the variable
`{odl,docker,openstack,tools}_system_image` followed by image name in the
format `<platform> - <template> - <date-stamp>`.

.. include:: cloud-images.rst

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
below.

Installing Jenkins Job Builder
------------------------------

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

Documentation is available for installing `python-virtualenvwrapper`_. On Linux
systems with pip (typical), they amount to:

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

    $ git clone --recursive https://git.opendaylight.org/gerrit/p/releng/builder.git

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

TODO: Explain that only the currently merged jjb/requirements.txt is supported,
other options described below are for troubleshooting only.

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

Updating releng/builder repo or global-jjb
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Follow these steps to update the releng/builder repo. The repo uses a submodule from
a global-jjb repo so that common source can be shared across different projects. This
requires updating the releng/builder repo periodically to pick up the changes. New
versions of jjb could also require updating the releng/builder repo. Follow the
previous steps earlier for updating jenkins-jobs using the
`builder/jjb/requirements.txt <odl-jjb-requirements.txt_>`_ file. Ensure that the
version listed in the file is the currently supported version, otherwise install a
different version or simply upgrade using `pip install --upgrade jenkins-job-builder`.

The example below assumes the user has cloned releng/builder to `~/git/releng/builder`.
Update the repo, update the submodules and then submit a test to verify it works.

.. code-block:: bash

    cd ~/git/releng/builder
    git checkout master
    git pull
    git submodule update --init --recursive
    jenkins-jobs --conf jenkins.ini test jjb/ netvirt-csit-1node-openstack-queens-upstream-stateful-fluorine

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


Jenkins Job Templates
---------------------

The OpenDaylight `RelEng/Builder <releng-builder-wiki_>`_ project provides
`jjb-templates`_ that can be used to define basic jobs.

The *Gerrit Trigger* listed in the jobs are keywords that can be used to
trigger the job to run manually by simply leaving a comment in Gerrit for the
patch you wish to trigger against.

All jobs have a default build-timeout value of 360 minutes (6 hrs) but can be
overrided via the opendaylight-infra-wrappers' build-timeout property.

TODO: Group jobs into categories: every-patch, after-merge, on-demand, etc.
TODO: Reiterate that "remerge" triggers all every-patch jobs at once,
because when only a subset of jobs is triggered, Gerrit forgets valid -1 from jobs outside the subset.
TODO: Document that only drafts and commit-message-only edits do not trigger every-patch jobs.
TODO: Document test-{project}-{feature} and test-{project}-all.

.. raw:: html

    <table class="table table-bordered">
      <tr class="warning">
        <td><b>Job Template</b><br/>{project}-distribution-check-{stream}</td>
        <td><b>Gerrit Trigger</b><br/>recheck</td>
      </tr>
      <tr>
        <td colspan="2">
          This job runs the PROJECT-distribution-check-BRANCH job which is
          building also integration/distribution project in order to run SingleFeatureTest.
          It also performs various other checks in order to prevent the change to break autorelease.
        </td>
      </tr>

      <tr class="warning">
        <td><b>Job Template</b><br/>{project}-integration-{stream}</td>
        <td></td>
      </tr>
      <tr>
        <td colspan="2">
          The Integration Job Template creates a job which runs when a project that your
          project depends on is successfully built. This job type is basically the same
          as a verify job except that it triggers from other Jenkins jobs instead of via
          Gerrit review updates. The dependencies that triger integration jobs are listed
          in your project.cfg file under the <b>DEPENDENCIES</b> variable.

          If no dependencies are listed then this job type is disabled by default.
        </td>
      </tr>

      <tr class="warning">
        <td><b>Job Template</b><br/>{project}-merge-{stream}</td>
        <td><b>Gerrit Trigger</b><br/>remerge</td>
      </tr>
      <tr>
        <td colspan="2">
          This job will trigger once a Gerrit patch is merged into the repo.
          It will build HEAD of the current project branch and also run the Maven goals
          <b>source:jar</b> and <b>javadoc:jar</b>.
          Artifacts are uploaded to OpenDaylight's
          <a href="https://nexus.opendaylight.org">Nexus</a> on completion.

          A distribution-merge-{stream} job is triggered to add the new artifacts to the
          integration distribution.

          Running the "remerge" trigger is possible before a Change is merged,
          it would still build the actual HEAD. This job does not alter Gerrit votes.
        </td>
      </tr>

      <tr class="warning">
        <td><b>Job Template</b><br/>{project}-sonar</td>
        <td><b>Gerrit Trigger</b><br/>run-sonar</td>
      </tr>
      <tr>
        <td colspan="2">
          This job runs Sonar analysis and reports the results to
          OpenDaylight's <a href="https://sonar.opendaylight.org">Sonar</a>
          dashboard.

          The Sonar Job Template creates a job which will run against the
          master branch, or if BRANCHES are specified in the CFG file it will
          create a job for the <b>First</b> branch listed.

          <div class="admonition note">
            <p class="first admonition-title">Note</p>
            <p>
              Running the "run-sonar" trigger will cause Jenkins to remove
              its existing vote if it's already -1'd or +1'd a comment. You
              will need to re-run your verify job (recheck) after running
              this to get Jenkins to re-vote.
            </p>
          </div>
        </td>
      </tr>

      <tr class="warning">
        <td><b>Job Template</b><br/>{project}-validate-autorelease-{stream}</td>
        <td><b>Gerrit Trigger</b><br/>recheck</td>
      </tr>
      <tr>
        <td colspan="2">
          This job runs the PROJECT-validate-autorelease-BRANCH job which is
          used as a quick sanity test to ensure that a patch does not depend on
          features that do not exist in the current release.
        </td>
      </tr>

      <tr class="warning">
        <td><b>Job Template</b><br/>{project}-verify-{stream}-{maven}-{jdks}</td>
        <td><b>Gerrit Trigger</b><br/>recheck</td>
      </tr>
      <tr>
        <td colspan="2">
          The Verify job template creates a Gerrit Trigger job that will
          trigger when a new patch is submitted to Gerrit.
          The job only builds the project code (including unit and integration tests).
        </td>
      </tr>

      <tr class="warning">
        <td><b>Job Template</b><br/>{project}-verify-node-{stream}</td>
        <td><b>Gerrit Trigger</b><br/>recheck</td>
      </tr>
      <tr>
        <td colspan="2">
          This job template can be used by a project that is NodeJS based. It
          simply installs a python virtualenv and uses that to install nodeenv
          which is then used to install another virtualenv for nodejs. It then
          calls <b>npm install</b> and <b>npm test</b> to run the unit tests.
          When  using this template you need to provide a {nodedir} and
          {nodever} containing the directory relative to the project root
          containing the nodejs package.json and version of node you wish to
          run tests with.
        </td>
      </tr>

      <tr class="warning">
        <td><b>Job Template</b><br/>{project}-verify-python-{stream} | {project}-verify-tox-{stream}</td>
        <td><b>Gerrit Trigger</b><br/>recheck</td>
      </tr>
      <tr>
        <td colspan="2">
          This job template can be used by a project that uses Tox to build. It
          simply installs a Python virtualenv and uses tox to run the tests
          defined in the project's tox.ini file. If the tox.ini is anywhere
          other than the project's repo root, the path to its directory
          relative to the project's repo root should be passed as {toxdir}.

          The 2 template names verify-python & verify-tox are identical and are
          aliases to each other. This allows the project to use the naming that
          is most reasonable for them.
        </td>
      </tr>

      <tr class="warning">
        <td><b>Job Template</b><br/>integration-patch-test-{stream}</td>
        <td><b>Gerrit Trigger</b><br/>test-integration</td>
      </tr>
      <tr>
        <td colspan="2">
          This job builds a distribution against your Java patch and triggers distribution sanity CSIT jobs.
          Leave a comment with trigger keyword above to activate it for a particular patch.
          This job should not alter Gerrit votes for a given patch.

          The list of CSIT jobs to trigger is defined in csit-list
          <a href="https://git.opendaylight.org/gerrit/gitweb?p=releng/builder.git;a=blob;f=jjb/integration/integration-test-jobs.yaml">here</a>.

          Some considerations when using this job:
          <ul>
            <li>
              The patch test verification takes some time (~2 hours) + consumes a lot of
              resources so it is not meant to be used for every patch.
            </li>
            <li>
              The system tests for master patches will fail most of the times because both
              code and test are unstable during the release cycle (should be good by the
              end of the cycle).
            </li>
            <li>
              Because of the above, patch test results typically have to be interpreted by
              system test experts. The <a href="https://wiki.opendaylight.org/view/Integration/Test">Integration/Test</a>
              project can help with that.
            </li>
        </td>
      </tr>

      <tr class="warning">
        <td><b>Job Template</b><br/>integration-multipatch-test-{stream}</td>
        <td><b>Gerrit Trigger</b><br/>multipatch-build</td>
      </tr>
      <tr>
        <td colspan="2">
          This job builds a list of patches provided in an specific order, and finally builds
          a distribution from either provided patch or latest code in branch.
          For example if someone leaves the following comment in a patch:
          multipatch-build:controller=61/29761/5:45/29645/6,neutron=51/65551/4,netvirt:59/60259/17
          the job will checkout controller patch 61/29761/5, cherry-pick 45/29645/6 and build controller,
          checkout neutron patch 51/65551/4 and build neutron, checkout latest netvirt code,
          cherry-pick 59/60259/17 and build netvirt, finally it will checkout latest distribution
          code and build a distribution. The resulting distribution is stored in Nexus and the URL
          is stored in a variable called BUNDLE_URL visible in the job console.
          This job also accepts a gerrit topic, for example: multipatch-build:topic=binding-tlc-rpc,
          in this case the job will find all patches in the topic binding-tlc-rpc for the projects
          specified in the BUILD_ORDER parameter and will build all projects from the first a patch
          has been found, for successive projects the branch HEAD is used if no patch is found.
          The job uses patch numbers to sort patches in the same project.
          Use multipatch-build-fast (vs multipatch-build) for building projects fast (-Pq).
          This job should not alter Gerrit votes for a given patch, nor will do anything with the
          given patch unless the patch is added to the build list.
        </td>
      </tr>

    </table>

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

.. _odl-jenkins-sandbox:

Jenkins Sandbox
---------------

URL: https://jenkins.opendaylight.org/sandbox

Jenkins Sandbox documentation can be found in the
:doc:`LF Jenkins Sandbox Guide <lfdocs:jenkins-sandbox>`.

.. _example-jenkins.ini: https://git.opendaylight.org/gerrit/gitweb?p=releng/builder.git;a=blob;f=jenkins.ini.example
.. _integration-test-wiki: https://wiki.opendaylight.org/view/Integration/Test
.. _jenkins-master: https://jenkins.opendaylight.org/releng
.. _jenkins.ini: http://docs.openstack.org/infra/jenkins-job-builder/execution.html#configuration-file
.. _jjb-autoupdate-project.py: https://git.opendaylight.org/gerrit/gitweb?p=releng/builder.git;a=blob;f=scripts/jjb-autoupdate-project.py
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
.. _releng-global-jjb: https://gerrit.linuxfoundation.org/infra/#/q/project:releng/global-jjb
.. _releng-builder-wiki: https://wiki.opendaylight.org/view/RelEng/Builder
.. _streams-design-background: https://lists.opendaylight.org/pipermail/release/2015-July/003139.html
.. _spinup-scripts: https://git.opendaylight.org/gerrit/gitweb?p=releng/builder.git;a=tree;f=jenkins-scripts
.. _spinup-scripts-basic_settings.sh: https://git.opendaylight.org/gerrit/gitweb?p=releng/builder.git;a=blob;f=jenkins-scripts/basic_settings.sh
.. _spinup-scripts-controller.sh: https://git.opendaylight.org/gerrit/gitweb?p=releng/builder.git;a=blob;f=jenkins-scripts/controller.sh
