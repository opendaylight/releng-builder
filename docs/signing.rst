Signing Gerrit Commits
======================

1. Generate your GPG key.

   The following instructions work on a Mac, but the general approach
   should be the same on other OSes.

   .. code-block:: bash

      brew install gpg2 # if you don't have homebrew, get that here: http://brew.sh/
      gpg2 --gen-key
      # pick 1 for "RSA and RSA"
      # enter 4096 to creat a 4096-bit key
      # enter an expiration time, I picked 2y for 2 years
      # enter y to accept the expiration time
      # pick O or Q to accept your name/email/comment
      # enter a pass phrase twice. it seems like backspace doesn't work, so type carefully
      gpg2 --fingerprint
      # you'll get something like this:
      # spectre:~ ckd$ gpg2 --fingerprint
      # /Users/ckd/.gnupg/pubring.gpg
      # -----------------------------
      # pub   4096R/F566C9B1 2015-04-06 [expires: 2017-04-05]
      #       Key fingerprint = 7C37 02AC D651 1FA7 9209  48D3 5DD5 0C4B F566 C9B1
      # uid       [ultimate] Colin Dixon <colin at colindixon.com>
      # sub   4096R/DC1497E1 2015-04-06 [expires: 2017-04-05]
      # you're looking for the part after 4096R, which is your key ID
      gpg2 --send-keys <key-id>
      # in the above example, the key-id would be F566C9B1
      # you should see output like this:
      # gpg: sending key F566C9B1 to hkp server keys.gnupg.net

   If you're trying to participate in an OpenDaylight keysigning, then
   send the output of ``gpg2 --fingerprint <key-id>`` to
   keysigning@opendaylight.org

   .. code-block:: bash

      gpg2 --fingerprint <key-id>
      # in the above example, the key-id would be F566C9B1
      # in my case, the output was:
      # pub   4096R/F566C9B1 2015-04-06 [expires: 2017-04-05]
      #       Key fingerprint = 7C37 02AC D651 1FA7 9209  48D3 5DD5 0C4B F566 C9B1
      # uid       [ultimate] Colin Dixon <colin at colindixon.com>
      # sub   4096R/DC1497E1 2015-04-06 [expires: 2017-04-05]

2. Install gpg, instead of or addition to gpg2. It appears as though
   gpg2 has annoying things that it does when asking for your
   passphrase, which I haven't debugged yet.

   .. note:: you can tell git to use gpg by doing:
     ``git config --global gpg.program gpg2``
     but that then will seem to struggle asking for your
     passphrase unless you have your gpg-agent set up right.

3. Add you GPG to Gerrit

   a. Run the following at the CLI:

      .. code-block:: bash

         gpg --export -a <fingerprint>
         # e.g., gpg --export -a F566C9B1
         # in my case the output looked like:
         # -----BEGIN PGP PUBLIC KEY BLOCK-----
         # Version: GnuPG v2
         #
         # mQINBFUisGABEAC/DkcjNUhxQkRLdfbfdlq9NlfDusWri0cXLVz4YN1cTUTF5HiW
         # ...
         # gJT+FwDvCGgaE+JGlmXgjv0WSd4f9cNXkgYqfb6mpji0F3TF2HXXiVPqbwJ1V3I2
         # NA+l+/koCW0aMReK
         # =A/ql
         # -----END PGP PUBLIC KEY BLOCK-----

   b. Browse to https://git.opendaylight.org/gerrit/#/settings/gpg-keys
   c. Click Add Key...
   d. Copy the output from the above command, paste it into the box,
      and click Add

3. Set up your git to sign commits and push signatures

   .. code-block:: bash

      git config commit.gpgsign true
      git config push.gpgsign true
      git config user.signingkey <fingerprint>
      # e.g., git config user.signingkey F566C9B1

   .. note:: you can do this instead with ``git commit -S``
      You can use ``git commit -S`` and ``git push --signed``
      on the CLI instead of configuring it in config if you
      want to control which commits use your signature.

4. Commit and push a change

   a. change a file
   b. ``git commit -asm "test commit"``

      .. note:: this should result in git asking you for your passphrase

   c. ``git review``

      .. note:: this should result in git asking you for your passphrase

      .. note:: annoyingly, the presence of a gpgp signature or pushing
        of a gpg signature isn't recognized as a "change" by
        Gerrit, so if you forget to do either, you need to change
        something about the commit to get Gerrit to accept the
        patch again. Slightly tweaking the commit message is a
        good way.

      .. note:: this assumes you have git review set up and push.gpgsign
        set to true. Otherwise:

        ``git push --signed gerrit HEAD:refs/for/master``

        .. note:: this assumes you have your gerrit remote set up, if
            not it's something like:
            ``ssh://ckd@git.opendaylight.org:29418/<repo>.git``
            where repo is something like docs or controller

5. Verify that your commit is signed by going to the change in Gerrit
   and checking for a green check (instead of a blue ?) next to your
   name.
