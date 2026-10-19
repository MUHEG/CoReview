# Shared core of the "combine reviewed batches into verified .xlsx" logic --
# used by both combine_reviewed() and run_review_app()'s in-app "Export
# batch output" button, so there is exactly one implementation of the
# row-building/red-highlighting logic, not two that could quietly drift
# apart. Pure functions only: nothing here reads commandArgs, writes to
# disk, or prints -- callers do that. Internal (non-exported) -- see
# R/reviewapp-package.R for this package's shared @import/@importFrom tags.
#
# Batch folder layout:
#   batch_N/
#     input/papers/<paper_id>.pdf        -- source PDFs, read-only
#     input/to_review/<paper_id>.json    -- AI output, read-only
#     output/completed/<paper_id>.json   -- reviewer's saved work, incremental
#     output/exports/                    -- this file's workbooks land here

# A timestamp safe to put in a filename (no colons/slashes), used by both
# the app's export button and the CLI's --timestamp-exports mode.
export_timestamp <- function() format(Sys.time(), "%Y-%m-%d_%H%M%S")

derive_status <- function(extraction_status, qa_status) {
  if (identical(extraction_status, "done") && identical(qa_status, "done")) return("completed")
  if (identical(extraction_status, "done") || identical(qa_status, "done")) return("partial")
  "pending"
}

# Merge a paper's to_review (AI baseline) record with its completed record,
# if one exists. Returns a fully-resolved record: every extraction field and
# QA item has ai/reviewed(-or-ai)/changed, plus reviewer/extraction_status/
# qa_status/status.
resolve_paper <- function(to_review_path, completed_path) {
  base <- jsonlite::fromJSON(to_review_path, simplifyVector = FALSE)
  
  if (!file.exists(completed_path)) {
    base$extraction <- lapply(base$extraction, function(f) {
      list(ai = f$ai %||% "", reviewed = f$ai %||% "", changed = FALSE)
    })
    base$qa <- lapply(base$qa, function(item) {
      list(ai_verdict = item$ai_verdict %||% "", ai_evidence = item$ai_evidence %||% "",
           reviewed_verdict = item$ai_verdict %||% "", reviewed_evidence = item$ai_evidence %||% "",
           changed = FALSE)
    })
    base$reviewer <- NA_character_
    base$extraction_status <- "pending"
    base$qa_status <- "pending"
    base$status <- "pending"
    base$flag_for_discussion <- FALSE
    base$note <- ""
    return(base)
  }
  
  completed <- jsonlite::fromJSON(completed_path, simplifyVector = FALSE)
  completed$pdf_file <- base$pdf_file
  completed$extraction_pipeline <- base$extraction_pipeline
  completed$extraction_flags <- base$extraction_flags
  completed$qa_pipeline <- base$qa_pipeline
  completed$doi <- base$doi %||% ""  # always from the AI baseline -- never reviewer-editable
  # Back-compat: a completed/ file from before extraction/QA were tracked
  # separately only ever existed once BOTH sections were saved together.
  completed$extraction_status <- completed$extraction_status %||% "done"
  completed$qa_status <- completed$qa_status %||% "done"
  completed$status <- completed$status %||% derive_status(completed$extraction_status, completed$qa_status)
  completed
}

# review_dir can point at either the parent folder holding all batch_N/
# folders (the normal, whole-corpus combine) OR a single batch_N/ folder
# directly (a reviewer previewing/exporting just their own work).
collect_batches <- function(review_dir) {
  if (dir.exists(file.path(review_dir, "input", "to_review"))) return(review_dir)
  batch_dirs <- list.dirs(review_dir, recursive = FALSE)
  batch_dirs <- batch_dirs[grepl("/batch_[0-9]+$", batch_dirs)]
  batch_dirs <- batch_dirs[dir.exists(file.path(batch_dirs, "input", "to_review"))]
  if (length(batch_dirs) == 0) stop("No batch_* folders with an input/to_review/ (and no input/to_review/ directly) found under ", review_dir)
  sort(batch_dirs)
}

# A function, not a top-level constant: a top-level call to an imported
# package's function (openxlsx::createStyle()) would run at package LOAD
# time, before this package's own NAMESPACE imports are necessarily in
# effect (e.g. during roxygen2::roxygenise()'s own load-and-parse pass,
# which regenerates NAMESPACE from these very doc comments -- a
# chicken-and-egg problem on a fresh build). Cheap enough to just build on
# every call.
red_fill <- function() createStyle(fgFill = "#FDECEA", fontColour = "#7A1E1E")

# openxlsx (as of 4.2.8.1) always reserves a drawing/vmlDrawing relationship
# per sheet, even when nothing ever adds a chart/image/comment -- the actual
# drawing1.xml/vmlDrawing1.vml files never get written, leaving a dangling
# relationship target. Excel silently tolerates this, but strict OOXML
# readers (openpyxl, some validators) refuse to open the file. Strip it
# before saving so the deliverable opens cleanly everywhere.
drop_dangling_drawing_rels <- function(wb) {
  wb$worksheets_rels <- lapply(wb$worksheets_rels, function(rels) {
    rels[!grepl("relationships/(vmlD|d)rawing", rels, ignore.case = TRUE)]
  })
  for (i in seq_along(wb$worksheets)) wb$worksheets[[i]]$drawing <- character(0)
  wb
}

