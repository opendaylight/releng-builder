# How to test locally
* Use the official Jenkins docker image:
    docker run -d -p 8080:8080 jenkins:weekly"
* Then install the Jenkins Plugin Dependencies as listed below
* Run JJB with:
    jenkins-jobs -l DEBUG --conf jenkins.ini update jjb

# Jenkins Plugin Dependencies
* Email-ext Plugin
* Gerrit Trigger Plugin
* Git Plugin
* Sonar Plugin
* SSH-Agent Plugin

# Creating jobs from OpenDaylight templates

The ODL Releng project provides 3 job templates which can be used to
define basic jobs.

Note: The templates below depend on a modified JJB version to add
      support for Config File Provider module in the Maven Project
      module for JJB. This custom version of JJB can be found at:
      https://github.com/zxiiro/jenkins-job-builder/tree/support-config-file-provider

## Verify Job Template

The Verify job template creates a Gerrit Trigger job that will trigger
when a new patch is submitted to Gerrit.

Verify jobs can be retriggered in Gerrit by leaving a comment that says
**recheck**.

## Merge Job Template

The Merge job template is similar to the Verify Job Template except it
will trigger once a Gerrit patch is merged into the repo.

Merge jobs can be retriggered in Gerrit by leavning a comment that says
**remerge**.

## Daily Job Template

The Daily (or Nightly) Job Template creates a job which will run on a
Daily basis and also Submits Sonar reports.


## Basic Job Configuration

To create jobs based on the above templates you can use the example
template which will create 6 jobs (verify, merge, and daily jobs for both
master and stable/helium branch).

Run the following steps from the repo root to create initial job config.
This script will produce a file in jjb/<project>/<project>.yaml
containing your project's base template.

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

If all your project requires is the basic verify, merge, and
daily jobs then using the job.template should be all you need to
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

    MVN_GOALS: clean install javadoc:aggregate -DrepoBuild -Dmaven.repo.local=$WORKSPACE/.m2repo -Dorg.ops4j.pax.url.mvn.localRepository=$WORKSPACE/.m2repo
    MVN_OPTS: -Xmx1024m -XX:MaxPermSize=256m
    DEPENDENCIES: aaa,controller,yangtools

#### Advanced

It is also possible to take advantage of both the auto updater and creating
your own jobs. To do this, create a YAML file in your project's sub-directory
with any name other than <project>.yaml. The auto-update script will only
search for files with the name <project>.yaml. The normal <project>.yaml
file can then be left in tact with the "# REMOVE THIS LINE IF..." comment so
it will be automatically updated.
