# Shared review-record I/O and helper functions.

`%||%` <- function(a, b) if (is.null(a)) b else a


list_paper_ids <- function(batch_dir) {
  files <- list.files(file.path(batch_dir, "input", "to_review"), pattern = "\\.json$")
  sort(sub("\\.json$", "", files))
}

# A folder is a usable batch if it has both of these -- the only thing
# do_load() and the CLI tools require.
is_batch_dir <- function(path) {
  dir.exists(file.path(path, "input", "papers")) && dir.exists(file.path(path, "input", "to_review"))
}

completed_path_for <- function(batch_dir, paper_id) file.path(batch_dir, "output", "completed", paste0(paper_id, ".json"))

to_review_path_for <- function(batch_dir, paper_id) file.path(batch_dir, "input", "to_review", paste0(paper_id, ".json"))

# 3-state: "pending" (never saved), "partial" (one of extraction/QA saved),
# "completed" (both saved). Back-compat: a completed/ file predating
# per-section tracking only ever existed once both were saved together, so
# a missing status field there defaults to "done", not "pending".
paper_status <- function(batch_dir, paper_id) {
  cp <- completed_path_for(batch_dir, paper_id)
  if (!file.exists(cp)) return("pending")
  rec <- jsonlite::fromJSON(
    # src,
    cp,
    simplifyVector = FALSE
  )
  derive_status(rec$extraction_status %||% "done", rec$qa_status %||% "done")
}

load_record <- function(batch_dir, paper_id) {
  cp <- completed_path_for(batch_dir, paper_id)
  src <- if (file.exists(cp)) cp else to_review_path_for(batch_dir, paper_id)
  rec <- jsonlite::fromJSON(src, simplifyVector = FALSE)
  rec$extraction_status <- rec$extraction_status %||% "pending"
  rec$qa_status <- rec$qa_status %||% "pending"
  rec$status <- derive_status(rec$extraction_status, rec$qa_status)
  rec
}

save_record <- function(batch_dir, record) {
  out_path <- completed_path_for(batch_dir, record$paper_id)
  dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(record, out_path, auto_unbox = TRUE, null = "null", pretty = TRUE)
}

current_value <- function(field) if (!is.null(field$reviewed) && !identical(field$reviewed, "")) field$reviewed else field$ai

current_qa_verdict <- function(item) if (!is.null(item$reviewed_verdict) && !identical(item$reviewed_verdict, "")) item$reviewed_verdict else item$ai_verdict


