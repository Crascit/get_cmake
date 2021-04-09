# Contributing

If you are interested in improving this repository, that's great!
To ensure a common understanding and to set expectations, please note the
following:

* Integration with any form of package manager is a non-goal.
  The scripts here are purely for downloading official packages from the
  official distribution channels.
  
* The dependencies needed for the scripts should be kept minimal.
  They will be used in containers, CI machines, etc. where minimizing downloads
  and complexity may be important.
  Note that this means a dependency on things like python or other similar
  languages or frameworks is therefore out of scope.
  
* The scripts should work on any reasonably mainstream distribution or system
  that has not reached its end-of-life.
  
* There may be ways to do things more efficiently than done in these scripts,
  but ease of understanding and maintainability are considered more important
  in most cases.
  Please keep this in mind if submitting any pull requests.

We do not require any formal copyright assignment or contributor license
agreement.
Any contributions are presumed to be offered under terms of the OSI-approved
BSD 3-clause License.
See LICENSE for details.
