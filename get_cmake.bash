#!/bin/bash

set -e

show_help()
{
    echo "Usage: $0 [options] [version]"
    echo ""
    echo "Download and unpack an official CMake release for this platform"
    echo "and architecture. If 'version' is given, it must be a release"
    echo "number in the form X.Y.Z or X.Y.Z-rcN, or it can be the special"
    echo "value 'latest'. If 'version' is omitted, 'latest' will be assumed."
    echo ""
    echo "Do not use 'latest' in scripts where the build needs to be"
    echo "repeatable or traceable. Always prefer to explicitly specify a"
    echo "version number. The use of 'latest' is intended only as a"
    echo "convenience for developers to use locally."
    echo ""
    echo "Supported options are the following:"
    echo ""
    echo "  -h"
    echo "  --help"
    echo "    Show this usage message and exit."
    echo ""
    echo "  --verbose"
    echo "    Log extra information about what the script is doing."
    echo "    Errors and warnings will always be logged regardless of whether"
    echo "    or not this option is given."
    echo ""
    echo "  --progress"
    echo "    Enable logging of progress output during download (default: off)."
    echo "    This option is independent of --verbose."
    echo ""
    echo "  -f repo"
    echo "  --from repo"
    echo "    Specifies where to download the release from. Supported values"
    echo "    for repo are 'github' or 'kitware'. If this option is not given,"
    echo "    the default is 'github', which is the recommended repo for the"
    echo "    best download performance. The value 'kitware' downloads directly"
    echo "    from cmake.org instead and is intended only for testing purposes."
    echo ""
    echo "  -o dir"
    echo "  --output dir"
    echo "    The name of the output directory where the release will be"
    echo "    downloaded and unpacked to. It will be created automatically"
    echo "    if required. The output directory will also contain other files"
    echo "    downloaded or created as part of the download process."
    echo "    If this option is not given, it will default to cmake-\${version}"
    echo "    relative to the current working directory."
    echo ""
    echo "  -t dir"
    echo "  --trusted-pubkey-dir dir"
    echo "    Optional directory containing public key files. File names are"
    echo "    assumed to end in .asc and the file contents are assumed to be"
    echo "    in ascii-armored form. If this option is not given, the script"
    echo "    will look in a directory called trusted_pubkeys below the"
    echo "    directory holding this script. It is not an error if the"
    echo "    directory does not exist."
    echo ""
}

log_msg()
{
    if [[ "${verbose}" == yes ]] ; then
        echo "$1"
    fi
}

curl_download()
{
    curl -L --max-time 300 ${curlSilentOpt} --show-error "$@"
}

verbose=no
scriptDir=$( cd `dirname $0` ; pwd )
outputDir=
repo=github
trustedPubKeyDir=${scriptDir}/trusted_pubkeys
curlSilentOpt="--silent"

while :; do
    case $1 in
        -h|--help)
            show_help
            exit
            ;;
        --verbose)
            verbose=yes
            ;;
        --progress)
            curlSilentOpt=
            ;;
        -f|--from)
            case $2 in
                github)
                    repo=github
                    ;;
                kitware)
                    repo=kitware
                    ;;
                *)
                    echo "ERROR: Unsupported file repo: $1 $2"
                    exit 1
            esac
            shift
            ;;
        -o|--output)
            outputDir=$2
            shift
            ;;
        -t|--trusted-pubkey-dir)
            trustedPubKeyDir=$2
            shift
            ;;
        -*)
            echo "ERROR: Unknown option: $1"
            exit 1
            ;;
        *)
            # Optional CMake version after all "-" options
            break
    esac

    shift
done

