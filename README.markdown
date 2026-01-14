RelEng/Builder centralizes OpenDaylight (ODL) CI/CD: Jenkins job templates,
cloud images, packer definitions, and helper scripts used to build, test,
release and publish project artifacts.

Quick links:

-   User / operator documentation: [Read the Docs site][1]
-   Jenkins (production): https://jenkins.opendaylight.org/releng
-   Jenkins (sandbox): https://jenkins.opendaylight.org/sandbox
-   Global shared JJB templates (submodule): `global-jjb/`
-   Contributing: see `CONTRIBUTING.markdown`

Getting started (new project):

1. Clone this repo recursively (brings in `global-jjb`).
2. Add a `jjb/<project>/<project>.yaml` using current examples in
   `jjb/releng-templates-java.yaml` (or language-specific lf-\* templates in
   `global-jjb/jjb/`).
3. Submit for review with `git review`.

See the documentation site for full details, job parameter reference,
supported images and migration notices (e.g. Java 11→17, CentOS 7 deprecation).

[1]: https://docs.opendaylight.org/projects/releng-builder/en/latest/
