# wiki for internal and external documentation

The wiki is built with [mdbook](https://rust-lang.github.io/mdBook/).  

The requirement is for an internal wiki and an external wiki, where items can be selectively included in the external wiki.  To accomplish this, we use a feature of mdbook, where it will only include files listed in `SUMMARY.md` in the build.  A script `build.sh` copies files to different directories so that mdbook will build appropriately for the internal and external docs.  


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


## deploying

The wikis are deployed to AWS with [terraform](https://developer.hashicorp.com/terraform/intro).  To deploy:

1. Export your MistyHatchWiki AWS account access key, secret access key, and session token to the terminal. (copy the values from the AWS single sign on page)
2. Execute the following commands:

```
bash build.sh int
bash build.sh ext
terraform init
terraform apply
```


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
├── main.tf
└── README.md
```

The `ext` folder specifies external documentation and the `int` folder specifies the internal documentation.  Each of these two folders has a `book.toml` and a `SUMMARY.md`.  The `book.toml` specifies info like the title, authors and build output directory.  The `SUMMARY.md` is the table of contents.  Only files referenced in `SUMMARY.md` will be included in the build output, so this is where to specify which files are shared externally.

The markdown content (for both internal and external) is in `src`.

The build output folders are `_ext_out` and `_int_out`.

The files `/book.toml` and `/src/SUMMARY.md`.  are temporary files created as precursors to the build process (they are copied from the `int` or `ext` folder).  They will be over-written.

`main.tf` is the [terraform](https://developer.hashicorp.com/terraform/intro) code that deploys the internal and external wikis to AWS.


## cloud architecture

**external wiki resources**

- s3
- cloudfront

The external wiki is an s3 bucked hosted as a website on cloudfront.

**internal wiki resources**

- s3
- lambda
- cloudfront

The internal wiki is the same, except there is also a lambda authorizer that is associated with the cloudfront distribution viewer-request event. 

The authorizer is a middleware that acts as a gatekeeper to the internal wiki.  It stores a hardcoded username and password.  When a request is made, the authorizer checks if the un and pw are provided in a Basic authentication header.  If they are correct, it passes on the request.  If they are not present or correct, then in sets a response with status code 401 (unauthorized) and a www-authenticate header requesting Basic authentication.  Web browsers support this response type by creating a popup window requesting the user to enter a username and password.  After these credentials are entered, the browser re-tries the request, with the entered credentials included in a basic authentication header.

This authentication architecture is described in [this blog post](https://douglasduhaime.com/posts/s3-lambda-auth.html).


