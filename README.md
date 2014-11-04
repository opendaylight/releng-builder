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

Note: The templates below depend on a modified JJB version to add
      support for Config File Provider module in the Maven Project
      module for JJB. This custom version of JJB can be found at:
      https://github.com/zxiiro/jenkins-job-builder/tree/support-config-file-provider

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
master and stable/helium branch).

Run the following steps from the repo root to create initial job config.

    python scripts/jjb-init-project.py <project-name>

    # Example
    python scripts/jjb-init-project.py aaa

    # Optionally pass the following options:
    #
    # -g / --mvn-goals : With your job's Maven Goals necessary to build
    #                    (defaults to "clean install")
    #          Example : -g "clean install"
    #
    # -o / --mvn-opts  : With your job's Maven Options necessary to build
    #                    (defaults to empty)
    #          Example : -o "-Xmx1024m"

If all your project requires is the basic verify, merge, and
daily jobs then using the job.template should be all you need to
configure for your jobs.
