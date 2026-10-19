# Builds a minimal, self-contained one-paper batch_1/ folder, matching what
# split_for_review() itself would produce, for the resolve_paper()/
# build_rows()/build_*_workbook() tests below.
# env = parent.frame(): ties the tempdir's cleanup to the calling
# test_that() block, not this helper's own call frame -- see
# test-review_io.R's make_batch_dir() for the full explanation.
make_resolved_test_batch <- function(env = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = env)
  batch_dir <- file.path(dir, "batch_1")
  dir.create(file.path(batch_dir, "input", "to_review"), recursive = TRUE)
  dir.create(file.path(batch_dir, "output", "completed"), recursive = TRUE)

  extraction <- stats::setNames(
    lapply(EXTRACTION_FIELDS, function(f) list(ai = paste0("AI ", f), reviewed = NULL)),
    EXTRACTION_FIELDS
  )
  qa <- stats::setNames(
    lapply(QA_KEYS, function(k) list(ai_verdict = "Unclear", ai_evidence = paste0("Evidence ", k),
                                      reviewed_verdict = NULL, reviewed_evidence = NULL)),
    QA_KEYS
  )
  record <- list(
    paper_id = "Foo_2020", pdf_file = "papers/Foo_2020.pdf", doi = "10.1/abc",
    extraction_pipeline = "claude", extraction_flags = "", qa_pipeline = "claude",
    extraction = extraction, qa = qa, reviewer = NULL,
    extraction_status = "pending", qa_status = "pending", status = "pending",
    flag_for_discussion = FALSE, note = ""
  )
  jsonlite::write_json(record, file.path(batch_dir, "input", "to_review", "Foo_2020.json"),
                        auto_unbox = TRUE, null = "null")
  batch_dir
}

test_that("export_timestamp produces a filename-safe timestamp", {
  ts <- export_timestamp()
  expect_match(ts, "^\\d{4}-\\d{2}-\\d{2}_\\d{6}$")
  expect_false(grepl("[:/]", ts))
})

test_that("access_type_label maps claude to open-access and everything else to paywalled", {
  expect_identical(access_type_label("claude"), "open-access")
  expect_identical(access_type_label("qwen3"), "paywalled")
  expect_identical(access_type_label("local_winner"), "paywalled")
  expect_identical(access_type_label(""), "paywalled")
})

test_that("derive_status covers all four combinations", {
  expect_identical(derive_status("done", "done"), "completed")
  expect_identical(derive_status("done", "pending"), "partial")
  expect_identical(derive_status("pending", "done"), "partial")
  expect_identical(derive_status("pending", "pending"), "pending")
})

test_that("resolve_paper falls back entirely to the AI baseline when nothing's been reviewed", {
  batch_dir <- make_resolved_test_batch()
  rec <- resolve_paper(
    file.path(batch_dir, "input", "to_review", "Foo_2020.json"),
    file.path(batch_dir, "output", "completed", "Foo_2020.json")  # doesn't exist yet
  )
  expect_identical(rec$status, "pending")
  expect_false(isTRUE(rec$extraction[[EXTRACTION_FIELDS[[1]]]]$changed))
  expect_identical(rec$extraction[[EXTRACTION_FIELDS[[1]]]]$reviewed, rec$extraction[[EXTRACTION_FIELDS[[1]]]]$ai)
  expect_identical(rec$qa[["1.1"]]$reviewed_verdict, rec$qa[["1.1"]]$ai_verdict)
})

test_that("resolve_paper merges a completed/ record over the AI baseline, carrying doi/pdf_file/pipeline from the baseline", {
  batch_dir <- make_resolved_test_batch()
  completed_path <- file.path(batch_dir, "output", "completed", "Foo_2020.json")
  completed <- list(
    paper_id = "Foo_2020", reviewer = "Jane",
    extraction_status = "done", qa_status = "pending",
    flag_for_discussion = TRUE, note = "check this one"
  )
  jsonlite::write_json(completed, completed_path, auto_unbox = TRUE, null = "null")

  rec <- resolve_paper(file.path(batch_dir, "input", "to_review", "Foo_2020.json"), completed_path)
  expect_identical(rec$reviewer, "Jane")
  expect_identical(rec$status, "partial")
  expect_identical(rec$doi, "10.1/abc")  # from the baseline, not reviewer-editable
  expect_identical(rec$pdf_file, "papers/Foo_2020.pdf")
  expect_identical(rec$extraction_pipeline, "claude")
})

test_that("collect_batches accepts a single batch dir directly", {
  batch_dir <- make_resolved_test_batch()
  expect_identical(collect_batches(batch_dir), batch_dir)
})

test_that("collect_batches finds batch_N/ subfolders under a parent review dir", {
  parent <- withr::local_tempdir()
  for (n in 1:2) {
    d <- file.path(parent, paste0("batch_", n))
    dir.create(file.path(d, "input", "to_review"), recursive = TRUE)
  }
  found <- collect_batches(parent)
  expect_length(found, 2)
  expect_true(all(grepl("batch_[12]$", found)))
})

test_that("collect_batches errors clearly when nothing usable is found", {
  empty_dir <- withr::local_tempdir()
  expect_error(collect_batches(empty_dir), "No batch_\\*")
})

test_that("build_rows resolves a real on-disk batch into one extraction row and one qa row", {
  batch_dir <- make_resolved_test_batch()
  rows <- build_rows(batch_dir)
  expect_length(rows$extraction_rows, 1)
  expect_length(rows$qa_rows, 1)
  expect_identical(rows$extraction_rows[[1]]$paper_id, "Foo_2020")
  expect_identical(rows$extraction_rows[[1]]$access_type, "open-access")
  expect_identical(rows$extraction_rows[[1]]$doi, "10.1/abc")
  expect_identical(rows$qa_rows[[1]]$access_type, "open-access")
  expect_identical(rows$qa_rows[[1]][["1.1"]], "Unclear")
  expect_identical(rows$qa_rows[[1]][["1.1_evidence"]], "Evidence 1.1")
})

test_that("build_extraction_workbook writes a valid workbook with access_type, not pipeline", {
  batch_dir <- make_resolved_test_batch()
  rows <- build_rows(batch_dir)
  wb <- build_extraction_workbook(rows$extraction_rows)
  out <- withr::local_tempfile(fileext = ".xlsx")
  openxlsx::saveWorkbook(wb, out, overwrite = TRUE)
  expect_true(file.exists(out))
  back <- openxlsx::read.xlsx(out)
  expect_true("access_type" %in% names(back))
  expect_false("pipeline" %in% names(back))
  expect_identical(back$access_type[[1]], "open-access")
})

test_that("build_qa_workbook writes a valid workbook with 33 verdict + 33 evidence columns", {
  batch_dir <- make_resolved_test_batch()
  rows <- build_rows(batch_dir)
  wb <- build_qa_workbook(rows$qa_rows)
  out <- withr::local_tempfile(fileext = ".xlsx")
  openxlsx::saveWorkbook(wb, out, overwrite = TRUE)
  back <- openxlsx::read.xlsx(out)
  expect_true(all(QA_KEYS %in% names(back)))
  expect_true(all(paste0(QA_KEYS, "_evidence") %in% names(back)))
  expect_true("access_type" %in% names(back))
})
