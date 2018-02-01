.. _odl-release-workflow:

Release Workflow
================

This page documents the workflow for releasing for projects that are not built
and released via the Autorelease project.

Sections:

.. contents::
   :depth: 3
   :local:

Workflow
--------

OpenDaylight uses Nexus as it's artifact repository for releasing artifacts to
the world. The workflow involves using Nexus to produce a staging repository
which can be tested and reviewed before being approved to copy to the final
destination opendaylight.release repo. The workflow in general is as follows:

1. Project create release tag and push to Gerrit
2. Project will contact helpdesk@opendaylight.org with project name and build
   tag to produce a release candidate / staging repo
3. Helpdesk will run a build and notify project of staging repo location
4. Project tests staging repo and notifies Helpdesk with go ahead to release
5. Helpdesk clicks Release repo button in Nexus
6. (optional) Helpdesk runs Jenkins job to push update-site.zip to p2repos
   sites repo

Step 6 is only necessary for Eclipse projects that need to additionally deploy
an update site to a webserver.

Release Job
-----------

There is a JJB template release job which should be used for a project if the
project needs to produce a staging repo for release. The supported Job types
are listed below, use the one relevant to your project.

**Maven|Java** {name}-release-java -- this job type will produce a staging repo
in Nexus for Maven projects.

**P2 Publisher** {name}-publish-p2repo -- this job type is useful for projects
that produce a p2 repo that needs to be published to a special URL.
