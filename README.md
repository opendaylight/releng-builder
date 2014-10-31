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

To create a jobs based on the above templates you can use the example
template which will create 6 jobs (verify, merge, and daily jobs for both
master and stable/helium branch). Begin by using job.yaml.template as a
starting point. You can also look at job.yaml.example to see an example
of a job configuration that is filled out.

Before starting create a sub-directory under jjb/ for your project
configuration files.

    1. mkdir jjb/PROJECT                # For example aaa
    2. cp jjb/job.yaml.template jjb/PROJECT/PROJECT.yaml
    3. Modify jjb/PROJECT/PROJECT.yaml and replace the following keywords
        - PROJECT: With your project name (eg. aaa)
        - MAVEN_GOALS: With your job's Maven Goals necessary to build
        - MAVEN_OPTS: With your job's Maven Options necessary to build

If all your project requires is the basic verify, merge, and
daily jobs then using the job.template should be all you need to
configure for your jobs.
