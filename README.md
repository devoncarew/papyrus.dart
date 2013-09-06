papyrus.dart
============

[![Build Status](https://drone.io/github.com/devoncarew/papyrus.dart/status.png)](https://drone.io/github.com/devoncarew/papyrus.dart/latest)

### Description

A Dart documentation generator

### Design Goals

- beautiful typography
- generate very few files - no cruft on the file system
- generate small files
- generate simple, clean html

### Sample Output

View the documentation for the Dart SDK libraries [here](http://devoncarew.github.io/papyrus.dart/).

### Download and Run

Download a Dart snapshot of the command-line tool [here](https://drone.io/github.com/devoncarew/papyrus.dart/files/dist/papyrus.snap).

The tool can then be invoked like a normal Dart script (`dart papyrus.snap`). Usage:

    usage: dart papyrus <options> path/to/library1 path/to/library2

    where <options> is one or more of:
        --exclude    a comma-separated list of library names to ignore
    -h, --help       show command help
        --include    a comma-separated list of library names to include
        --out        the output directory
                     (defaults to "out")