# Walks the given batch_dirs (as returned by collect_batches) and returns
# list(extraction_rows = ..., qa_rows = ...) -- the resolved, per-row data
# both output workbooks are built from.
build_rows <- function(batch_dirs) {
  extraction_rows <- list()
  qa_rows <- list()
  
  for (bd in batch_dirs) {
    to_review_files <- list.files(file.path(bd, "input", "to_review"), pattern = "\\.json$", full.names = TRUE)
    for (trf in to_review_files) {
      pid <- sub("\\.json$", "", basename(trf))
      completed_path <- file.path(bd, "output", "completed", paste0(pid, ".json"))
      rec <- resolve_paper(trf, completed_path)
      
      erow <- c(
        list(paper_id = pid, pipeline = rec$extraction_pipeline %||% "", doi = rec$doi %||% ""),
        setNames(lapply(EXTRACTION_FIELDS, function(f) rec$extraction[[f]]$reviewed %||% rec$extraction[[f]]$ai %||% ""), EXTRACTION_FIELDS),
        list(Flags = rec$extraction_flags %||% "",
             reviewer = rec$reviewer %||% NA_character_,
             extraction_status = rec$extraction_status, qa_status = rec$qa_status, status = rec$status,
             flag_for_discussion = isTRUE(rec$flag_for_discussion),
             note = rec$note %||% "")
      )
      erow$.changed <- vapply(EXTRACTION_FIELDS, function(f) isTRUE(rec$extraction[[f]]$changed), logical(1))
      extraction_rows[[length(extraction_rows) + 1]] <- erow
      
      # Wide: one row per paper, one verdict column PLUS one evidence column
      # per sub-item (66 data columns) -- easier to scan a paper's whole
      # checklist, verdict and supporting quote together, than 33 separate
      # rows. Evidence is display-only in the app (never reviewer-edited),
      # so it's always the AI's own text, but it's kept here alongside the
      # verdict rather than making a reader go back to the original
      # pre-review qa_33items.xlsx to see what the verdict was based on.
      qrow <- list(paper = pid, pipeline = rec$qa_pipeline %||% "",
                   reviewer = rec$reviewer %||% NA_character_,
                   extraction_status = rec$extraction_status, qa_status = rec$qa_status, status = rec$status,
                   flag_for_discussion = isTRUE(rec$flag_for_discussion), note = rec$note %||% "")
      changed_qa_cols <- character(0)
      for (key in QA_KEYS) {
        item <- rec$qa[[key]]
        ai_v <- item$ai_verdict %||% ""
        v <- item$reviewed_verdict %||% ai_v
        qrow[[key]] <- v
        qrow[[paste0(key, "_evidence")]] <- item$reviewed_evidence %||% item$ai_evidence %||% ""
        if (isTRUE(item$changed) && !identical(v, ai_v)) changed_qa_cols <- c(changed_qa_cols, key)
      }
      qrow$.changed <- changed_qa_cols
      qa_rows[[length(qa_rows) + 1]] <- qrow
    }
  }
  list(extraction_rows = extraction_rows, qa_rows = qa_rows)
}

# Returns a ready-to-save openxlsx Workbook (styling + dangling-rel fix
# already applied) -- never writes to disk itself.
build_extraction_workbook <- function(extraction_rows) {
  ex_cols <- c("paper_id", "pipeline", "doi", EXTRACTION_FIELDS, "Flags", "reviewer",
               "extraction_status", "qa_status", "status", "flag_for_discussion", "note")
  wb <- createWorkbook()
  addWorksheet(wb, "final_extraction")
  writeData(wb, "final_extraction", as.data.frame(t(sapply(extraction_rows, function(r) unlist(r[ex_cols])))))
  for (i in seq_along(extraction_rows)) {
    changed_cols <- which(EXTRACTION_FIELDS %in% EXTRACTION_FIELDS[extraction_rows[[i]]$.changed])
    if (length(changed_cols)) {
      col_idx <- match(EXTRACTION_FIELDS, ex_cols)[changed_cols]
      addStyle(wb, "final_extraction", red_fill(), rows = i + 1, cols = col_idx, gridExpand = TRUE)
    }
  }
  setColWidths(wb, "final_extraction", cols = seq_along(ex_cols), widths = 22)
  drop_dangling_drawing_rels(wb)
}

# One row per paper, one verdict column PLUS one evidence column per
# sub-item (e.g. "1.1", "1.1_evidence", ..., "10.6", "10.6_evidence").
build_qa_workbook <- function(qa_rows) {
  item_cols <- as.vector(rbind(QA_KEYS, paste0(QA_KEYS, "_evidence")))
  qa_cols <- c("paper", "pipeline", "reviewer", "extraction_status", "qa_status", "status",
               "flag_for_discussion", "note", item_cols)
  wb <- createWorkbook()
  addWorksheet(wb, "qa_33items")
  writeData(wb, "qa_33items", as.data.frame(t(sapply(qa_rows, function(r) unlist(r[qa_cols])))))
  for (i in seq_along(qa_rows)) {
    changed_cols <- match(qa_rows[[i]]$.changed, qa_cols)
    changed_cols <- changed_cols[!is.na(changed_cols)]
    if (length(changed_cols)) addStyle(wb, "qa_33items", red_fill(), rows = i + 1, cols = changed_cols, gridExpand = TRUE)
  }
  widths <- rep(10, length(qa_cols))
  widths[qa_cols %in% c("paper", "pipeline", "reviewer")] <- 16
  widths[qa_cols == "note" | grepl("_evidence$", qa_cols)] <- 30
  setColWidths(wb, "qa_33items", cols = seq_along(qa_cols), widths = widths)
  drop_dangling_drawing_rels(wb)
}