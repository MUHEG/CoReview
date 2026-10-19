# Split AI extraction/QA output into per-reviewer batch folders.

Reads the AI pipeline's two .xlsx deliverables (extraction + QA) and the
source PDFs, and writes one self-contained batch folder per reviewer,
ready to hand off (see
[`run_app`](https://MUHEG.github.io/CoReview/reference/run_app.md)).

## Usage

``` r
split_for_review(
  extraction,
  qa,
  papers_dir,
  out,
  manifest = NULL,
  n_batches = 6
)
```

## Arguments

- extraction:

  Path to the extraction .xlsx (paper_id, pipeline, one column per
  extraction field, Flags).

- qa:

  Path to the QA .xlsx (paper, pipeline, subitem, verdict, evidence).

- papers_dir:

  Folder containing the source PDFs.

- out:

  Destination folder for the batch_N/ subfolders. No default on purpose
  – this data may live nowhere near wherever this package is installed,
  so the destination is always explicit.

- manifest:

  Optional path to a manifest.json mapping `paper_id -> pdf_file` (and,
  optionally, `doi`) for when PDF filenames don't reliably match
  paper_id. Without it, assumes `"<paper_id>.pdf"` under `papers_dir`,
  and every paper's DOI is left blank.

- n_batches:

  Number of reviewer batches to split into (even split, no overlap).
  Default 6.

## Value

Invisible; called for its side effect of writing batch_N/ folders under
`out`. Prints a per-batch and total summary.
