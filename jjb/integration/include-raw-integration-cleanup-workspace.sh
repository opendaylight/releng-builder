echo "Cleaning up the workspace..."

# Leftover files from previous runs could be wrongly copied as results.
# Keep the cloned integration/test repository!
for file_or_dir in `ls -A -1 -I "test"`
do
  rm -vrf "$file_or_dir"
done
