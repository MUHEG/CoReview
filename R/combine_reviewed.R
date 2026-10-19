# Reassembles all reviewer batches' work into the two final, human-verified
# deliverables. All the actual row-building/red-highlighting logic lives in
# combine_logic.R, shared with run_app()'s in-app "Export batch
# output" button, so there's exactly one implementation, not two that could
# quietly drift apart.
#
# Walks every batch_*/to_review/*.json (the full paper list + AI baseline)
# and, where it exists, the matching batch_*/completed/*.json (the
# reviewer's edits). A paper never opened by its reviewer falls back
# entirely to its AI values, with status "pending" -- never silently blank.
#
# qa_33items_verified.xlsx is wide, one row per paper: one verdict column
# PLUS one evidence column per sub-item ("1.1", "1.1_evidence", ...,
# "10.6", "10.6_evidence"), 66 item columns in total. Evidence is the AI's
# own supporting quote, display-only in the app and never reviewer-edited
# -- kept alongside the verdict so a reader can see what it was based on
# without going back to the original, pre-review qa_33items.xlsx. Only the
# primary pipeline's verdict (the one a reviewer actually saw and could
# edit -- see split_for_review()'s docstring on qa_pipeline) fills those
# columns, so the "pipeline" column in this output is "claude" for every
# open-access paper and "qwen3" for every closed-access paper -- never
# anything else.

# Inserts _<timestamp> before the file extension, e.g.
# "final_extraction_verified.xlsx" -> "final_extraction_verified_2026-10-07_1432.xlsx".
add_timestamp <- function(filename, ts) sub("(\\.[^.]+)$", paste0("_", ts, "\\1"), filename)

#' Combine reviewed batches into the final verified deliverables.
#'
#' Walks every \code{batch_*/} folder under \code{review_dir}, merges each
#' paper's AI baseline with the reviewer's saved edits (falling back to the
#' AI's own values for anything not yet touched), and writes the two final
#' workbooks. Every cell a reviewer changed is filled red.
#'
#' @param review_dir Either the parent folder holding all \code{batch_N/}
#'   folders (the normal, whole-corpus combine), or a single
#'   \code{batch_N/} folder directly (to combine just one batch -- this is
#'   also what \code{\link{run_app}}'s in-app "Export batch output"
#'   button does, always timestamped).
#' @param out Destination folder for the two output files. No default on
#'   purpose -- see \code{\link{split_for_review}}'s \code{out} parameter
#'   for why.
#' @param extraction_out,qa_out Output filenames (written under \code{out}).
#' @param timestamp If TRUE, inserts a timestamp before each filename's
#'   extension (e.g. \code{final_extraction_verified_2026-10-07_1432.xlsx})
#'   instead of overwriting on every call. Default FALSE, since this is
#'   typically run once, deliberately, as the final combine -- not
#'   repeatedly while reviewing is still in progress (unlike the app's own
#'   export button, which always timestamps).
#' @return Invisible; called for its side effect of writing the two
#'   workbooks under \code{out}. Prints a summary, including how many
#'   papers were never opened by a reviewer (status "pending") or only
#'   half-reviewed (status "partial").
#' @export
combine_reviewed <- function(review_dir, out,
                             extraction_out = "final_extraction_verified.xlsx",
                             qa_out = "qa_33items_verified.xlsx",
                             timestamp = FALSE) {
  batch_dirs <- collect_batches(review_dir)
  dir.create(out, recursive = TRUE, showWarnings = FALSE)
  
  rows <- build_rows(batch_dirs)
  
  ex_name <- extraction_out; qa_name <- qa_out
  if (isTRUE(timestamp)) {
    ts <- export_timestamp()
    ex_name <- add_timestamp(ex_name, ts); qa_name <- add_timestamp(qa_name, ts)
  }
  
  out1 <- file.path(out, ex_name)
  openxlsx::saveWorkbook(build_extraction_workbook(rows$extraction_rows), out1, overwrite = TRUE)
  cat(sprintf("Wrote %s (%d rows)\n", out1, length(rows$extraction_rows)))
  
  out2 <- file.path(out, qa_name)
  openxlsx::saveWorkbook(build_qa_workbook(rows$qa_rows), out2, overwrite = TRUE)
  cat(sprintf("Wrote %s (%d rows)\n", out2, length(rows$qa_rows)))
  
  n_pending <- sum(vapply(rows$extraction_rows, function(r) identical(r$status, "pending"), logical(1)))
  n_partial <- sum(vapply(rows$extraction_rows, function(r) identical(r$status, "partial"), logical(1)))
  if (n_pending > 0) cat(sprintf("\n%d of %d paper(s) were never opened by a reviewer -- status 'pending', AI values only.\n", n_pending, length(rows$extraction_rows)))
  if (n_partial > 0) cat(sprintf("%d of %d paper(s) have only extraction OR QA done, not both -- status 'partial'.\n", n_partial, length(rows$extraction_rows)))
  invisible(NULL)
}