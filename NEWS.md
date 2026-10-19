# CoReview 0.0.0.9000

* Initial pre-CRAN version, restructured from the original Shiny app into
  golem's package/module conventions (`mod_CoReview_main_ui()`/`_server()`).
* Implemented "Save QA & continue", batch export, status badges, and
  change-count tracking, which the initial golem restructure had not yet
  carried over.
* Fixed change-tracking (red highlighting) not working at all: it relied on
  a CSS class added via `tagAppendAttributes()` on `textAreaInput()`/
  `selectInput()`, which places the class on the wrapping `<div>`, not the
  actual `<textarea>`/`<select>` element. Field widgets are now built as
  raw tags, matching the original app.
* Fixed a startup crash when a batch folder is supplied directly via
  `run_app(batch_dir = ...)` (reactive state read outside a reactive
  consumer).
* Fixed the Note and QA Evidence fields incorrectly flagging as "changed"
  on edit, and restored the QA Evidence field's read-only, display-only
  behaviour (the AI's own supporting quote, never reviewer-edited).
* Added "Open in system PDF viewer" and a per-paper DOI link, matching the
  original app.
* Switching papers (via the sidebar or auto-advance after completing both
  sections) now always lands on the Extraction tab.
* The exported `pipeline` column (AI model name) is now `access_type`
  (`open-access`/`paywalled`) in both deliverables.
