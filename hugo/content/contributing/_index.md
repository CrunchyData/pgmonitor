---
title: "Contributing"
draft: false
weight: 4
---

## Getting Started

Welcome! Thank you for your interest in contributing. Before submitting a new [issue](https://github.com/CrunchyData/pgmonitor/issues/new)
or [pull request](https://github.com/CrunchyData/pgmonitor/pulls) to the [pgmonitor](https://github.com/CrunchyData/pgmonitor/) project on GitHub,
*please review any open or closed issues* [here](https://github.com/crunchydata/pgmonitor/issues) in addition to any existing open pull requests.

## Documentation

The [documentation website](https://crunchydata.github.io/pgmonitor/) is generated using [Hugo](https://gohugo.io/) and
[GitHub Pages](https://pages.github.com/).

## Hosting Hugo Locally (Optional)

If you would like to build the documentation locally, view the
[official Installing Hugo](https://gohugo.io/getting-started/installing/) guide to set up Hugo locally. You can then start the server by
running the following commands -

```sh
cd $CCPROOT/hugo/
vi config.toml
hugo server
```

The local version of the Hugo server is accessible by default from
`localhost:1313`. Once you've run `hugo server`, that will let you interactively make changes to the documentation as desired and view the updates
in real-time.


## Contributing to the Documentation

When you're ready to commit a change, please view and run the script located in the root folder labeled `generate-docs.sh` which will automatically generate a new
set of webpages using Hugo that will update the live website after the change has been committed to the repository.
