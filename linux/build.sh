#!/bin/bash
set -eux

# Login to the registry
printenv GITHUB_TOKEN | docker login docker.pkg.github.com -u "$GITHUB_ACTOR" --password-stdin

# Pull our custom manylinux image and use it in place of the official one
TARGET_IMAGE="docker.pkg.github.com/vivekpanyam/manylinux-shared/manylinux-shared:latest"
docker pull "$TARGET_IMAGE"
docker tag "$TARGET_IMAGE" "quay.io/pypa/manylinux2010_x86_64"

# Get the appimage repo
git clone https://github.com/niess/python-appimage.git
pushd python-appimage
git checkout 3f6ed9e6b2b2d4d5b78dda3a4fe9db7324f788a7
git apply ../appimage.patch

# Create a container with the image
id=$(docker create quay.io/pypa/manylinux2010_x86_64)

for tag in "cp27-cp27m" "cp27-cp27mu" "cp35-cp35m" "cp36-cp36m" "cp37-cp37m" "cp38-cp38"
do
    python -m python_appimage build manylinux \
        2010_x86_64 \
        $tag

    mv *.AppImage current.AppImage
    ./current.AppImage --appimage-extract
    rm current.AppImage
    mv "squashfs-root" "$tag"

    # Copy in libcrypt.so.2
    docker cp -L $id:/usr/local/lib/libcrypt.so.2 "$tag/usr/lib/"
done

# Copy in libpython
# TODO: clean this up
docker cp $id:/opt/python/cp27-cp27m/lib/libpython2.7.so.1.0 cp27-cp27m/usr/lib/
docker cp $id:/opt/python/cp27-cp27mu/lib/libpython2.7.so.1.0 cp27-cp27mu/usr/lib/
docker cp $id:/opt/python/cp35-cp35m/lib/libpython3.5m.so.1.0 cp35-cp35m/usr/lib/
docker cp $id:/opt/python/cp36-cp36m/lib/libpython3.6m.so.1.0 cp36-cp36m/usr/lib/
docker cp $id:/opt/python/cp37-cp37m/lib/libpython3.7m.so.1.0 cp37-cp37m/usr/lib/
docker cp $id:/opt/python/cp38-cp38/lib/libpython3.8.so.1.0 cp38-cp38/usr/lib/

# Fix rpaths
find . -name "libpython*.so.1.0" | xargs -L 1 sudo patchelf --set-rpath '$ORIGIN'

# Create tar files
for d in cp*
do
    pushd $d
    tar -cvzf "../linux_$d.tar.gz" *
    popd
done

popd
