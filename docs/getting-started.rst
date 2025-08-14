Getting Started
===============

This page provides a concise entry point for new OpenDaylight projects
integrating with RelEng/Builder.

Steps:

1. Clone the repository (include submodules)

   .. code-block:: bash

      git clone --recursive https://git.opendaylight.org/gerrit/releng/builder
2. Create your project directory under jjb/ and add a <project>.yaml using
   current examples (see jjb/releng-templates-java.yaml or lf-* templates in
   global-jjb/jjb/).
3. Set java-version (default openjdk17) and maven (mvn39 recommended)
   parameters as needed.
4. Include verify, merge, sonar, distribution-check, and an autorelease check
   job if you join the simultaneous release.
5. Submit for review: git add / commit / git review.

See jenkins.rst for detailed explanations of job types, parameters and minion images.
