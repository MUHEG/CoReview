
<!-- README.md is generated from README.Rmd. Please edit that file -->

# `{CoReview}`

<!-- badges: start -->

[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.23490201.svg)](https://doi.org/10.5281/zenodo.23490201)

<!-- badges: end -->

A Shiny app for human reviewers checking and correcting AI-generated
data extraction and Drummond quality-appraisal results against the
original source PDFs, as part of an AI-assisted literature review of
health economic evaluation studies. The source PDF and the AI’s
extracted data sit side by side, so every field and QA verdict can be
checked and corrected at a glance.

(An AI pipeline’s extraction/QA spreadsheets are split into per-reviewer
batches with `split_for_review()` before reviewing starts, and combined
back into the final verified deliverables with `combine_reviewed()` once
it’s done – see `vignette("CoReview")` for details.)

## Installation

You can install the development version of `{CoReview}` like so:

``` r
# (Only necessary if the remotes package is not installed).
utils::install.packages("remotes")
```

``` r
remotes::install_github("MUHEG/CoReview")
```

## Run

Launch the app with a folder picker, so a reviewer can load any batch
folder themselves:

``` r
CoReview::run_app()
```

Or point it straight at a batch, optionally pre-filling the reviewer
name:

``` r
CoReview::run_app(batch_dir = "review_batches/batch_1", reviewer = "Jane Doe")
```

## Status

This library is experimental and under active development as part of an
ongoing systematic review project. It is not currently recommended for
use beyond members of the development team.

## About

You are reading the doc about version : 0.0.0.9000

This README has been compiled on the

``` r
Sys.time()
#> [1] "2026-10-20 16:20:51 AEDT"
```

Here are the tests results and package coverage:

``` r
devtools::check(quiet = TRUE)
#> ℹ Loading CoReview
#> ── R CMD check results ──────────────────────────────── CoReview 0.0.0.9000 ────
#> Duration: 1m 46.2s
#> 
#> ❯ checking for future file timestamps ... NOTE
#>   unable to verify current time
#> 
#> ❯ checking top-level files ... NOTE
#>   Non-standard file/directory found at top level:
#>     'Citation.cff'
#> 
#> 0 errors ✔ | 0 warnings ✔ | 2 notes ✖
```

``` r
covr::package_coverage()
#> CoReview Coverage: 81.34%
#> R/run_app.R: 0.00%
#> R/mod_coreview_main.R: 54.55%
#> R/combine_reviewed.R: 94.74%
#> R/combine_logic.R: 95.24%
#> R/split_for_review.R: 98.82%
#> R/app_config.R: 100.00%
#> R/app_server.R: 100.00%
#> R/app_ui.R: 100.00%
#> R/extraction_definitions.R: 100.00%
#> R/golem_utils_server.R: 100.00%
#> R/golem_utils_ui.R: 100.00%
#> R/qa_definitions.R: 100.00%
#> R/review_io.R: 100.00%
```
