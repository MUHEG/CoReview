# env = parent.frame() + .local_envir = env: withr::local_tempdir() ties its
# cleanup to the given environment -- without passing the CALLER's (the
# test_that() block's) environment through explicitly, it would tie to this
# helper's own call frame instead, and the directory would be deleted the
# moment this helper returns, before the test body ever runs.
make_batch_dir <- function(env = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = env)
  dir.create(file.path(dir, "input", "papers"), recursive = TRUE)
  dir.create(file.path(dir, "input", "to_review"), recursive = TRUE)
  dir
}

write_to_review <- function(batch_dir, paper_id, extra = list()) {
  record <- utils::modifyList(
    list(paper_id = paper_id, pdf_file = paste0("papers/", paper_id, ".pdf"), doi = ""),
    extra
  )
  jsonlite::write_json(record, to_review_path_for(batch_dir, paper_id), auto_unbox = TRUE, null = "null")
}

test_that("list_paper_ids lists and sorts ids from input/to_review/", {
  dir <- make_batch_dir()
  write_to_review(dir, "Zebra_2020")
  write_to_review(dir, "Apple_2019")
  expect_identical(list_paper_ids(dir), c("Apple_2019", "Zebra_2020"))
})

test_that("list_paper_ids returns character(0) for an empty to_review/", {
  dir <- make_batch_dir()
  expect_identical(list_paper_ids(dir), character(0))
})

test_that("is_batch_dir requires both input/papers/ and input/to_review/", {
  dir <- make_batch_dir()
  expect_true(is_batch_dir(dir))

  only_papers <- withr::local_tempdir()
  dir.create(file.path(only_papers, "input", "papers"), recursive = TRUE)
  expect_false(is_batch_dir(only_papers))

  expect_false(is_batch_dir(withr::local_tempdir()))
})

test_that("completed_path_for and to_review_path_for build the expected paths", {
  dir <- make_batch_dir()
  expect_identical(completed_path_for(dir, "Foo_2020"), file.path(dir, "output", "completed", "Foo_2020.json"))
  expect_identical(to_review_path_for(dir, "Foo_2020"), file.path(dir, "input", "to_review", "Foo_2020.json"))
})

test_that("paper_status is 'pending' when no completed/ file exists yet", {
  dir <- make_batch_dir()
  write_to_review(dir, "Foo_2020")
  expect_identical(paper_status(dir, "Foo_2020"), "pending")
})

test_that("paper_status reflects extraction_status/qa_status in the completed/ file", {
  dir <- make_batch_dir()
  cp <- completed_path_for(dir, "Foo_2020")
  dir.create(dirname(cp), recursive = TRUE, showWarnings = FALSE)

  jsonlite::write_json(list(paper_id = "Foo_2020", extraction_status = "done", qa_status = "pending"), cp, auto_unbox = TRUE)
  expect_identical(paper_status(dir, "Foo_2020"), "partial")

  jsonlite::write_json(list(paper_id = "Foo_2020", extraction_status = "done", qa_status = "done"), cp, auto_unbox = TRUE)
  expect_identical(paper_status(dir, "Foo_2020"), "completed")
})

test_that("paper_status back-compat: a completed/ file predating per-section tracking reads as done/done", {
  dir <- make_batch_dir()
  cp <- completed_path_for(dir, "Foo_2020")
  dir.create(dirname(cp), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(list(paper_id = "Foo_2020"), cp, auto_unbox = TRUE)
  expect_identical(paper_status(dir, "Foo_2020"), "completed")
})

test_that("load_record falls back to input/to_review/ when nothing's been saved yet", {
  dir <- make_batch_dir()
  write_to_review(dir, "Foo_2020", list(extra_field = "untouched"))
  rec <- load_record(dir, "Foo_2020")
  expect_identical(rec$extraction_status, "pending")
  expect_identical(rec$qa_status, "pending")
  expect_identical(rec$status, "pending")
  expect_identical(rec$extra_field, "untouched")
})

test_that("load_record prefers output/completed/ over input/to_review/ once it exists", {
  dir <- make_batch_dir()
  write_to_review(dir, "Foo_2020", list(reviewer = NULL))
  cp <- completed_path_for(dir, "Foo_2020")
  dir.create(dirname(cp), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(
    list(paper_id = "Foo_2020", reviewer = "Jane", extraction_status = "done", qa_status = "pending"),
    cp, auto_unbox = TRUE
  )
  rec <- load_record(dir, "Foo_2020")
  expect_identical(rec$reviewer, "Jane")
  expect_identical(rec$status, "partial")
})

test_that("save_record writes to output/completed/ and round-trips through load_record", {
  dir <- make_batch_dir()
  write_to_review(dir, "Foo_2020")
  record <- list(paper_id = "Foo_2020", reviewer = "Jane", extraction_status = "done", qa_status = "done", status = "completed")
  save_record(dir, record)
  expect_true(file.exists(completed_path_for(dir, "Foo_2020")))
  rec <- load_record(dir, "Foo_2020")
  expect_identical(rec$reviewer, "Jane")
  expect_identical(rec$status, "completed")
})

test_that("save_record creates output/completed/ if it doesn't exist yet", {
  dir <- withr::local_tempdir()  # deliberately no output/completed/ pre-created
  save_record(dir, list(paper_id = "Foo_2020"))
  expect_true(file.exists(completed_path_for(dir, "Foo_2020")))
})

test_that("current_value prefers a non-empty 'reviewed' value, else falls back to 'ai'", {
  expect_identical(current_value(list(ai = "AI text", reviewed = "Edited text")), "Edited text")
  expect_identical(current_value(list(ai = "AI text", reviewed = "")), "AI text")
  expect_identical(current_value(list(ai = "AI text", reviewed = NULL)), "AI text")
})

test_that("current_qa_verdict prefers a non-empty 'reviewed_verdict', else falls back to 'ai_verdict'", {
  expect_identical(current_qa_verdict(list(ai_verdict = "Yes", reviewed_verdict = "No")), "No")
  expect_identical(current_qa_verdict(list(ai_verdict = "Yes", reviewed_verdict = "")), "Yes")
  expect_identical(current_qa_verdict(list(ai_verdict = "Yes", reviewed_verdict = NULL)), "Yes")
})
