Pool: ODLVEX
^^^^^^^^^^^^

.. note::

   CentOS 7 based minions are deprecated; prefer Ubuntu 22.04 or CentOS Stream 8 where available.

Selected minion types (deprecated examples):

* centos7-builder-* (2c-1g, 2c-2g, 2c-8g, 4c-4g, 8c-8g, autorelease-4c-16g)

  - Packer: ``packer/templates/builder.json``
  - Playbook: ``packer/common-packer/provision/baseline.yaml``
  - Note: Deprecated CentOS 7 general build / autorelease images. Use Ubuntu 22.04 builder going forward.

* centos7-robot-2c-2g

  - Packer: ``packer/templates/robot.json``
  - Playbook: ``packer/provision/robot.yaml``
  - Note: Deprecated robot test runner (CentOS 7); migrate to updated robot images when available.

* ubuntu1804-mininet-ovs-28-2c-2g

  - Packer: ``packer/templates/mininet-ovs-2.8.json``
  - Playbook: ``packer/provision/mininet-ovs-2.8.yaml``
  - Note: Legacy Ubuntu 18.04 + OVS 2.8 for historical CSIT; prefer Ubuntu 22.04 mininet-ovs-217.

* centos7-devstack-2c-4g

  - Packer: ``packer/templates/devstack.json``
  - Playbook: ``packer/provision/devstack.yaml``
  - Note: Deprecated DevStack OpenStack test image (CentOS 7); prefer Ubuntu 22.04 devstack.

* centos7-docker-2c-4g

  - Packer: ``packer/templates/docker.json``
  - Playbook: ``packer/common-packer/provision/docker.yaml``
  - Note: Deprecated CentOS 7 docker image; prefer Ubuntu 20.04/22.04 docker labels.

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
environment. It is imperative to ensure modifications to these spinup scripts have
considered time taken to install the packages, as this could increase the build
time for every job which runs on the image. After all of these scripts have
executed Jenkins will finally attach the minion as an actual minion and start
Pool: ODLVEX
^^^^^^^^^^^^

.. list-table:: CentOS 7 (deprecated) build templates
   :widths: 30 30 20 20
   :header-rows: 1

   * - Jenkins Labels
     - Minion Template Names
     - Packer Template
     - Playbook
   * - centos7-builder-2c-1g, centos7-builder-2c-2g, centos7-builder-2c-8g,\
       centos7-builder-4c-4g, centos7-builder-8c-8g, centos7-autorelease-4c-16g
     - prd-centos7-builder-2c-1g, prd-centos7-builder-2c-2g, prd-centos7-builder-2c-8g,\
       prd-centos7-builder-4c-4g, prd-centos7-builder-8c-8g, prd-centos7-autorelease-4c-16g
     - releng/builder/packer/templates/builder.json
     - releng/builder/packer/common-packer/provision/baseline.yaml
   * - CentOS 7 build minions are deprecated. Use Ubuntu 22.04 (Jammy) or\
       CentOS Stream 8 builder labels for all new jobs. Java 17 is default;\
       Java 11 only for legacy needs.
     - \-
     - \-
     - \-

.. list-table:: CentOS 7 (deprecated) robot templates
   :widths: 30 30 20 20
   :header-rows: 1

   * - Jenkins Labels
     - Minion Template Names
     - Packer Template
     - Playbook
   * - centos7-robot-2c-2g
     - centos7-robot-2c-2g
     - releng/builder/packer/templates/robot.json
     - releng/builder/packer/provision/robot.yaml
   * - Robot image contains only test execution dependencies (deprecated).\
       Prefer Ubuntu 22.04 or CentOS Stream 8 robot images when available.
     - \-
     - \-
     - \-
.. list-table:: Additional deprecated templates
   :widths: 30 30 20 20
   :header-rows: 1

   * - Jenkins Labels
     - Minion Template Names
     - Packer Template
     - Playbook
   * - ubuntu1804-mininet-ovs-28-2c-2g
     - ubuntu1804-mininet-ovs-28-2c-2g
     - releng/builder/packer/templates/mininet-ovs-2.8.json
     - releng/builder/packer/provision/mininet-ovs-2.8.yaml
   * - Ubuntu 18.04 with OVS 2.8 (deprecated; migrate to Ubuntu 22.04 mininet-ovs-217)
     - \-
     - \-
     - \-
   * - centos7-devstack-2c-4g
     - centos7-devstack-2c-4g
     - releng/builder/packer/templates/devstack.json
     - releng/builder/packer/provision/devstack.yaml
   * - CentOS 7 DevStack image (deprecated). Prefer Ubuntu 22.04 devstack.
     - \-
     - \-
     - \-
   * - centos7-docker-2c-4g
     - centos7-docker-2c-4g
     - releng/builder/packer/templates/docker.json
     - releng/builder/packer/common-packer/provision/docker.yaml
   * - CentOS 7 docker image (deprecated). Prefer Ubuntu 20.04/22.04 docker.
     - \-
     - \-
     - \-

