#!/bin/bash

# This script formats the patches from a git branch, adds them
# to the current branch and updates the spec file

# To use it, do e.g.
#
#   $> git checkout master
#   $> git remote add -f fedora-openstack git@github.com:fedora-openstack/nova.git
#   $> git branch master-patches fedora-openstack/master
#   $> ./update-patches.sh
#
# Now your left with a commit which updates the patches
#
# When you've pushed and built the package, don't forget to also
# push the patches with e.g.
#
#   $> git push fedora-openstack +master-patches:master
#

spec=$(fedpkg gimmespec)
branch=$(git branch | awk '/^\* / {print $2}')
patches_branch="${branch}-patches"
patches_base=$(awk -F '=' '/# patches_base/ { print $2 }' "${spec}")
orig_patches=$(awk '/^Patch[0-9][0-9]*:/ { print $2 }' "${spec}")

#
# Create a commit which removes all the patches
#
git rm ${orig_patches}
git commit -m "Updated patches from ${patches_branch}" ${orig_patches}

#
# Check out the ${branch}-patches branch and format the patches
#
git checkout "${patches_branch}"
new_patches=$(git format-patch -N "${patches_base}")

#
# Switch back to the original branch and add the patches
#
git checkout "${branch}"
git add ${new_patches}

#
# Remove the Patch/%patch lines from the spec file
#
sed -i '/^\(Patch\|%patch\)[0-9][0-9]*/d' "${spec}"

#
# Add a new set of Patch/%patch lines
#
patches_list=$(mktemp)
patches_apply=$(mktemp)

i=1;
for p in ${new_patches}; do
    printf "Patch%.4d: %s\n" "${i}" "${p}" >> "${patches_list}"
    printf "%%patch%.4d -p1\n" "${i}" >> "${patches_apply}"
    i=$((i+1))
done

sed -i -e "/# patches_base/ { N; r ${patches_list}" -e "}" "${spec}"
sed -i -e "/%setup -q / { N; r ${patches_apply}" -e "}" "${spec}"

rm "${patches_list}" "${patches_apply}"

#
# Update the original commit to include the new set of patches
#
git commit --amend -m "Updated patches from ${patches_branch}" "${spec}" ${new_patches}
