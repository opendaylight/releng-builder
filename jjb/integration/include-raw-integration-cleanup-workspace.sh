echo "Cleaning up the workspace..."

# Leftover files from previous runs could be wrongly copied as results.
# Keep the cloned integration/test repository!
for file_or_dir in `ls -A -1 -I "test"`
# FIXME: Make this compatible with multipatch and other possible build&run jobs.
do
  rm -vrf "$file_or_dir"
done
