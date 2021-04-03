#!/bin/bash

set -e

CMAKE_VERSION=$1
if [[ -z "${CMAKE_VERSION}" ]] ; then
    echo "The CMake version must be specified as a command-line argument"
    exit 1
fi

# Prefer to use this, downloads will likely be faster
#DOWNLOAD_BASE=https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}

# For testing direct downloads from Kitware, not recommended for normal use
CMAKE_FEATURE_RELEASE=`echo ${CMAKE_VERSION} | cut -d. -f1-2`
DOWNLOAD_BASE=https://cmake.org/files/v${CMAKE_FEATURE_RELEASE}

# Adjust as needed for your use case. The URL of the file to be downloaded
# will be appended to this. It is expected that a file with the same name
# as the filename at the end of that URL will be created in the current
# directory.
doDownload="curl -LO --max-time 300 --silent --show-error"


#======================================================================
# Put all our downloaded/generated files in the output directory so we
# don't pollute the working dir we were called from.
#======================================================================
scriptDir=$( cd `dirname $0` ; pwd )
outputDir=${scriptDir}/${2:-cmake-${CMAKE_VERSION}}
mkdir -p ${outputDir}
cd ${outputDir}


#======================================================================
# Allow a set of trusted public keys to be used instead of requiring
# the default keyring to already have the required keys.
# The public keys are expected to be ASCII-armored public key files.
# A link is provided on the GitHub releases page for each release, and
# on the CMake download page for the current release.
# Look for the following line on either page:
#
#   PGP sig by ...
#
# where ... will be a link to a keyserver providing the public key.
#======================================================================
keyringOpts="--batch"
if [[ -d "${scriptDir}/trusted_pubkeys" ]] ; then
    trustedPubKeyDir=${scriptDir}/trusted_pubkeys
    pubkeys=`ls ${trustedPubKeyDir}/*.asc`
    if [[ -n "${pubkeys}" ]] ; then
        keyringFile="${outputDir}/trusted_pubkeys_keyring.gpg"
        echo "Creating local keyring ${keyringFile} for trusted keys in ${trustedPubKeyDir}"
        gpg ${keyringOpts} --trust-model always \
            --import-options import-export \
            --import ${trustedPubKeyDir}/*.asc > ${keyringFile}
        keyringOpts="${keyringOpts} --keyring ${keyringFile}"
    fi
fi


#======================================================================
# Download the JSON file that specifies the file names for each
# platform, architecture, etc.
#======================================================================
jsonFile=cmake-${CMAKE_VERSION}-files-v1.json
echo "Downloading JSON package descriptions file: ${jsonFile}"
${doDownload} ${DOWNLOAD_BASE}/${jsonFile}


#======================================================================
# Get hashes and verify that signatures can be trusted
#======================================================================
hashQuery=".hashFiles[] | select(.algorithm[] | . == \"SHA-256\")"
hashFilename=`jq -r "${hashQuery} | .name" ${jsonFile}`
msg=`jq -r "${hashQuery} | .deprecated" ${jsonFile}`
if [[ ! "${msg}" = null ]] ; then
    echo "WARNING: The CMake hash file provides the following deprecation message:"
    echo "${msg}"
fi
${doDownload} ${DOWNLOAD_BASE}/${hashFilename}

goodSigFile=""
for sigFile in $( jq -r "${hashQuery} | .signature | .[]" ${jsonFile}) ; do
    echo "Downloading and checking signature file: ${sigFile}"
    ${doDownload} ${DOWNLOAD_BASE}/${sigFile}
    if gpg ${keyringOpts} --verify ${sigFile} ${hashFilename} ; then
        goodSigFile=${sigFile}
        break
    fi
done
if [[ -z "${goodSigFile}" ]] ; then
    echo "Unable to verify hashes with provided signature(s)."
    echo "Check if a new public key is now being used."
    echo "This may require updating your project with new public key files."
    exit 1
fi


#======================================================================
# Download the appropriate package for this platform/architecture
#======================================================================
case "$(uname -s)" in
    Linux)
        OS="linux"
        shatool="sha256sum"
        ;;
    Darwin)
        OS="macOS"
        shatool="shasum -a 256"
        ;;
    *)
        echo "Unrecognized platform $(uname -s)"
        exit 1
        ;;
esac
ARCH=`uname -m`

pkgQuery=".files[] | select((.os[] | . == \"${OS}\") and (.architecture[] | . == \"${ARCH}\") and (.class == \"archive\"))"
pkgFilename=`jq -r "${pkgQuery} | .name" ${jsonFile}`
msg=`jq -r "${pkgQuery} | .deprecated" ${jsonFile}`
if [[ ! "${msg}" = null ]] ; then
    echo "WARNING: The CMake package provides the following deprecation message:"
    echo "${msg}"
fi
echo "Downloading package file: ${pkgFilename}"
${doDownload} ${DOWNLOAD_BASE}/${pkgFilename}


#======================================================================
# Verify the downloaded package
#======================================================================
echo "Verifying downloaded file"
grep ${pkgFilename} ${hashFilename} | ${shatool} --check


#======================================================================
# Package passed verification, unpack it
#======================================================================
echo "Extracting package to ${outputDir}"
tar zxf ${pkgFilename} --strip-components 1

case "${OS}" in
    macOS)
        # NOTE: macOS packages are distributed as an app bundle
        echo "Prepend the following to your PATH: ${outputDir}/CMake.app/Contents/bin"
        ;;
    *)
        echo "Prepend the following to your PATH: ${outputDir}/bin"
        ;;
esac
