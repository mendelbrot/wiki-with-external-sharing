# the MH11 docs repo

This repo uses [mdbook](https://rust-lang.github.io/mdBook/) to build the wiki.  

Our requirement is to have an internal wiki and an external wiki, where items can be selectively included in the external wiki.  To accomplish, we use the feature of mdbook, where it will only include files that are in the table of contents, and a script `build.sh` that copies files so that it will build appropriately for the internal and external docs.  

## directory structure

For internal documentation, the table of contents to edit and determine what to include is `intenral-contents/SUMMARY.md`, and the output build is in `internal-docs`.

For external documentation, the table of contents to edit and determine what to include is `external-contents/SUMMARY.md`, and the output build is in `external-docs`.

The the markdown content (for both internal and external) is in `src`.

To build the internal docs, run `bash build.sh in`, and for the internal docs, run `bash build.sh ex`.