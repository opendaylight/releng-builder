Signing Gerrit Commits
======================

1. Generate your GPG key. See:
   https://lists.opendaylight.org/pipermail/tsc/2015-April/002841.html
     Note: the \*s around the non commented lines are just to indicate
     it's a command at the CLI.

2. Install gpg, instead of or addition to gpg2. It appears as though
   gpg2 has annoying things that it does when asking for your
   passphrase, which I haven't debugged yet.
     Note: you can tell git to use gpg by doing:
     ``git config --global gpg.program gpg2``
     but that then will seem to struggle asking for your
     passphrase unless you have your gpg-agent set up right.

3. Add you GPG to Gerrit

   a. https://git.opendaylight.org/gerrit/#/settings/gpg-keys
   b. ``gpg --export -a <fingerprint>`` // e.g., gpg --export -a F566C9B1
   c. copy that output and paste it into the box and click add

3. Set up your git to sign commits and push signatures

   a. ``git config commit.gpgsign true``
        Note: you can do this instead with ``git commit -S``
   b. ``git config push.gpgsign true``
         Note: you can do this instead with ``git push --signed``
   c. ``git config user.signingkey <fingerprint>``
      // e.g., git config user.signingkey F566C9B1

4. Commit and push a change

   a. change a file
   b. git commit -asm "test commit"
      Note: this should result in git asking you for your passphrase
   c. git review
        Note: this should result in git asking you for your passphrase

        Note: annoyingly, the presence of a gpgp signature or pushing
        of a gpg signature isn't recognized as a "change" by
        Gerrit, so if you forget to do either, you need to change
        something about the commit to get Gerrit to accept the
        patch again. Slightly tweaking the commit message is a
        good way.

        Note: this assumes you have git review set up and push.gpgsign
        set to true. Otherwise:

          ``git push --signed gerrit HEAD:refs/for/master``
            Note: this assumes you have your gerrit remote set up, if
            not it's something like:
            ``ssh://ckd@git.opendaylight.org:29418/<repo>.git``
            where repo is something like docs or controller

5. Verify that your commit is signed by going to the change in Gerrit
   and checking for a green check (instead of a blue ?) next to your
   name.
