# Reuses the same one-paper batch_1/ fixture shape as test-combine_logic.R's
# make_resolved_test_batch() -- duplicated locally rather than shared, so
# this file stays self-contained (per AGENTS.md: "each test_that() block
# sets up its own data inline").
make_test_review_dir <- function(env = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = env)
  batch_dir <- file.path(dir, "batch_1")
  dir.create(file.path(batch_dir, "input", "to_review"), recursive = TRUE)

  extraction <- stats::setNames(
    lapply(EXTRACTION_FIELDS, function(f) list(ai = paste0("AI ", f), reviewed = NULL)),
    EXTRACTION_FIELDS
  )
  qa <- stats::setNames(
    lapply(QA_KEYS, function(k) list(ai_verdict = "Unclear", ai_evidence = "",
                                      reviewed_verdict = NULL, reviewed_evidence = NULL)),
    QA_KEYS
  )
  record <- list(
    paper_id = "Foo_2020", pdf_file = "papers/Foo_2020.pdf", doi = "",
    extraction_pipeline = "claude", extraction_flags = "", qa_pipeline = "claude",
    extraction = extraction, qa = qa, reviewer = NULL,
    extraction_status = "pending", qa_status = "pending", status = "pending",
    flag_for_discussion = FALSE, note = ""
  )
  jsonlite::write_json(record, file.path(batch_dir, "input", "to_review", "Foo_2020.json"),
                        auto_unbox = TRUE, null = "null")
  dir
}

test_that("combine_reviewed() writes both deliverables under out/", {
  review_dir <- make_test_review_dir()
  out_dir <- file.path(review_dir, "combined")

  expect_output(combine_reviewed(review_dir, out_dir), "final_extraction_verified\\.xlsx")

  expect_true(file.exists(file.path(out_dir, "final_extraction_verified.xlsx")))
  expect_true(file.exists(file.path(out_dir, "qa_33items_verified.xlsx")))
})

test_that("combine_reviewed() respects custom output filenames", {
  review_dir <- make_test_review_dir()
  out_dir <- file.path(review_dir, "combined")

  combine_reviewed(review_dir, out_dir, extraction_out = "ex.xlsx", qa_out = "qa.xlsx")

  expect_true(file.exists(file.path(out_dir, "ex.xlsx")))
  expect_true(file.exists(file.path(out_dir, "qa.xlsx")))
})

test_that("combine_reviewed(timestamp = TRUE) inserts a timestamp before the extension", {
  review_dir <- make_test_review_dir()
  out_dir <- file.path(review_dir, "combined")

  combine_reviewed(review_dir, out_dir, timestamp = TRUE)

  written <- list.files(out_dir)
  expect_true(any(grepl("^final_extraction_verified_\\d{4}-\\d{2}-\\d{2}_\\d{6}\\.xlsx$", written)))
  expect_true(any(grepl("^qa_33items_verified_\\d{4}-\\d{2}-\\d{2}_\\d{6}\\.xlsx$", written)))
})
