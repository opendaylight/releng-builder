Job Templates Overview
======================

This page summarizes commonly used job templates / macros (high-level). For
full legacy list see jenkins.rst.

Categories
----------

Every-patch (Gerrit triggered):

* {project}-verify-{stream}-{maven}-{java-version}
* {project}-distribution-check-{stream}
* {project}-validate-autorelease-{stream}

Post-merge:

* {project}-merge-{stream}

Quality / Analysis:

* {project}-sonar (or consolidated sonar stages in lf-maven-jobs)

On-demand / resource intensive:

* integration-patch-test-{stream}
* integration-multipatch-test-{stream}

Language-specific (from global-jjb):

* lf-maven-jobs (Java/Maven multi-stage groups, supports java-version,
  mvn-version overrides)
* lf-python-jobs (tox, multi-version matrix)
* lf-go-jobs (includes sonar scan using java-version for scanner)
* lf-gradle-jobs (gradle verify + publish patterns)
* lf-c-cpp-jobs (cmake / build / test / sonar pipelines)

Key Parameters
--------------

* java-version: default openjdk17 (java11 retained for legacy)
* maven / mvn-version: mvn38 / mvn39 (default typically mvn39)
* sonarcloud-java-version / sonar-jdk: Java used by sonar scanner (inherits
  java-version if unset)
* build-timeout: override default 360m via opendaylight-infra-wrappers property

Override Examples
-----------------

Example snippet to override Java & Maven (YAML fragment):

.. code-block:: yaml

   java-version: openjdk17
   maven:
     - mvn39:
         mvn-version: mvn39

Matrix Builds
-------------

Some lf-* jobs create matrix builds (e.g. 3 python versions). See
corresponding files under global-jjb/jjb/ for parameter options.

Sonar / SonarCloud
------------------

Use {project}-sonar or sonar-enabled grouped jobs. Provide project key through
global settings if needed. Set sonarcloud-java-version to ensure scanner JDK
alignment.

Refer to global-jjb release notes (global-jjb/releasenotes) for newly added
parameters and deprecations.
