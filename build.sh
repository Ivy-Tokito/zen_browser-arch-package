#!/usr/bin/bash

set -e

buildir="$(pwd)"

# create non-privileged user for makepkg
groupadd sudo
useradd -G sudo -m user || true
echo "## Allow user to execute any root command
user ALL=(ALL) NOPASSWD: /usr/bin/pacman" >> "/etc/sudoers"

# Change Owners
chown -R user:user "$buildir"

# Build Package
sudo -u user bash <<EXC
makepkg
EXC
echo "Packaging Completed!"

# Copy Out Package
mkdir -p /out/packages
cp -v *.zst /out/packages/
