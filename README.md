# get_cmake

The scripts in this repository are intended primarily for copying directly into
your own project and used as part of automated CI jobs.
They retrieve official release packages from an official location, verify
the downloaded files and unpack the release to a configurable directory.
They should not require any administrative privileges, as the official
packages are fully relocatable and can be run directly from the local output
directory created by the script.


## Incorporating Into Your Project

You should be able to embed or copy this whole repository to your own
project's source tree.
Only embed it as a git submodule if you can guarantee that the remote repo
isn't compromised (e.g. a mirror or fork on your local network, not the
canonical repo on GitHub).
Otherwise, make an actual copy and embed it directly in your repository.
Whichever approach is taken, you should preserve the directory structure,
but you are free to place it all under whatever directory you find convenient.

The scripts will automatically create a local keyring file and use that if
it finds any public keys in the `trusted_pubkeys` subdirectory relative to
the script's location.
You can tell the script to look in a different location for public key files
instead if needed.
Public key files may need to be updated occasionally when new public keys
are used.
If you want to rely on your default keychain instead, don't copy the
`trusted_pubkeys` subdirectory to your project or tell the script to look in
a non-existent directory.


## Using The Scripts

The scripts accept a command line argument specifying the CMake version you
want to download.
This should be the full version number, like `3.20.0`.
Release candidates can also be retrieved (e.g. `3.20.0-rc3`).
If no version is specified, the latest CMake release will be downloaded.
CI scripts should always ask for a specific CMake version for repeatability
and traceability reasons.
The script offers a few options for controlling things like the output
directory and verbosity.
See the output from running the script with the `--help` option for details.

In your CI job, you will need to add the relevant directory to your `PATH`
after the script has completed.
The directory is different for different platforms due to the different
package structure.
The following examples show how to run the script, setup the `PATH` and run
`cmake` to print the version:

```
# Linux with default output directory
./get_cmake.bash 3.20.0
export PATH=`pwd`/cmake-3.20.0/bin:${PATH}
cmake --version
```

```
# macOS with custom output directory and accounting for app bundle structure
./get_cmake.bash --output cmake 3.20.0
export PATH=`pwd`/cmake/CMake.app/Contents/bin:${PATH}
cmake --version
```


## Requirements

The scripts assume a few common tools are available.
The requirements vary a little between platforms, as specified below.

### Linux

* bash
* jq
* sha256sum
* gpg
* curl
* tar

### macOS

* bash
* jq
* shasum
* gpg
* curl
* tar

### Windows

TBA
