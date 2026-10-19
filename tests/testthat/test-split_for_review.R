test_that("assign_batches splits evenly across n_batches and keeps every id", {
  ids <- paste0("Paper_", 1:10)
  batches <- assign_batches(ids, 2)
  expect_length(batches, 2)
  expect_identical(sort(unlist(batches, use.names = FALSE)), sort(ids))
})

test_that("assign_batches(n_batches = 1) puts everything in one batch (regression: cut() rejects breaks = 1)", {
  ids <- paste0("Paper_", 1:5)
  batches <- assign_batches(ids, 1)
  expect_length(batches, 1)
  expect_identical(batches[[1]], ids)
})

test_that("pick_primary_qa_pipeline prefers claude, then qwen3, then local_winner, then whatever's left", {
  expect_identical(pick_primary_qa_pipeline(c("qwen3", "claude")), "claude")
  expect_identical(pick_primary_qa_pipeline(c("local_winner", "qwen3")), "qwen3")
  expect_identical(pick_primary_qa_pipeline("local_winner"), "local_winner")
  expect_identical(pick_primary_qa_pipeline("some_other_pipeline"), "some_other_pipeline")
})

test_that("build_record assembles extraction + all 33 QA items from minimal inputs, carrying doi through", {
  ex_row <- stats::setNames(as.list(rep("value", length(EXTRACTION_FIELDS))), EXTRACTION_FIELDS)
  ex_row$pipeline <- "claude"
  ex_row$Flags <- "some flag"
  ex_row <- as.data.frame(ex_row, stringsAsFactors = FALSE)

  qa_rows <- data.frame(
    pipeline = "claude", subitem = "1.1", verdict = "Yes", evidence = "because X",
    stringsAsFactors = FALSE
  )

  rec <- build_record("Foo_2020", ex_row, qa_rows, "papers/Foo_2020.pdf", doi = "10.1/xyz")

  expect_identical(rec$paper_id, "Foo_2020")
  expect_identical(rec$doi, "10.1/xyz")
  expect_identical(rec$extraction_pipeline, "claude")
  expect_identical(rec$qa_pipeline, "claude")
  expect_length(rec$qa, length(QA_KEYS))
  expect_identical(rec$qa[["1.1"]]$ai_verdict, "Yes")
  expect_identical(rec$qa[["1.1"]]$ai_evidence, "because X")
  # No QA row at all for "1.2" -- falls back to "Unclear"/"", not an error.
  expect_identical(rec$qa[["1.2"]]$ai_verdict, "Unclear")
  expect_identical(rec$extraction_status, "pending")
})

test_that("build_record defaults doi to \"\" when none is supplied", {
  ex_row <- stats::setNames(as.list(rep("value", length(EXTRACTION_FIELDS))), EXTRACTION_FIELDS)
  ex_row <- as.data.frame(ex_row, stringsAsFactors = FALSE)
  qa_rows <- data.frame(pipeline = character(0), subitem = character(0), verdict = character(0), evidence = character(0))
  rec <- build_record("Foo_2020", ex_row, qa_rows, "papers/Foo_2020.pdf")
  expect_identical(rec$doi, "")
})

test_that("split_for_review() writes a complete batch folder from .xlsx input, with DOI from the manifest", {
  work_dir <- withr::local_tempdir()

  ex_df <- stats::setNames(as.data.frame(matrix("value", nrow = 2, ncol = length(EXTRACTION_FIELDS))), EXTRACTION_FIELDS)
  ex_df$paper_id <- c("Foo_2020", "Bar_2021")
  ex_df$pipeline <- c("claude", "qwen3")
  ex_df$Flags <- ""
  extraction_path <- file.path(work_dir, "extraction.xlsx")
  openxlsx::write.xlsx(ex_df, extraction_path)

  qa_df <- data.frame(
    paper = rep(c("Foo_2020", "Bar_2021"), each = length(QA_KEYS)),
    pipeline = rep(c("claude", "qwen3"), each = length(QA_KEYS)),
    subitem = rep(QA_KEYS, 2),
    verdict = "Unclear",
    evidence = "some evidence",
    stringsAsFactors = FALSE
  )
  qa_path <- file.path(work_dir, "qa.xlsx")
  openxlsx::write.xlsx(qa_df, qa_path)

  papers_dir <- file.path(work_dir, "papers")
  dir.create(papers_dir)
  writeLines("not a real pdf, just needs to exist", file.path(papers_dir, "Foo_2020.pdf"))
  # Bar_2021.pdf deliberately NOT created, to exercise the "PDF not found" warning path.

  manifest_path <- file.path(work_dir, "manifest.json")
  jsonlite::write_json(
    list(list(paper_id = "Foo_2020", pdf_file = "Foo_2020.pdf", doi = "10.1/foo"),
         list(paper_id = "Bar_2021", pdf_file = "Bar_2021.pdf")),
    manifest_path, auto_unbox = TRUE
  )

  out_dir <- file.path(work_dir, "out")
  expect_warning(
    split_for_review(extraction_path, qa_path, papers_dir, out_dir, manifest = manifest_path, n_batches = 1),
    "PDF not found"
  )

  foo_record <- jsonlite::fromJSON(file.path(out_dir, "batch_1", "input", "to_review", "Foo_2020.json"), simplifyVector = FALSE)
  expect_identical(foo_record$doi, "10.1/foo")
  expect_true(file.exists(file.path(out_dir, "batch_1", "input", "papers", "Foo_2020.pdf")))

  bar_record <- jsonlite::fromJSON(file.path(out_dir, "batch_1", "input", "to_review", "Bar_2021.json"), simplifyVector = FALSE)
  expect_identical(bar_record$doi, "")  # manifest entry has no doi field at all
  expect_false(file.exists(file.path(out_dir, "batch_1", "input", "papers", "Bar_2021.pdf")))

  expect_true(dir.exists(file.path(out_dir, "batch_1", "output", "completed")))
  expect_true(dir.exists(file.path(out_dir, "batch_1", "output", "exports")))
})
