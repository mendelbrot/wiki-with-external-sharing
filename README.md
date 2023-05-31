# wiki for internal and external documentation

The wiki is built with [mdbook](https://rust-lang.github.io/mdBook/).  

The requirement is for an internal wiki and an external wiki, where items can be selectively included in the external wiki.  To accomplish this, we use a feature of mdbook, where it will only include files listed in `SUMMARY.md` in the build.  A script `build.sh` copies files to different directories so that mdbook will build appropriately for the internal and external docs.  


## directory structure

```
├── _ext_out
│   └── ...
├── _int_out
│   └── ...
├── ext
│   ├── book.toml 
│   └── SUMMARY.md
├── int
│   ├── book.toml 
│   └── SUMMARY.md
├── src
│   ├── ...
│   └── SUMMARY.md
├── .gitignore
├── book.toml 
├── build.sh
└── README.md
```

The `ext` folder specifies external documentation and the `int` folder specifies the internal documentation.  Each of these two folders has a `book.toml` and a `SUMMARY.md`.  The `book.toml` specifies info like the title, authors and build output directory.  The `SUMMARY.md` is the table of contents.  Only files referenced in `SUMMARY.md` will be included in the build output, so this is where to specify which files are shared externally.

The markdown content (for both internal and external) is in `src`.

The build output folders are `_ext_out` and `_int_out`.

The files `/book.toml` and `/src/SUMMARY.md`.  are temporary files created as precursors to the build process (they are copied from the `int` or `ext` folder).  They will be over-written.


## building and viewing the wiki

To build and view the internal docs, run:
```
bash build.sh int
mdbook serve -o
```

Likewise, to build and view the external docs, run:
```
bash build.sh ext
mdbook serve -o
```
