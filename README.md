= How to test locally
    - Use the official Jenkins docker image:
        docker run -d -p 8080:8080 jenkins:weekly"
    - Then install the Jenkins Plugin Dependencies as listed below
    - Run JJB with:
        jenkins-jobs -l DEBUG --conf jenkins.ini update jjb

= Jenkins Plugin Dependencies
    - Email-ext Plugin
    - Gerrit Trigger Plugin
    - Git Plugin
    - Sonar Plugin
    - SSH-Agent Plugin

= Creating jobs from OpenDaylight templates

The ODL Releng project provides 3 job templates which can be used to
define basic jobs.

== Verify Job Template

The Verify job template creates a Gerrit Trigger job that will trigger
when a new patch is submitted to Gerrit.

== Merge Job Template

The Merge job template is similar to the Verify Job Template except it
will trigger once a Gerrit patch is merged into
the repo.

== Daily Job Template

The Daily (or Nightly) Job Template creates a job which will run on a
Daily basis and also Submits Sonar reports.


== Basic Job Configuration

To create a jobs based on the above templates you can use the following
example which will create 6 jobs (verify, merge, and daily jobs for both
master and stable/helium branch).

Before starting create a sub-directory under jjb/ for your project
configuration files.

    1. mkdir jjb/PROJECT                # For example controller
    2. touch jjb/PROJECT/PROJECT.yaml
    3. Add your job configuration to jjb/PROJECT/PROJECT.yaml

If all your project requires is the basic verify, merge, and
daily jobs then the following template should be all you need to
configure for your job.

Replace:

PROJECT:           Project Name
PROJECT_SCM_URL:   URL to Gerrit repo
PROJECT_MVN_GOALS: Maven Goals
PROJECT_MVN_OPTS:  Maven Options

########### EXAMPLE ###########

- project:
    name: PROJECT
    jobs:
        - '{name}-verify-{stream}'
        - '{name}-merge-{stream}'
        - '{name}-daily-{stream}'

    # SCM
    scm-url: PROJECT_SCM_URL
    stream:
        - master:
            branch: master
        - stable-helium:
            branch: stable/helium

    # Maven
    mvn-goals: 'PROJECT_MVN_GOALS'
    mvn-opts: 'PROJECT_MVN_OPTS'

    # Email Publisher
    email-prefix: '[PROJECT]'

########### END EXAMPLE ###########



Sample data:

########### SAMPLE ###########

- project:
    name: aaa
    jobs:
        - '{name}-verify-{stream}'
        - '{name}-merge-{stream}'
        - '{name}-daily-{stream}'

    # SCM
    scm-url: ssh://jenkins-controller@git.opendaylight.org:29418/aaa.git
    stream:
        - master:
            branch: master
        - stable-helium:
            branch: stable/helium

    # Maven
    mvn-goals: '-Dmaven.repo.local=$WORKSPACE/.m2repo -Dorg.ops4j.pax.url.mvn.localRepository=$WORKSPACE/.m2repo clean install'
    mvn-opts: '-Xmx1024m -XX:MaxPermSize=256m'

    # Email Publisher
    email-prefix: '[aaa]'

########### END SAMPLE ###########
