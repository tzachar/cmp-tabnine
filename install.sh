#!/usr/bin/env bash

# Based on https://github.com/codota/TabNine/blob/master/dl_binaries.sh
# Download latest TabNine binaries
set -o errexit
set -o pipefail
set -x

# get the absolute path where the script resides. we want to install the
# binaries there
ABSOLUTE_PATH="$(\cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
DIRNAME=$(dirname $ABSOLUTE_PATH)

echo $ABSOLUTE_PATH
echo $DIRNAME

version=${version:-$(curl -sS https://update.tabnine.com/bundles/version)}

case $(uname -s) in
"Darwin")
    platform="apple-darwin"
    ;;
"Linux")
    platform="unknown-linux-musl"
    ;;
esac
triple="$(uname -m)-$platform"

# we want the binary to reside inside our plugin's dir
cd $(dirname $0)
path=$version/$triple

curl https://update.tabnine.com/bundles/${path}/TabNine.zip \
	--create-dirs \
	-o ${DIRNAME}/binaries/${path}/TabNine.zip
unzip -o ${DIRNAME}/binaries/${path}/TabNine.zip -d ${DIRNAME}/binaries/${path}
rm -rf ${DIRNAME}/binaries/${path}/TabNine.zip
chmod +x ${DIRNAME}/binaries/${path}/*

target=${DIRNAME}/"binaries/TabNine_$(uname -s)"
rm ${target} || true # remove old link
ln -sf ${DIRNAME}/binaries/${path}/TabNine $target
