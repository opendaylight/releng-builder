The purpose of these various directories is to have Vagrant definitions
that are then snapshotted for use as slaves in the OpenDaylight and
ODLForge environments.

If building up in a Rackspace environment using this for the first time
there is a particular order that should be taken to produce a finalized
image.

1. Bring a vagrant image up using the rackspace-convert-base definition.
   This will prepare a basic Rackspace image to operate properly when
   being managed by vagrant. It is purposely very limited in what it
   does.

2. After the rackspace-convert-base image is up and you receive the
   notice to snapshot the image perform a ```nova create-image```
   against the running instance. Once the snapshot is complete you may
   destroy the currently running vagrant image (it's easiest if the
   create-image is done with --poll so you know when it's complete)

3. Bring up one of the various other vagrant images passing
   ```RSIMAGE=${a_vagrant_image_id}``` where ```$a_vagrant_image_id```
   is the imageID that was generated after the snapshotting operation in
   step 2. You probably also want to execute using ```RSRESEAL=true` to
   have the brought up image resealed for cloning purposes.

4. If you executed with ```RSRESEAL=true``` now is the time to take the
   snapshot of the current running vagrant. See step 2

5. The final step in preparing an image for use in the Linux Foundation
   managed environments to then take the image produced in step 4 and
   run the ```lf-networking``` vagrant definition using it. See the
   README.md in that vagrant folder for the required extra environment
   variables.

6. Snapshot the new vagrant, see step 2 for details.

At this point a new Rackspace image will be ready for a given network
configuration. If you, the reader, are looking to utilize any of this
for your own Rackspace managed environment, or standard Vagrant then
step 5 & 6 will likely not be needed as they are specific to how the
Linux Foundation manages the Jenkins environment for OpenDaylight.
