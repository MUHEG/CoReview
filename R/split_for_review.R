# Splits the AI pipeline's two .xlsx deliverables into one per-paper JSON
# review record each (extraction + QA bundled), and distributes those
# records into N reviewer batch folders (even split, no overlap -- MVP; see
# assign_batches() below for where a stratified/overlap scheme would slot
# in later without touching the rest of this file).
#
# Batch folder layout:
#   batch_N/
#     input/papers/<paper_id>.pdf        -- copied from papers_dir
#     input/to_review/<paper_id>.json    -- this function's output, read-only
#     output/completed/                  -- starts empty, reviewer writes here
#     output/exports/                    -- starts empty, exported .xlsx land here
#
# For each paper's QA sub-items, only ONE pipeline's verdict/evidence
# becomes the "ai" value a reviewer checks against the PDF (one
# verdict+evidence box per item, not one per pipeline). "claude" is
# preferred when present; closed-access papers only ever have "qwen3".
# pick_primary_qa_pipeline() also still recognizes "local_winner" (an
# older naming for this same local model, before it was aligned with
# extraction's "qwen3"), for compatibility with older-shaped input.
#
# EXTRACTION_FIELDS, QA_KEYS, and %||% come from combine_logic.R -- the
# same per-paper schema this package's "Export batch output" step and
# combine_reviewed() both read back out of these JSON records.

# ---- batch assignment (its own function so MVP's even split can be
# swapped later for stratified/overlap assignment without touching the
# rest of split_for_review()) ----

assign_batches <- function(paper_ids, n_batches) {
  if (n_batches <= 1) return(list(`1` = paper_ids))  # cut() rejects breaks = 1 ("invalid number of intervals")
  split(paper_ids, cut(seq_along(paper_ids), breaks = n_batches, labels = FALSE))
}

pick_primary_qa_pipeline <- function(pipelines_present) {
  if ("claude" %in% pipelines_present) return("claude")
  if ("qwen3" %in% pipelines_present) return("qwen3")
  if ("local_winner" %in% pipelines_present) return("local_winner")
  pipelines_present[[1]]
}

build_record <- function(paper_id, extraction_row, qa_rows, pdf_file, doi = "") {
  extraction <- setNames(
    lapply(EXTRACTION_FIELDS, function(f) {
      list(ai = as.character(extraction_row[[f]] %||% ""), reviewed = NULL)
    }),
    EXTRACTION_FIELDS
  )
  
  primary <- pick_primary_qa_pipeline(unique(qa_rows$pipeline))
  
  qa <- setNames(lapply(QA_KEYS, function(k) {
    row <- qa_rows[qa_rows$pipeline == primary & qa_rows$subitem == k, ]
    verdict <- if (nrow(row)) row$verdict[[1]] else "Unclear"
    evidence <- if (nrow(row)) row$evidence[[1]] else ""
    list(
      ai_verdict = as.character(verdict), ai_evidence = as.character(evidence),
      reviewed_verdict = NULL, reviewed_evidence = NULL
    )
  }), QA_KEYS)
  
  list(
    paper_id = paper_id,
    pdf_file = pdf_file,
    doi = as.character(doi %||% ""),
    extraction_pipeline = as.character(extraction_row$pipeline %||% ""),
    extraction_flags = as.character(extraction_row$Flags %||% ""),
    qa_pipeline = primary,
    extraction = extraction,
    qa = qa,
    reviewer = NULL,
    extraction_status = "pending",
    qa_status = "pending",
    status = "pending",
    flag_for_discussion = FALSE,
    note = ""
  )
}