Pool: ODLVEX - HOT (Heat Orchestration Templates)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

HOT integration spins up integration lab servers for CSIT jobs using Heat rather
than jclouds (deprecated). Image names update on project-specific job templates
via the ``{odl,docker,openstack,tools}_system_image`` variable using the format
``<platform> - <template> - <date-stamp>``.

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

  # virtualenvwrapper uses this dir for virtual environments
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

Note: Only the version of JJB pinned in the merged ``jjb/requirements.txt`` is
supported in CI. The ad-hoc override examples below are for local
troubleshooting and should not be committed.

To change the version of JJB specified by `builder/jjb/requirements.txt
<odl-jjb-requirements.txt_>`_
to install from the latest commit to the master branch of JJB's git repository:

.. code-block:: bash

  $ cat jjb/requirements.txt
  -e git+https://opendev.org/jjb/jenkins-job-builder#egg=jenkins-job-builder

To install from a tag, like 1.4.0:

.. code-block:: bash

  $ cat jjb/requirements.txt
  -e git+https://opendev.org/jjb/jenkins-job-builder@1.4.0#egg=jenkins-job-builder

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
    jenkins-jobs --conf jenkins.ini test \
      jjb/ netvirt-csit-1node-openstack-queens-upstream-stateful-fluorine

Installing JJB Manually
-----------------------

This section documents installing JJB from its manually cloned repository.

Note that `installing via pip <Installing JJB using pip_>`_ is typically simpler.

Checkout the version of JJB's source you'd like to build.

For example, using master:

.. code-block:: bash

  $ git clone https://opendev.org/jjb/jenkins-job-builder

Using a tag, like 1.4.0:

.. code-block:: bash

  $ git clone https://opendev.org/jjb/jenkins-job-builder
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
overridden via the opendaylight-infra-wrappers' build-timeout property.

Job Categories & Triggers
~~~~~~~~~~~~~~~~~~~~~~~~~

Every patch uploaded (or updated) triggers the standard verify pipeline jobs.
Draft changes and commit-message-only amendments are the only updates that do
not trigger builds.

If you comment ``remerge`` on a change before it merges, Jenkins rebuilds the
current branch HEAD and (historically) triggered all every-patch jobs. Use this
to re-run a full set when a subset was manually triggered and you need a clean
baseline.

Feature / subset test jobs follow the pattern ``test-{project}-{feature}`` and
``test-{project}-all`` (run broader functional suites). These are on-demand
and do not vote on Gerrit.

Job Parameter Reference
~~~~~~~~~~~~~~~~~~~~~~~

Common parameters (lf-* and legacy templates):

* java-version: openjdk17 (default) or openjdk11 (legacy) – selects JDK
  toolchain.
* sonarcloud-java-version / sonar-jdk: JDK for Sonar scanner (defaults to
  java-version).
* maven / mvn-version / maven-version: mvn39, mvn38 – selects configured
  Maven install.
* mvn-settings: ``<project>``-settings – custom settings.xml profile.
* mvn-goals: e.g. clean install -DskipTests – build phases/properties.
* mvn-opts: e.g. -Xmx2g – JVM flags via MAVEN_OPTS/JAVA_TOOL_OPTIONS.
* build-timeout: minutes (default 360) – override via wrapper property.
* dependencies: comma-separated upstream merge job names triggering
  integration jobs.
