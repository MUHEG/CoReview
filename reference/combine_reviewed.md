# Combine reviewed batches into the final verified deliverables.

Walks every `batch_*/` folder under `review_dir`, merges each paper's AI
baseline with the reviewer's saved edits (falling back to the AI's own
values for anything not yet touched), and writes the two final
workbooks. Every cell a reviewer changed is filled red.

## Usage

``` r
combine_reviewed(
  review_dir,
  out,
  extraction_out = "final_extraction_verified.xlsx",
  qa_out = "qa_33items_verified.xlsx",
  timestamp = FALSE
)
```

## Arguments

- review_dir:

  Either the parent folder holding all `batch_N/` folders (the normal,
  whole-corpus combine), or a single `batch_N/` folder directly (to
  combine just one batch – this is also what
  [`run_app`](https://MUHEG.github.io/CoReview/reference/run_app.md)'s
  in-app "Export batch output" button does, always timestamped).

- out:

  Destination folder for the two output files. No default on purpose –
  see
  [`split_for_review`](https://MUHEG.github.io/CoReview/reference/split_for_review.md)'s
  `out` parameter for why.

- extraction_out, qa_out:

  Output filenames (written under `out`).

- timestamp:

  If TRUE, inserts a timestamp before each filename's extension (e.g.
  `final_extraction_verified_2026-10-07_1432.xlsx`) instead of
  overwriting on every call. Default FALSE, since this is typically run
  once, deliberately, as the final combine – not repeatedly while
  reviewing is still in progress (unlike the app's own export button,
  which always timestamps).

## Value

Invisible; called for its side effect of writing the two workbooks under
`out`. Prints a summary, including how many papers were never opened by
a reviewer (status "pending") or only half-reviewed (status "partial").
