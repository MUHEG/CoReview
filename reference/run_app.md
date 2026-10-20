# Run the Shiny Application

Run the Shiny Application

## Usage

``` r
run_app(
  onStart = NULL,
  options = list(),
  enableBookmarking = NULL,
  uiPattern = "/",
  ...
)
```

## Arguments

- onStart:

  A function that will be called before the app is actually run. This is
  only needed for `shinyAppObj`, since in the `shinyAppDir` case, a
  `global.R` file can be used for this purpose.

- options:

  Named options that should be passed to the `runApp` call (these can be
  any of the following: "port", "launch.browser", "host", "quiet",
  "display.mode" and "test.mode"). You can also specify `width` and
  `height` parameters which provide a hint to the embedding environment
  about the ideal height/width for the app.

- enableBookmarking:

  Can be one of `"url"`, `"server"`, or `"disable"`. The default value,
  `NULL`, will respect the setting from any previous calls to
  [`enableBookmarking()`](https://rdrr.io/pkg/shiny/man/enableBookmarking.html).
  See
  [`enableBookmarking()`](https://rdrr.io/pkg/shiny/man/enableBookmarking.html)
  for more information on bookmarking your app.

- uiPattern:

  A regular expression that will be applied to each `GET` request to
  determine whether the `ui` should be used to handle the request. Note
  that the entire request path must match the regular expression in
  order for the match to be considered successful.

- ...:

  Arguments passed to golem_opts, retrieved inside the app via
  \`golem::get_golem_options()\`. Two are recognised:

  \`batch_dir\`

  :   Path to a \`batch_N/\` folder (as written by
      [`split_for_review`](https://MUHEG.github.io/CoReview/reference/split_for_review.md))
      to open immediately. Without it, the app opens with a folder
      picker instead.

  \`reviewer\`

  :   Reviewer name to pre-fill on save. Without it, the reviewer types
      their own name in the app.

  See \`?golem::get_golem_options\` for more details.

## Examples

``` r
if (FALSE) { # \dontrun{
run_app()
run_app(batch_dir = "review_batches/batch_1", reviewer = "Jane Doe")
} # }
```
