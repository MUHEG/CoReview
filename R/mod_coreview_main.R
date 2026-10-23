#' CoReview_main UI Function
#'
#' @description A shiny Module -- the human-verification review screen.
#'   Extraction/QA field widgets are built once, here, as static UI (per
#'   AGENTS.md: prefer static UI + update*() over renderUI()) -- they never
#'   change shape (EXTRACTION_FIELDS/QA_SECTIONS are fixed constants), only
#'   their values do, and those are pushed in via update*Input() +
#'   setAiBaseline custom messages. Only content that genuinely varies in
#'   STRUCTURE (the paper list, the PDF pane, status badges, the export box)
#'   stays as renderUI()/uiOutput(), per AGENTS.md's "only if there are no
#'   other options."
#'
#' @param id,input,output,session Internal parameters for {shiny}.
#'
#' @noRd
#'
#' @importFrom shiny NS tagList tags div h4 h5 fluidRow column tabsetPanel
#'   tabPanel textInput actionButton checkboxInput textAreaInput helpText
#'   uiOutput textOutput selectInput conditionalPanel HTML tagAppendAttributes
app_css <- "
html, body { height: 100%; }
body { padding-bottom: 60px; }
.app-shell { display: flex; align-items: flex-start; gap: 0; }
.sidebar-col {
  flex: 0 0 230px; width: 230px; max-width: 230px; overflow: hidden;
  background: #f7f7f8; border-right: 1px solid #e2e2e2; padding: 48px 15px 15px 15px;
  transition: flex-basis .15s, width .15s, padding .15s, opacity .1s;
}
.sidebar-col.collapsed { flex: 0 0 0; width: 0; max-width: 0; padding: 48px 0 15px 0; opacity: 0; pointer-events: none; }
.main-col { flex: 1 1 auto; min-width: 0; padding: 15px 20px 15px 48px; }
.sidebar-toggle-btn {
  position: fixed; top: 12px; left: 8px; z-index: 1000;
  border: 1px solid #ccc; background: #fff; border-radius: 4px;
  width: 30px; height: 30px; line-height: 28px; text-align: center; cursor: pointer;
}
.batch-picker { margin-bottom: 10px; }
.batch-picker .form-group { margin-bottom: 6px; }
.batch-picker-status { font-size: 0.82em; margin-top: 4px; }
.batch-picker-status.ok { color: #1a7f37; }
.batch-picker-status.err { color: #c0392b; font-weight: 600; }
.no-data-placeholder {
  padding: 40px; text-align: center; color: #888; font-size: 1.05em;
  border: 2px dashed #ddd; border-radius: 8px; margin-top: 40px;
}
.review-box { transition: background-color .15s, border-color .15s, box-shadow .15s; }
.review-box.changed {
  border: 2px solid #c0392b !important;
  background-color: #fdecea !important;
  box-shadow: 0 0 0 1px #c0392b33;
}
.review-field.field-changed > label, .qa-item.field-changed > strong { color: #c0392b; }
.review-field.field-changed > label::after { content: ' (edited)'; font-weight: normal; font-size: 0.85em; color: #c0392b; }
.qa-item { border-bottom: 1px solid #eee; padding: 10px 0; }
.qa-item.field-changed { background-color: #fdf4f3; }
.qa-question { display: block; color: #555; font-size: 0.9em; margin: 2px 0 6px; }
.qa-na-note { display: block; color: #999; font-size: 0.8em; font-style: italic; }
.qa-evidence-display { background: #f0f0f0 !important; color: #555; cursor: default; }
.tab-scroll { max-height: 68vh; overflow-y: auto; padding-right: 6px; }
.tab-header { display: flex; align-items: center; justify-content: space-between; margin: 4px 0 10px; flex-wrap: wrap; gap: 6px; }
.status-badge { font-size: 0.82em; padding: 2px 10px; border-radius: 10px; font-weight: 600; }
.status-badge.done { background: #eafaf0; color: #1a7f37; }
.status-badge.pending { background: #f4f4f4; color: #888; }
.save-section-btn { margin-top: 10px; }
.pdf-toolbar { display: flex; align-items: center; gap: 8px; margin-bottom: 6px; flex-wrap: wrap; }
.extraction-flags { margin-bottom: 6px; padding: 6px 10px; background: #fff8e6; border: 1px solid #f0d58c; border-radius: 4px; font-size: 0.88em; color: #6b5100; }
#pdf_pane { width: 100%; height: 80vh; border: 1px solid #ccc; }
.paper-group-title { font-size: 0.8em; text-transform: uppercase; color: #888; margin: 12px 0 4px; }
.sidebar-paper {
  display: flex; align-items: center; gap: 6px; width: 100%; text-align: left;
  margin-bottom: 3px; padding: 4px 6px; border-radius: 4px; border: none; background: none;
}
.sidebar-paper:hover { background: #eaeaea; }
.sidebar-paper .status-dot { display: inline-block; width: 9px; height: 9px; border-radius: 50%; flex: 0 0 auto; }
.sidebar-paper.done .status-dot { background: #1a7f37; }
.sidebar-paper.partial .status-dot { background: #e0a800; }
.sidebar-paper.pending .status-dot { background: #bbb; }
.sidebar-paper.done { color: #1a7f37; }
.sidebar-paper.partial { color: #8a6500; }
.sidebar-paper.selected { background: #e4e4e4; }
.sidebar-paper.selected:hover { background: #e4e4e4; }
.change-counter { font-weight: 600; }
.export-box { margin-top: 14px; padding: 10px; background: #eafaf0; border: 1px solid #a8dbb8; border-radius: 6px; }
.export-box p { margin: 0 0 6px; font-weight: 600; color: #1a7f37; }
.export-box .export-note { display: block; font-size: 0.82em; font-weight: normal; color: #6a6a6a; margin-bottom: 8px; }
.export-box .btn { margin-bottom: 6px; }
"

# Client-side only: toggles .changed on any .review-box whose value differs
# from its data-ai baseline (and .field-changed on the wrapping field/item,
# for the label/strikeout styling). Kept in JS (not a server round trip) so
# typing in a textarea never loses cursor focus. Matches on the .review-box
# CLASS, not the tag name -- Note and the (deliberately read-only, never
# reviewer-edited) QA Evidence box are plain textareas WITHOUT that class,
# precisely so they're excluded here.
app_js <- "
function refreshChanged(el) {
  var ai = el.getAttribute('data-ai') || '';
  var isChanged = el.value !== ai;
  el.classList.toggle('changed', isChanged);
  var wrap = el.closest('.review-field') || el.closest('.qa-item');
  if (wrap) {
    var evidenceEl = wrap.querySelector ? wrap.querySelector('textarea.review-box') : null;
    var verdictEl = wrap.querySelector ? wrap.querySelector('select.review-box') : null;
    var anyChanged = (evidenceEl && evidenceEl.classList.contains('changed')) ||
                      (verdictEl && verdictEl.classList.contains('changed')) ||
                      isChanged;
    wrap.classList.toggle('field-changed', anyChanged);
  }
}
document.addEventListener('input', function(e) {
  if (e.target && e.target.classList && e.target.classList.contains('review-box')) refreshChanged(e.target);
});
document.addEventListener('change', function(e) {
  if (e.target && e.target.classList && e.target.classList.contains('review-box')) refreshChanged(e.target);
});
if (typeof Shiny !== 'undefined') {
  // setAiBaseline can arrive before the matching updateTextAreaInput()/
  // updateSelectInput() call has actually landed on the same element --
  // message arrival order isn't a guarantee of client-side processing
  // order. Retrying on a short timer (rather than comparing immediately)
  // waits this out. Because the field widgets are now static (built once,
  // in mod_CoReview_main_ui(), not via renderUI()), the element itself is
  // ALWAYS already in the DOM by the time this fires -- only the value
  // update's landing order is ever in question, never the element's
  // existence.
  Shiny.addCustomMessageHandler('setAiBaseline', function(msg) {
    var attempts = 0;
    function apply() {
      var el = document.getElementById(msg.id);
      if (!el) { if (++attempts < 40) setTimeout(apply, 25); return; }
      el.setAttribute('data-ai', msg.ai);
      refreshChanged(el);
      setTimeout(function() { refreshChanged(el); }, 50);
      setTimeout(function() { refreshChanged(el); }, 250);
    }
    setTimeout(apply, 0);
  });
}
document.addEventListener('DOMContentLoaded', function() {
  var btn = document.getElementById('sidebar_toggle');
  var side = document.getElementById('sidebar_col');
  if (btn && side) btn.addEventListener('click', function() { side.classList.toggle('collapsed'); });
});
"

status_badge <- function(label_done, label_pending, done) {
  if (isTRUE(done)) span(class = "status-badge done", paste0("\u2713 ", label_done))
  else span(class = "status-badge pending", label_pending)
}

no_data_text <- "No data loaded. Paste a batch folder's path above (it needs input/papers/ and input/to_review/ inside it) and click Load."

# Static extraction-field widgets -- built once, here, not per paper-load
# and not via renderUI(). EXTRACTION_FIELDS never changes shape at runtime,
# only the per-paper VALUES do (pushed in later via updateTextAreaInput() +
# the setAiBaseline custom message), so there's nothing to regenerate.
#
# Raw tags$textarea(), deliberately NOT textAreaInput() +
# tagAppendAttributes(): textAreaInput() returns a wrapping
# <div class="shiny-input-textarea ..."><textarea class="form-control">
# structure, so tagAppendAttributes(..., class = "review-box") lands the
# class on the OUTER div, never on the <textarea> itself -- the change-
# tracking JS (which matches .review-box on the actual input element) then
# never fires. Confirmed directly: printing that tag shows class="review-box"
# on the <div>, "form-control" (alone) on the <textarea>. A raw tag sidesteps
# this entirely by only ever having the one element to put the class on.
extraction_field_widgets <- function(ns) {
  tagList(lapply(EXTRACTION_FIELDS, function(f) {
    field_id <- ns(paste0("ext_", f))
    div(class = "review-field",
        tags$label(gsub("_", " ", f), `for` = field_id),
        tags$textarea(id = field_id, class = "form-control review-box",
                       rows = extraction_field_rows(f), `data-ai` = "")
    )
  }))
}

# Static QA-item widgets -- same reasoning as extraction_field_widgets().
# The Evidence box is deliberately a plain tags$textarea(), not
# textAreaInput() -- readonly, no "review-box" class, so it's excluded from
# both the change-tracking JS and any updateXInput() calls: it's the AI's
# own supporting quote, display-only, never reviewer-edited.
qa_item_widgets <- function(ns) {
  tagList(lapply(QA_SECTIONS, function(sec) {
    tagList(
      h5(paste0(sec$id, ". ", sec$title)),
      lapply(names(sec$items), function(key) {
        vid <- ns(paste0("qa_verdict_", qa_id(key)))
        eid <- ns(paste0("qa_evidence_", qa_id(key)))
        div(class = "qa-item",
            tags$strong(key), tags$span(class = "qa-question", sec$items[[key]]),
            if (key %in% QA_NA_ELIGIBLE) tags$span(class = "qa-na-note", "\"Not applicable\" is a valid answer here."),
            fluidRow(
              # Raw tags$select(), not selectInput() + tagAppendAttributes()
              # -- same wrapping-div problem as extraction_field_widgets()
              # above (selectInput() also returns a wrapper div, not a bare
              # <select>); a raw tag is the only way to put "review-box"
              # directly on the element the JS actually matches against.
              column(3, tags$select(id = vid, class = "form-control review-box", `data-ai` = "",
                                     lapply(qa_verdict_choices(key), function(v) tags$option(value = v, v)))),
              column(9, tags$textarea(id = eid, class = "form-control qa-evidence-display", rows = 3, readonly = "readonly"))
            )
        )
      })
    )
  }))
}

mod_CoReview_main_ui <- function(id) {

  ns <- NS(id)

  tagList(
    tags$head(
      tags$style(HTML(app_css)),
      tags$script(HTML(app_js)),
      tags$title("AI review verification")
    ),

    tags$button(id = "sidebar_toggle", class = "sidebar-toggle-btn", title = "Show/hide paper list", "\u2630"),

    div(class = "app-shell",

      div(id = "sidebar_col", class = "sidebar-col",

        h4("AI review verification"),

        div(class = "batch-picker",
            textInput(ns("batch_path"), "Batch folder", placeholder = "Paste the full path to your batch folder"),
            actionButton(ns("load_batch_btn"), "Load", class = "btn-default btn-sm"),
            uiOutput(ns("batch_picker_status"))
        ),

        tags$hr(),

        conditionalPanel("!output.has_batch", ns = ns,
          div(class = "no-data-placeholder", no_data_text)
        ),

        conditionalPanel("output.has_batch", ns = ns,
          textInput(ns("reviewer_name"), "Your name", placeholder = "required before saving"),
          tags$hr(),
          uiOutput(ns("paper_list")),
          tags$hr(),
          checkboxInput(ns("flag_for_discussion"), "Flag this paper for discussion", value = FALSE),
          textAreaInput(ns("note"), "Note", rows = 3),
          helpText("Flag/note are saved whichever Save button you use."),
          uiOutput(ns("export_section"))
        )
      ),

      div(class = "main-col",

        conditionalPanel("!output.has_batch", ns = ns,
          div(class = "no-data-placeholder", no_data_text)
        ),

        conditionalPanel("output.has_batch", ns = ns,
          fluidRow(
            column(6, uiOutput(ns("pdf_frame"))),
            column(6,
              tabsetPanel(id = ns("review_tabs"),
                tabPanel("Extraction",
                  div(class = "tab-header",
                      div(class = "change-counter", textOutput(ns("extraction_change_count"), inline = TRUE)),
                      uiOutput(ns("extraction_status_badge"), inline = TRUE)
                  ),
                  div(class = "tab-scroll", extraction_field_widgets(ns)),
                  actionButton(ns("save_extraction_btn"), "Save extraction & continue", class = "btn-primary save-section-btn")
                ),
                tabPanel("Quality Assessment",
                  div(class = "tab-header",
                      div(class = "change-counter", textOutput(ns("qa_change_count"), inline = TRUE)),
                      uiOutput(ns("qa_status_badge"), inline = TRUE)
                  ),
                  div(class = "tab-scroll", qa_item_widgets(ns)),
                  actionButton(ns("save_qa_btn"), "Save QA & continue", class = "btn-primary save-section-btn")
                )
              )
            )
          )
        )
      )
    )
  )
}

#' CoReview_main Server Functions
#'
#' @noRd
#'
#' @importFrom shiny moduleServer reactiveValues reactive outputOptions
#'   renderUI observeEvent updateTextInput updateTextAreaInput
#'   updateCheckboxInput updateSelectInput updateTabsetPanel showNotification
#'   req actionLink span tagList renderText
mod_CoReview_main_server <- function(
    id,
    initial_batch_dir = NULL,
    reviewer = NULL
) {

  moduleServer(
    id,
    function(input, output, session) {

      # --------------------------------------------------
      # State -- one reactiveValues() per AGENTS.md (never reactiveVal()).
      # reviewer_prefilled is the one deliberate exception: a plain,
      # non-reactive closure flag, not part of this. Nothing ever needs to
      # REACT to it changing, and do_load() -- which reads and sets it --
      # runs once synchronously outside any reactive consumer whenever
      # initial_batch_dir is supplied (see the session$onFlushed() call
      # below). Reading a reactiveValues field (same as a reactiveVal's
      # getter) outside a reactive consumer throws "Operation not allowed
      # without an active reactive context" in a real session -- keeping
      # this one flag plain avoids that class of bug entirely rather than
      # working around it.
      # --------------------------------------------------

      review_state <- reactiveValues(
        batch_dir = NULL,
        paper_ids = character(0),
        paper_statuses = character(0),
        current_paper = NULL,
        record = NULL,
        load_message = NULL
      )

      reviewer_prefilled <- FALSE

      # --------------------------------------------------
      # Helpers
      # --------------------------------------------------

      # Loads (or reloads) a batch folder. Called once at startup if
      # initial_batch_dir was supplied, and again any time the reviewer
      # pastes a different path and clicks Load -- same validation, same
      # "no data" handling either way. Only ever SETS review_state fields
      # (always safe, even outside a reactive consumer) -- never reads one
      # back for its own logic, so it's safe to call from the one-time,
      # non-reactive startup path too.
      do_load <- function(path) {
        path <- trimws(path %||% "")
        if (path == "") {
          review_state$load_message <- list(type = "err", text = "Enter a folder path first.")
          return(invisible())
        }

        ok <- tryCatch(dir.exists(path), error = function(e) FALSE)
        if (!ok) {
          review_state$load_message <- list(type = "err", text = "That folder doesn't exist.")
          review_state$batch_dir <- NULL
          return(invisible())
        }

        path <- normalizePath(path, mustWork = TRUE)

        if (!is_batch_dir(path)) {
          review_state$load_message <- list(type = "err", text = "No data \u2014 that folder needs an input/papers/ and input/to_review/ inside it.")
          review_state$batch_dir <- NULL
          return(invisible())
        }

        ids <- list_paper_ids(path)
        if (length(ids) == 0) {
          review_state$load_message <- list(type = "err", text = "No data \u2014 input/to_review/ is empty.")
          review_state$batch_dir <- NULL
          return(invisible())
        }

        dir.create(file.path(path, "output", "completed"), recursive = TRUE, showWarnings = FALSE)
        dir.create(file.path(path, "output", "exports"), recursive = TRUE, showWarnings = FALSE)
        shiny::addResourcePath("pdfs_", file.path(path, "input", "papers"))

        statuses <- vapply(ids, function(p) paper_status(path, p), character(1))
        first_unfinished <- ids[statuses != "completed"][1]

        review_state$batch_dir <- path
        review_state$paper_ids <- ids
        review_state$paper_statuses <- statuses
        review_state$current_paper <- if (!is.na(first_unfinished)) first_unfinished else ids[[1]]
        review_state$load_message <- list(type = "ok", text = sprintf("Loaded %d paper(s).", length(ids)))

        updateTextInput(session, "batch_path", value = path)

        if (!reviewer_prefilled) {
          updateTextInput(session, "reviewer_name", value = reviewer %||% "")
          reviewer_prefilled <<- TRUE
        }
      }

      # Loads the given paper's record into the (static) field widgets via
      # update*Input() + setAiBaseline -- never renderUI(), per AGENTS.md.
      # Since the widgets are static (built once in mod_CoReview_main_ui()),
      # they're always already in the DOM by the time this runs -- no
      # render-order race to work around, no artificial delay needed.
      load_into_inputs <- function(rec) {
        for (f in EXTRACTION_FIELDS) {
          val <- current_value(rec$extraction[[f]])
          updateTextAreaInput(session, paste0("ext_", f), value = val %||% "")
          session$sendCustomMessage("setAiBaseline", list(id = session$ns(paste0("ext_", f)), ai = rec$extraction[[f]]$ai %||% ""))
        }
        for (key in QA_KEYS) {
          item <- rec$qa[[key]]
          vid <- paste0("qa_verdict_", qa_id(key)); eid <- paste0("qa_evidence_", qa_id(key))
          current_verdict <- current_qa_verdict(item) %||% "Unclear"
          updateSelectInput(session, vid, choices = union(qa_verdict_choices(key), current_verdict), selected = current_verdict)
          updateTextAreaInput(session, eid, value = item$ai_evidence %||% "")
          session$sendCustomMessage("setAiBaseline", list(id = session$ns(vid), ai = item$ai_verdict %||% ""))
        }
        updateCheckboxInput(session, "flag_for_discussion", value = isTRUE(rec$flag_for_discussion))
        updateTextAreaInput(session, "note", value = rec$note %||% "")
      }

      # Shared by both save buttons: persists reviewer/flag/note, updates
      # this paper's status, and only auto-advances once the paper is
      # FULLY done (both sections) -- a reviewer doing both sections
      # together isn't bounced to the next paper mid-paper; one doing
      # single-section passes across many papers navigates via the sidebar.
      finalize_save <- function(rec, pid, name) {
        rec$status <- derive_status(rec$extraction_status, rec$qa_status)
        rec$reviewer <- name
        rec$flag_for_discussion <- isTRUE(input$flag_for_discussion)
        rec$note <- input$note %||% ""
        save_record(review_state$batch_dir, rec)

        ids <- review_state$paper_ids
        statuses <- review_state$paper_statuses
        statuses[[which(ids == pid)]] <- rec$status
        review_state$paper_statuses <- statuses
        review_state$record <- rec

        showNotification(sprintf("Saved %s (%s)", pid, rec$status), type = "message")

        if (identical(rec$status, "completed")) {
          remaining <- ids[review_state$paper_statuses != "completed"]
          remaining <- remaining[remaining != pid]
          if (length(remaining) > 0) review_state$current_paper <- remaining[[1]]
          else showNotification("All papers in this batch are done.", type = "message", duration = NULL)
        }
      }

      # --------------------------------------------------
      # Startup -- deferred into session$onFlushed() rather than called
      # directly in the module body, so the one-time initial do_load()
      # (when initial_batch_dir is supplied) runs inside Shiny's reactive
      # machinery, per AGENTS.md's "always inside a reactive consumer",
      # even though do_load() itself only ever SETS review_state fields
      # (safe either way -- this is belt-and-braces, matching house style).
      # --------------------------------------------------

      session$onFlushed(function() {
        if (!is.null(initial_batch_dir)) do_load(initial_batch_dir)
      }, once = TRUE)

      # --------------------------------------------------
      # Outputs
      # --------------------------------------------------

      output$has_batch <- reactive({ !is.null(review_state$batch_dir) })
      outputOptions(output, "has_batch", suspendWhenHidden = FALSE)

      output$batch_picker_status <- renderUI({
        m <- review_state$load_message
        if (is.null(m)) return(NULL)
        div(class = paste("batch-picker-status", if (identical(m$type, "ok")) "ok" else "err"), m$text)
      })

      output$paper_list <- renderUI({
        ids <- review_state$paper_ids
        statuses <- review_state$paper_statuses
        current <- review_state$current_paper

        make_link <- function(i) {
          p <- ids[[i]]; st <- statuses[[i]]
          cls <- switch(st, completed = "done", partial = "partial", "pending")
          if (identical(p, current)) cls <- paste(cls, "selected")
          actionLink(session$ns(paste0("goto_", make.names(p))),
                     tagList(span(class = "status-dot"), span(p)),
                     class = paste("sidebar-paper", cls))
        }

        pending_idx <- which(statuses == "pending")
        partial_idx <- which(statuses == "partial")
        done_idx <- which(statuses == "completed")

        tagList(
          if (length(pending_idx)) tagList(div(class = "paper-group-title", sprintf("To review (%d)", length(pending_idx))), lapply(pending_idx, make_link)),
          if (length(partial_idx)) tagList(div(class = "paper-group-title", sprintf("In progress (%d)", length(partial_idx))), lapply(partial_idx, make_link)),
          if (length(done_idx)) tagList(div(class = "paper-group-title", sprintf("Completed (%d)", length(done_idx))), lapply(done_idx, make_link))
        )
      })

      output$extraction_status_badge <- renderUI({
        rec <- review_state$record; if (is.null(rec)) return(NULL)
        status_badge("extraction saved", "extraction not yet saved", identical(rec$extraction_status, "done"))
      })
      output$qa_status_badge <- renderUI({
        rec <- review_state$record; if (is.null(rec)) return(NULL)
        status_badge("QA saved", "QA not yet saved", identical(rec$qa_status, "done"))
      })

      output$pdf_frame <- renderUI({
        rec <- review_state$record; if (is.null(rec)) return(NULL)
        pdf_rel <- file.path("pdfs_", basename(rec$pdf_file %||% ""))
        doi <- trimws(rec$doi %||% "")
        flags <- trimws(rec$extraction_flags %||% "")
        tagList(
          div(class = "pdf-toolbar",
              actionButton(session$ns("open_system_pdf_btn"), "Open in system PDF viewer", class = "btn-default btn-sm"),
              if (nzchar(doi)) tags$a(href = paste0("https://doi.org/", doi), target = "_blank", rel = "noopener",
                                       class = "btn btn-default btn-sm", "View DOI \u2197")
          ),
          if (nzchar(flags)) div(class = "extraction-flags", tags$strong("AI flags: "), flags),
          tags$iframe(id = "pdf_pane", src = pdf_rel)
        )
      })

      # Shells out to the OS's own default PDF app -- the reliable,
      # guaranteed-search escape hatch (a browser-embedded PDF pane has no
      # find/search of its own). shell.exec() (Windows) takes the raw path,
      # no shell-quoting -- unlike the other two branches, quoting it there
      # would be wrong.
      observeEvent(input$open_system_pdf_btn, {
        rec <- review_state$record; if (is.null(rec)) return()
        pdf_path <- file.path(review_state$batch_dir, "input", rec$pdf_file)
        if (!file.exists(pdf_path)) { showNotification("PDF file not found on disk.", type = "error"); return() }
        pdf_path <- normalizePath(pdf_path)
        sysname <- Sys.info()[["sysname"]]
        withCallingHandlers(
          tryCatch({
            if (sysname == "Darwin") system2("open", shQuote(pdf_path))
            else if (sysname == "Windows") shell.exec(pdf_path)
            else system2("xdg-open", shQuote(pdf_path))
          }, error = function(e) showNotification(
            sprintf("Could not open externally on %s: %s", sysname, conditionMessage(e)), type = "error", duration = NULL)),
          warning = function(w) {
            showNotification(sprintf("Could not open externally on %s: %s", sysname, conditionMessage(w)), type = "error", duration = NULL)
            invokeRestart("muffleWarning")
          }
        )
      })

      output$extraction_change_count <- renderText({
        rec <- review_state$record
        n <- sum(vapply(EXTRACTION_FIELDS, function(f) {
          if (is.null(rec)) return(FALSE)
          !identical(input[[paste0("ext_", f)]] %||% "", rec$extraction[[f]]$ai %||% "")
        }, logical(1)))
        sprintf("%d of %d fields changed", n, length(EXTRACTION_FIELDS))
      })

      output$qa_change_count <- renderText({
        rec <- review_state$record
        if (is.null(rec)) return(sprintf("0 of %d items changed", length(QA_KEYS)))
        n <- sum(vapply(QA_KEYS, function(key) {
          item <- rec$qa[[key]]
          v <- input[[paste0("qa_verdict_", qa_id(key))]] %||% ""
          !identical(v, item$ai_verdict %||% "")
        }, logical(1)))
        sprintf("%d of %d items changed", n, length(QA_KEYS))
      })

      # "Export batch output" -- always available (not gated on
      # completion): unfinished papers are included with the AI's original
      # values via combine_logic.R's own fallback. Every click writes a NEW
      # timestamped pair of files -- nothing already-exported is ever
      # silently replaced.
      output$export_section <- renderUI({
        statuses <- review_state$paper_statuses
        n_done <- sum(statuses == "completed")
        n_total <- length(review_state$paper_ids)
        div(class = "export-box",
            tags$p(sprintf("%d of %d papers fully done.", n_done, n_total)),
            if (n_done < n_total) tags$span(class = "export-note",
              "You can export now anyway -- unfinished papers are included with the AI's original values, clearly marked."),
            actionButton(session$ns("export_batch_btn"), "Export batch output", class = "btn-default btn-block")
        )
      })

      observeEvent(input$export_batch_btn, {
        bd <- review_state$batch_dir; if (is.null(bd)) return()
        ts <- export_timestamp()
        batch_label <- basename(bd)
        exports_dir <- file.path(bd, "output", "exports")
        dir.create(exports_dir, recursive = TRUE, showWarnings = FALSE)
        ex_path <- file.path(exports_dir, sprintf("final_extraction_%s_%s.xlsx", batch_label, ts))
        qa_path <- file.path(exports_dir, sprintf("qa_33items_%s_%s.xlsx", batch_label, ts))
        tryCatch({
          rows <- build_rows(collect_batches(bd))
          openxlsx::saveWorkbook(build_extraction_workbook(rows$extraction_rows), ex_path, overwrite = TRUE)
          openxlsx::saveWorkbook(build_qa_workbook(rows$qa_rows), qa_path, overwrite = TRUE)
          showNotification(
            tagList(tags$div(tags$strong("Batch exported:")), tags$div(ex_path), tags$div(qa_path)),
            type = "message", duration = 15
          )
        }, error = function(e) {
          showNotification(paste("Export failed:", conditionMessage(e)), type = "error", duration = NULL)
        })
      })

      # --------------------------------------------------
      # Navigation
      # --------------------------------------------------

      observeEvent(input$load_batch_btn, { do_load(input$batch_path) })

      observeEvent(review_state$paper_ids, {
        ids <- review_state$paper_ids
        lapply(ids, function(p) {
          observeEvent(input[[paste0("goto_", make.names(p))]], { review_state$current_paper <- p }, ignoreInit = TRUE)
        })
      })

      observeEvent(review_state$current_paper, {
        req(review_state$batch_dir)
        req(review_state$current_paper)
        rec <- load_record(review_state$batch_dir, review_state$current_paper)
        review_state$record <- rec
        load_into_inputs(rec)
        # Always land on Extraction first for a new paper -- whether
        # switched to via the sidebar or by auto-advancing after
        # completing both sections of the previous one. Without this, the
        # tabset stays wherever it was (e.g. Quality Assessment, right
        # after clicking "Save QA & continue"), landing the reviewer on QA
        # for a paper they haven't even started yet.
        updateTabsetPanel(session, "review_tabs", selected = "Extraction")
      }, ignoreNULL = TRUE)

      # --------------------------------------------------
      # Save Actions
      # --------------------------------------------------

      observeEvent(input$save_extraction_btn, {
        name <- trimws(input$reviewer_name %||% "")
        if (name == "") { showNotification("Enter your name before saving.", type = "error"); return() }
        rec <- review_state$record; pid <- review_state$current_paper
        for (f in EXTRACTION_FIELDS) {
          ai <- rec$extraction[[f]]$ai %||% ""
          val <- input[[paste0("ext_", f)]] %||% ""
          rec$extraction[[f]] <- list(ai = ai, reviewed = val, changed = !identical(val, ai))
        }
        rec$extraction_status <- "done"
        finalize_save(rec, pid, name)
      })

      observeEvent(input$save_qa_btn, {
        name <- trimws(input$reviewer_name %||% "")
        if (name == "") { showNotification("Enter your name before saving.", type = "error"); return() }
        rec <- review_state$record; pid <- review_state$current_paper
        for (key in QA_KEYS) {
          item <- rec$qa[[key]]
          ai_v <- item$ai_verdict %||% ""; ai_e <- item$ai_evidence %||% ""
          v <- input[[paste0("qa_verdict_", qa_id(key))]] %||% ""
          # Evidence is display-only (not reviewer-editable), so it always
          # mirrors the AI's own text -- "changed" reflects the verdict alone.
          rec$qa[[key]] <- list(ai_verdict = ai_v, ai_evidence = ai_e,
                                 reviewed_verdict = v, reviewed_evidence = ai_e,
                                 changed = !identical(v, ai_v))
        }
        rec$qa_status <- "done"
        finalize_save(rec, pid, name)
      })

    }
  )

}
