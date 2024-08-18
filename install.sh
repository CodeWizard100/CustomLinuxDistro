#!/bin/sh

# Example installation script
set -e

# Build the image
aports/scripts/mkimage.sh --tag edge \
  --outdir ~/iso \
  --arch x86_64 \
  --repository https://dl-cdn.alpinelinux.org/alpine/edge/main \
  --profile standard

# Sign the image
gpg --detach-sign --armor ~/iso/your-image.iso
