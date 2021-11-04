# About

CARI Builder is a Bash script used to build the [CARI wallet](https://github.com/Carbon-Reduction-Initiative/CARI) (CLI, daemon and GUI) for several operating systems using cross compilation on Ubuntu 20.04.

Binaries generated during the process can be tested (using virtualization if needed) to ensure they run corrrectly. If binaries passed all tests, ZIP archives containing CLI, daemon and/or GUI binaries are created.

The build process can be tweaked using ten or so arguments. Run the script with the argument "-h" for usage details.