if [[ $# -gt 1 ]] ; then
    echo "ERROR: Too many command line arguments"
    echo ""
    show_help
    exit 1
fi

CMAKE_VERSION=${1:-latest}


#======================================================================
# Put all our downloaded/generated files in the output directory so we
# don't pollute the working dir we were called from.
#======================================================================
outputDir=${outputDir:-$( pwd )/cmake-${CMAKE_VERSION}}
log_msg "Using output directory ${outputDir}"
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
if [[ "${verbose}" == no ]] ; then
    keyringOpts="${keyringOpts} --quiet"
fi
if [[ -d "${trustedPubKeyDir}" ]] ; then
    pubkeys=`ls ${trustedPubKeyDir}/*.asc`
    if [[ -n "${pubkeys}" ]] ; then
        keyringFile="${outputDir}/trusted_pubkeys_keyring.gpg"
        log_msg "Creating local keyring ${keyringFile} for trusted keys in ${trustedPubKeyDir}"
        [[ -e "${keyringFile}" ]] && rm ${keyringFile}
       	touch ${keyringFile}
        gpg ${keyringOpts} \
            --trust-model always \
            --no-auto-check-trustdb \
            --primary-keyring ${keyringFile} \
            --import ${trustedPubKeyDir}/*.asc
        keyringOpts="${keyringOpts} --keyring ${keyringFile}"
    fi
fi


#======================================================================
# Download the JSON file that specifies the file names for each
# platform, architecture, etc.
#======================================================================
if [[ "${CMAKE_VERSION}" == latest ]] ; then
    case ${repo} in
        github)
            log_msg "Getting latest release from GitHub"
            # GitHub's concept of "latest" is time-based, not version-based.
            # That makes it unsuitable for our needs. We have to use its API to
            # get the list of releases and work out the latest for ourselves.
            # Sorting needs to account for an optional -rcN suffix, but the
            # sort -V command would consider those to be later than the same
            # release without the suffix. We need the opposite of that, so we
            # append an underscore for sorting and then strip it off again to
            # get the ordering we need.
            curl_download \
                 -o releases.json \
                 -H "Accept: application/vnd.github.v3+json" \
                 https://api.github.com/repos/Kitware/CMake/releases
            CMAKE_VERSION=`jq -r '.[] | select(.draft | not) | (.tag_name + "_") | .[1:]' releases.json | sort -V | sed 's/_$//g' | tail -1`
            log_msg "Latest release found to be ${CMAKE_VERSION}"
            DOWNLOAD_BASE=https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}
            ;;
        kitware)
            log_msg "Getting latest release from cmake.org"
            DOWNLOAD_BASE=https://cmake.org/files/LatestRelease
            ;;
        *)
            echo "Unexpected repo source: ${repo}"
            exit 1
    esac
else
    if ! [[ "${CMAKE_VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-rc[0-9]+)?$ ]] ; then
        echo "Invalid CMake version specified: ${CMAKE_VERSION}"
        echo "Expected a version number in the form X.Y.Z or X.Y.Z-rcN"
        exit 1
    fi

    case ${repo} in
        github)
            log_msg "Getting CMake ${CMAKE_VERSION} from GitHub"
            DOWNLOAD_BASE=https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}
            ;;
        kitware)
            log_msg "Getting CMake ${CMAKE_VERSION} from cmake.org"
            CMAKE_FEATURE_RELEASE=`echo ${CMAKE_VERSION} | cut -d. -f1-2`
            DOWNLOAD_BASE=https://cmake.org/files/v${CMAKE_FEATURE_RELEASE}
            ;;
        *)
            echo "Unexpected repo source: ${repo}"
            exit 1
    esac
fi
jsonFile=cmake-${CMAKE_VERSION}-files-v1.json
log_msg "Downloading JSON package descriptions file: ${jsonFile}"
curl_download -O ${DOWNLOAD_BASE}/${jsonFile}
if jq . ${jsonFile} >/dev/null 2>&1 ; then
    log_msg "Package descriptions file is valid JSON"
else
    echo "Package descriptions file does not appear to be valid JSON."
    echo "Obtained from URL:  ${DOWNLOAD_BASE}/${jsonFile}"
    echo "End of the downloaded file follows:"
    cat ${jsonFile} | tail -13
    exit 1
fi


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
curl_download -O ${DOWNLOAD_BASE}/${hashFilename}

goodSigFile=""
for sigFile in $( jq -r "${hashQuery} | .signature | .[]" ${jsonFile}) ; do
    log_msg "Downloading and checking signature file: ${sigFile}"
    curl_download -O ${DOWNLOAD_BASE}/${sigFile}
    if [[ "${verbose}" == no ]] ; then
        # --verify-options doesn't allow us to prevent all output, so dump it
        if gpg ${keyringOpts} --verify ${sigFile} ${hashFilename} > /dev/null 2>&1 ; then
            goodSigFile=${sigFile}
            break
        fi
    else
        # This will print various details about the key used
        if gpg ${keyringOpts} --verify ${sigFile} ${hashFilename} ; then
            goodSigFile=${sigFile}
            break
        fi
    fi
done
if [[ -z "${goodSigFile}" ]] ; then
    echo "Unable to verify hashes with provided signature(s)."
    echo "Check if a new public key is now being used."
    echo "This may require updating your project with new public key files"
    echo "or adding the missing key to your default keyring."
    exit 1
fi


#======================================================================
# Download and verify the appropriate package for this
# platform/architecture
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

# If we've already got a package file with the expected name, check if it
# matches the checksum and skip the download if we can confirm we already
# have the right file.
haveFile=no
if [[ -e "${pkgFilename}" ]] ; then
    grep ${pkgFilename} ${hashFilename} | ${shatool} --check --status && haveFile=yes
fi
if [[ ${haveFile} == yes ]] ; then
    log_msg "Existing package file matches checksum, skipping download and re-using it"
else
    log_msg "Downloading package file: ${pkgFilename}"
    curl_download -O ${DOWNLOAD_BASE}/${pkgFilename}

    log_msg "Verifying downloaded file"
    statusOpt=
    if [[ "${verbose}" == no ]] ; then
        statusOpt="--status"
    fi
    if ! grep ${pkgFilename} ${hashFilename} | ${shatool} --check ${statusOpt} ; then
        echo "Package file failed verification check: ${pkgFilename}"
        exit 1
    fi
fi


#======================================================================
# Package downloaded and verified, unpack it
#======================================================================
log_msg "Extracting package to ${outputDir}"
tar zxf ${pkgFilename} --strip-components 1

case "${OS}" in
    macOS)
        # NOTE: macOS packages are distributed as an app bundle
        log_msg "Prepend the following to your PATH: ${outputDir}/CMake.app/Contents/bin"
        ;;
    *)
        log_msg "Prepend the following to your PATH: ${outputDir}/bin"
        ;;
esac