#' Split AI extraction/QA output into per-reviewer batch folders.
#'
#' Reads the AI pipeline's two .xlsx deliverables (extraction + QA) and the
#' source PDFs, and writes one self-contained batch folder per reviewer,
#' ready to hand off (see \code{\link{run_review_app}}).
#'
#' @param extraction Path to the extraction .xlsx (paper_id, pipeline, one
#'   column per extraction field, Flags).
#' @param qa Path to the QA .xlsx (paper, pipeline, subitem, verdict, evidence).
#' @param papers_dir Folder containing the source PDFs.
#' @param out Destination folder for the batch_N/ subfolders. No default on
#'   purpose -- this data may live nowhere near wherever this package is
#'   installed, so the destination is always explicit.
#' @param manifest Optional path to a manifest.json mapping
#'   \code{paper_id -> pdf_file} (and, optionally, \code{doi}) for when PDF
#'   filenames don't reliably match paper_id. Without it, assumes
#'   \code{"<paper_id>.pdf"} under \code{papers_dir}, and every paper's DOI
#'   is left blank.
#' @param n_batches Number of reviewer batches to split into (even split,
#'   no overlap). Default 6.
#' @return Invisible; called for its side effect of writing batch_N/ folders
#'   under \code{out}. Prints a per-batch and total summary.
#' @export
split_for_review <- function(extraction, qa, papers_dir, out, manifest = NULL, n_batches = 6) {
  n_batches <- as.integer(n_batches)
  
  extraction_df <- as.data.frame(readxl::read_excel(extraction), stringsAsFactors = FALSE)
  qa_df <- as.data.frame(readxl::read_excel(qa), stringsAsFactors = FALSE)
  
  manifest_df <- NULL
  if (!is.null(manifest)) {
    manifest_df <- jsonlite::fromJSON(manifest, simplifyDataFrame = TRUE)
  }
  pdf_for <- function(paper_id) {
    if (!is.null(manifest_df)) {
      hit <- manifest_df[manifest_df$paper_id == paper_id, ]
      if (nrow(hit)) return(hit$pdf_file[[1]])
    }
    paste0(paper_id, ".pdf")
  }
  # "doi" is an optional column in manifest.json -- blank here whenever
  # it's missing, same fallback shape as pdf_for().
  doi_for <- function(paper_id) {
    if (!is.null(manifest_df) && "doi" %in% names(manifest_df)) {
      hit <- manifest_df[manifest_df$paper_id == paper_id, ]
      if (nrow(hit) && !is.na(hit$doi[[1]])) return(hit$doi[[1]])
    }
    ""
  }
  
  paper_ids <- extraction_df$paper_id
  batches <- assign_batches(paper_ids, n_batches)
  
  n_written <- 0
  for (b in seq_along(batches)) {
    # "batch_N" is a placeholder -- likely to become each reviewer's actual
    # name once that's decided; nothing else in the pipeline cares what the
    # folder is called.
    batch_dir <- file.path(out, paste0("batch_", b))
    to_review_dir <- file.path(batch_dir, "input", "to_review")
    papers_out_dir <- file.path(batch_dir, "input", "papers")
    dir.create(to_review_dir, recursive = TRUE, showWarnings = FALSE)
    dir.create(papers_out_dir, recursive = TRUE, showWarnings = FALSE)
    dir.create(file.path(batch_dir, "output", "completed"), recursive = TRUE, showWarnings = FALSE)
    dir.create(file.path(batch_dir, "output", "exports"), recursive = TRUE, showWarnings = FALSE)
    
    for (pid in batches[[b]]) {
      ex_row <- extraction_df[extraction_df$paper_id == pid, ][1, ]
      qa_rows <- qa_df[qa_df$paper == pid, ]
      pdf_name <- pdf_for(pid)
      
      record <- build_record(pid, ex_row, qa_rows, file.path("papers", pdf_name), doi = doi_for(pid))
      jsonlite::write_json(record, file.path(to_review_dir, paste0(pid, ".json")),
                           auto_unbox = TRUE, null = "null", pretty = TRUE)
      
      src_pdf <- file.path(papers_dir, pdf_name)
      if (file.exists(src_pdf)) {
        file.copy(src_pdf, file.path(papers_out_dir, pdf_name), overwrite = TRUE)
      } else {
        warning("PDF not found for ", pid, ": ", src_pdf, " -- copy it in manually before review.")
      }
      n_written <- n_written + 1
    }
    cli::cli_alert_success("batch_%d: %d paper(s) -> %s\n", b, length(batches[[b]]), to_review_dir)
  }
  cli::cli_alert_success("\nWrote %d review record(s) across %d batch(es) under %s\n", n_written, n_batches, out)
  invisible(NULL)
}