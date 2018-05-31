# OpenDaylight CI Packer

[Packer][1] is a tool for automatically creating VM and container images,
configuring them and post-processing them into standard output formats.

We build OpenDaylight's CI images via Packer.

## Building

You'll need to [install Packer][2], of course.

OpenDaylight's Packer configuration is divided into build-specific variables,
output-specific templates and a set of shared provisioning scripts. To do a
specific build, combine the template for the desired output artifact type with
a variable file. To build a new java-builder instance the following would be done:

```
packer build -var-file=vars/cloud-env.json -var-file=vars/centos-7.json templates/java-builder.json
```

**NOTE:** vars/cloud-env.json is a gitignored file as it contains private
information. A vars/cloud-env.json.example file is provided as an example.

This would build bootable image in two different OpenStack clouds. In specific,
Rackspace's Public cloud and a private OpenStack cloud.

From a high level, the builds:

* Boot a specified base image in both clouds.
* Run a set of shell scripts, listed in the template's shell provisioner
  section, to do any configuration required by the builder.
* Execute a shutdown of the running instance in the clouds.
* Execute a 'nova image-create' operation against the shutdown instance.
* Perform a 'nova delete' operation against the shutdown instance.

[1]: https://www.packer.io/
[2]: https://www.packer.io/intro/getting-started/setup.html