* stream: release stream identifier (e.g. master, a named release).
* branch: Git branch to build (multi-branch definitions).
* java-opts / jvm-opts: additional JVM flags (runtime/integration phases).
* archive-artifacts: patterns (e.g. ``target/*.log``) to archive.
* email-upstream: tokens for upstream dependency notifications.
* python-version (lf-python): comma-separated Python versions (e.g.
  3.10,3.11).
* go-version (lf-go): Go toolchain (e.g. 1.22.x).
* gradle-version (lf-gradle): Gradle distribution version (e.g. 8.6).
* enable-sonar / sonar: true to include Sonar stage.
* skip-tests / skip-integration-tests: booleans to bypass test phases.

**Core Job Templates (summary)**

* {project}-distribution-check-{stream} (recheck): Builds
  integration/distribution, runs SingleFeatureTest, guards autorelease.
* {project}-integration-{stream} (auto): Triggers on upstream dependency
  merges (project.cfg DEPENDENCIES); disabled if none.
* {project}-merge-{stream} (remerge): Builds HEAD after merge (or
  manually) and publishes artifacts to Nexus.
* {project}-sonar (run-sonar): Runs Sonar analysis; re-run verify
  afterward to restore vote.
* {project}-validate-autorelease-{stream} (recheck): Quick sanity test
  ensuring no dependency on features absent from release.
* {project}-verify-{stream}-{maven}-{java-version} (recheck): Per-patch
  build + unit/integration tests.
* {project}-verify-node-{stream} (recheck): NodeJS project build/test
  (requires nodedir/nodever params; runs npm install & test).
* {project}-verify-python-{stream} / {project}-verify-tox-{stream}
  (recheck): Tox-driven test execution (set toxdir if tox.ini not at repo
  root). Template names are aliases.

.. list-table:: On-demand / Advanced Job Templates
   :widths: 30 15 55
   :header-rows: 1

   * - Job Template
     - Gerrit Trigger
     - Purpose / Notes
   * - integration-patch-test-{stream}
     - test-integration
     - Builds a distribution including the patch, then triggers a CSIT
       subset (see integration-test-jobs.yaml). High resource/time cost
       (~2h); use selectively. Does not vote.
   * - integration-multipatch-test-{stream}
     - multipatch-build
     - Builds multiple patches in order (or by topic) across projects, then
       builds a distribution. Stores bundle URL (BUNDLE_URL) in console.
       Use multipatch-build-fast for quick builds. Does not vote.

Maven Properties
----------------

We provide a properties which your job can take advantage of if you want to do
trigger a different configuration depending on job type. You can create a
profile that activates on a property listed below. The JJB templated jobs will
activate the profile during the build to run any custom code configuration you
wish to run for this job type.

.. code-block:: bash

    -Dmerge   : The Merge job sets this flag and is the same as setting the
                Maven property <merge>true</merge>.
    -Dsonar   : The Sonar job sets this flag and is the same as setting the
                Maven property <sonar>true</sonar>.

.. _odl-jenkins-sandbox:

Jenkins Sandbox
---------------

URL: https://jenkins.opendaylight.org/sandbox

Jenkins Sandbox documentation is available in the
:doc:`LF Jenkins Sandbox Guide <lfdocs:jenkins-sandbox>`.

.. _example-jenkins.ini: https://git.opendaylight.org/gerrit/gitweb?p=releng/\
  builder.git;a=blob;f=jenkins.ini.example
.. _integration-test-wiki: https://wiki.opendaylight.org/view/Integration/Test
.. _jenkins-master: https://jenkins.opendaylight.org/releng
.. _jenkins.ini: https://docs.opendev.org/opendev/jenkins-job-builder/latest/execution.html#configuration-file
.. _jjb-autoupdate-project.py: https://git.opendaylight.org/gerrit/gitweb?p=releng/\
  builder.git;a=blob;f=scripts/jjb-autoupdate-project.py
.. _jjb-docs: https://docs.opendev.org/opendev/jenkins-job-builder/latest/
.. _jjb-init-project.py: https://git.opendaylight.org/gerrit/gitweb?p=releng/\
  builder.git;a=blob;f=scripts/jjb-init-project.py
.. _jjb-repo: https://opendev.org/jjb/jenkins-job-builder
.. _jjb-requirements.txt: https://opendev.org/jjb/jenkins-job-builder/raw/branch/master/requirements.txt
.. _jjb-templates: https://git.opendaylight.org/gerrit/gitweb?p=releng/builder.git;a=tree;f=jjb
.. _odl-jjb-requirements.txt: https://gerrit.linuxfoundation.org/infra/gitweb?p=releng/global-jjb.git;a=blob;f=requirements.txt
.. _odl-nexus: https://nexus.opendaylight.org
.. _odl-sonar: https://sonar.opendaylight.org
.. _python-virtualenv: https://virtualenv.readthedocs.org/en/latest/
.. _python-virtualenvwrapper: https://virtualenvwrapper.readthedocs.org/en/latest/
.. _releng-wiki: https://docs.releng.linuxfoundation.org/en/latest/
.. _releng-builder-gerrit: https://git.opendaylight.org/gerrit/admin/repos/releng%2Fbuilder
.. _releng-builder-repo: https://git.opendaylight.org/gerrit/gitweb?\
  p=releng%2Fbuilder.git;a=summary
.. _releng-global-jjb: https://gerrit.linuxfoundation.org/infra/#/q/project:releng/\
  global-jjb
.. _releng-builder-wiki: https://lf-opendaylight.atlassian.net/wiki/spaces/\
  ODL/pages/12518223/RelEng+Builder
.. _streams-design-background: https://lists.opendaylight.org/pipermail/\
  release/2015-July/003139.html
.. _spinup-scripts: https://git.opendaylight.org/gerrit/gitweb?p=releng/\
  builder.git;a=tree;f=jenkins-scripts
.. _spinup-scripts-basic_settings.sh: https://git.opendaylight.org/gerrit/gitweb?\
  p=releng/builder.git;a=blob;f=jenkins-scripts/basic_settings.sh
.. _spinup-scripts-controller.sh: https://git.opendaylight.org/gerrit/gitweb?\
  p=releng/builder.git;a=blob;f=jenkins-scripts/controller.sh
