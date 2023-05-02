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
git checkout 818fe273c124223ce651e3ba5d439de9a9550cd7
git apply ../appimage.patch

# Create a container with the image
id=$(docker create quay.io/pypa/manylinux2010_x86_64)

for tag in "cp39-cp39"
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
docker cp $id:/opt/python/cp39-cp39/lib/libpython3.9.so.1.0 cp39-cp39/usr/lib/

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
