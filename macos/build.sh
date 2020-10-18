#!/bin/bash
set -eux

# Install gtar
HOMEBREW_NO_AUTO_UPDATE=1 brew install gnu-tar

# To bootstrap pip
curl https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py

# Get the relocatable python repo
git clone https://github.com/gregneagle/relocatable-python.git
pushd relocatable-python
git checkout 8bce58e91895978da6f238c1d2e1de3559ea4643
git apply ../relocatable-python.patch

for version in "2.7.18_10.9" "3.5.4_10.6" "3.6.8_10.9" "3.7.8_10.9" "3.8.5_10.9"
do
    # Split version
    IFS='_' read -a ver <<< "$version"

    # Get python and make it relocatable
    ./make_relocatable_python_framework.py --python-version=${ver[0]} --os-version=${ver[1]}

    # Fix some rpaths
    pushd ./Python.framework/Versions/Current/lib/python*/lib-dynload/
    find . -type f -name "*.so" -exec sh -c '(otool -L "$0" | grep rpath) > /dev/null' {} \; -print | xargs -L 1 install_name_tool -add_rpath @loader_path/../../../../../
    popd

    # Package it
    gtar -cvzf "darwin_$version.tar.gz" --hard-dereference Python.framework
    rm -rf Python.framework
done

popd
