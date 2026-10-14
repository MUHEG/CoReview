# field_widget <- function(field_id, label, rows = 1) {
#   div(class = "review-field",
#       tags$label(label, `for` = field_id),
#       tags$textarea(id = field_id, class = "form-control review-box", rows = rows, `data-ai` = "")
#   )
# }

# field_widget <- function(field_id, label, rows = 1) {
#   
#   div(
#     class = "review-field",
#     
#     tags$label(label),
#     
#     textAreaInput(
#       inputId = field_id,
#       label = NULL,
#       value = "",
#       rows = rows
#     )
#     
#   )
#   
# }

field_widget <- function(field_id, label, rows = 1) {
  
  div(
    class = "review-field",
    
    tags$label(label),
    
    shiny::textAreaInput(
      inputId = field_id,
      label = NULL,
      value = "",
      rows = rows
    )
    
  )
}

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
textarea.changed {
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
.change-counter { font-weight: 600; }
.export-box { margin-top: 14px; padding: 10px; background: #eafaf0; border: 1px solid #a8dbb8; border-radius: 6px; }
.export-box p { margin: 0 0 6px; font-weight: 600; color: #1a7f37; }
.export-box .export-note { display: block; font-size: 0.82em; font-weight: normal; color: #6a6a6a; margin-bottom: 8px; }
.export-box .btn { margin-bottom: 6px; }
"

# Client-side only: toggles .changed on any .review-box whose value differs
# from its data-ai baseline (and .field-changed on the wrapping field/item,
# for the label/strikeout styling). Kept in JS (not a server round trip) so
# typing in a textarea never loses cursor focus.
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

  if (
    e.target &&
    e.target.tagName === 'TEXTAREA'
  ) {
    refreshChanged(e.target);
  }

});

document.addEventListener('change', function(e) {

  if (
    e.target &&
    e.target.tagName === 'TEXTAREA'
  ) {
    refreshChanged(e.target);
  }

});
if (typeof Shiny !== 'undefined') {
  // setAiBaseline can arrive before two things are true: (a) on the very
  // first paper shown, before the field widgets (rendered once via
  // renderUI) exist in the DOM at all; (b) on every later paper switch,
  // before the matching updateTextAreaInput()/updateSelectInput() call has
  // actually landed on that same element -- message send order on the
  // server is not a guarantee of client-side processing order. Retrying
  // on a short timer (rather than comparing immediately) waits out both.
  Shiny.addCustomMessageHandler('setAiBaseline', function(msg) {
    var attempts = 0;
    function apply() {
      var el = document.getElementById(msg.id);
      if (!el) { if (++attempts < 40) setTimeout(apply, 25); return; }
      el.setAttribute('data-ai', msg.ai);
      // Re-checked a couple more times shortly after: harmless if the value
      // update already landed (recomputes the same answer), and the safety
      // net if it lands a beat later than this message.
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


#' coreview_main UI Function
#'
#' @description A shiny Module.
#'
#' @param id,input,output,session Internal parameters for {shiny}.
#'
#' @noRd 
#'
#' @importFrom shiny NS tagList 
mod_coreview_main_ui <- function(id) {
  
  ns <- NS(id)
  
  tagList(
    tags$head(
      tags$style(HTML(app_css)),
      tags$script(HTML(app_js)),
      tags$title("AI review verification")
    ),
    
    tags$button(
      id = "sidebar_toggle",
      class = "sidebar-toggle-btn",
      title = "Show/hide paper list",
      "\u2630"
    ),
    
    div(
      class = "app-shell",
      
      div(
        id = "sidebar_col",
        class = "sidebar-col",
        
        h4("AI review verification"),
        
        div(
          class = "batch-picker",
          
          textInput(
            ns("batch_path"),
            "Batch folder",
            placeholder = "Paste the full path to your batch folder"
          ),
          
          actionButton(
            ns("load_batch_btn"),
            "Load",
            class = "btn-default btn-sm"
          ),
          
          uiOutput(ns("batch_picker_status"))
        ),
        
        tags$hr(),
        
        conditionalPanel(
          condition = "!output.has_batch",
          ns = ns,
          div(
            class = "no-data-placeholder",
            no_data_text
          )
        ),
        
        conditionalPanel(
          condition = "output.has_batch",
          ns = ns,
          
          textInput(
            ns("reviewer_name"),
            "Your name",
            placeholder = "required before saving"
          ),
          
          tags$hr(),
          
          uiOutput(ns("paper_list")),
          
          tags$hr(),
          
          checkboxInput(
            ns("flag_for_discussion"),
            "Flag this paper for discussion",
            value = FALSE
          ),
          
          textAreaInput(
            ns("note"),
            "Note",
            rows = 3
          ),
          
          helpText(
            "Flag/note are saved whichever Save button you use."
          ),
          
          uiOutput(ns("export_section"))
        )
      ),
      
      div(
        class = "main-col",
        
        conditionalPanel(
          condition = "!output.has_batch",
          ns = ns,
          
          div(
            class = "no-data-placeholder",
            no_data_text
          )
        ),
        
        conditionalPanel(
          condition = "output.has_batch",
          ns = ns,
          
          fluidRow(
            column(6, uiOutput(ns("pdf_frame"))),
            
            column(
              6,
              
              tabsetPanel(
                tabPanel(
                  "Extraction",
                  
                  div(
                    class = "tab-header",
                    
                    div(
                      class = "change-counter",
                      textOutput(
                        ns("extraction_change_count"),
                        inline = TRUE
                      )
                    ),
                    
                    uiOutput(
                      ns("extraction_status_badge"),
                      inline = TRUE
                    )
                  ),
                  
                  div(
                    class = "tab-scroll",
                    uiOutput(ns("extraction_fields"))
                  ),
                  
                  actionButton(
                    ns("save_extraction_btn"),
                    "Save extraction & continue",
                    class = "btn-primary save-section-btn"
                  )
                ),
                
                tabPanel(
                  "Quality Assessment",
                  
                  div(
                    class = "tab-header",
                    
                    div(
                      class = "change-counter",
                      textOutput(
                        ns("qa_change_count"),
                        inline = TRUE
                      )
                    ),
                    
                    uiOutput(
                      ns("qa_status_badge"),
                      inline = TRUE
                    )
                  ),
                  
                  div(
                    class = "tab-scroll",
                    uiOutput(ns("qa_items"))
                  ),
                  
                  actionButton(
                    ns("save_qa_btn"),
                    "Save QA & continue",
                    class = "btn-primary save-section-btn"
                  )
                )
              )
            )
          )
        )
      )
    )
  )
}
    
#' coreview_main Server Functions
#'
#' @noRd 
mod_coreview_main_server <- function(
    id,
    initial_batch_dir = NULL,
    reviewer = NULL
) {
  
  moduleServer(
    id,
    function(input, output, session) {
      
      # --------------------------------------------------
      # State
      # --------------------------------------------------
      
      batch_dir <- reactiveVal(NULL)
      
      paper_ids <- reactiveVal(character(0))
      
      paper_statuses <- reactiveVal(character(0))
      
      current_paper <- reactiveVal(NULL)
      
      rv_record <- reactiveVal(NULL)
      
      load_message <- reactiveVal(NULL)
      
      reviewer_prefilled <- reactiveVal(FALSE)

      # --------------------------------------------------
      # Helpers
      # --------------------------------------------------
      
      do_load <- function(path) {
        
        path <- trimws(path %||% "")
        
        if (path == "") {
          load_message(
            list(
              type = "err",
              text = "Enter a folder path first."
            )
          )
          return(invisible())
        }
        
        ok <- tryCatch(
          dir.exists(path),
          error = function(e) FALSE
        )
        
        if (!ok) {
          load_message(
            list(
              type = "err",
              text = "That folder doesn't exist."
            )
          )
          batch_dir(NULL)
          return(invisible())
        }
        
        path <- normalizePath(
          path,
          mustWork = TRUE
        )
        
        if (!is_batch_dir(path)) {
          
          load_message(
            list(
              type = "err",
              text = "No data — that folder needs an input/papers/ and input/to_review/ inside it."
            )
          )
          
          batch_dir(NULL)
          
          return(invisible())
        }
        
        ids <- list_paper_ids(path)
        
        if (length(ids) == 0) {
          
          load_message(
            list(
              type = "err",
              text = "No data — input/to_review/ is empty."
            )
          )
          
          batch_dir(NULL)
          
          return(invisible())
        }
        
        dir.create(
          file.path(path, "output", "completed"),
          recursive = TRUE,
          showWarnings = FALSE
        )
        
        dir.create(
          file.path(path, "output", "exports"),
          recursive = TRUE,
          showWarnings = FALSE
        )
        
        shiny::addResourcePath(
          "pdfs_",
          file.path(path, "input", "papers")
        )
        
        statuses <- vapply(
          ids,
          function(p) paper_status(path, p),
          character(1)
        )
        
        first_unfinished <- ids[
          statuses != "completed"
        ][1]
        
        batch_dir(path)
        paper_ids(ids)
        paper_statuses(statuses)
        
        current_paper(
          if (!is.na(first_unfinished))
            first_unfinished
          else
            ids[[1]]
        )
        
        load_message(
          list(
            type = "ok",
            text = sprintf(
              "Loaded %d paper(s).",
              length(ids)
            )
          )
        )
        
        updateTextInput(
          session,
          session$ns("batch_path"),
          value = path
        )
        
        if (!reviewer_prefilled()) {
          
          updateTextInput(
            session,
            session$ns("reviewer_name"),
            value = reviewer %||% ""
          )
          
          reviewer_prefilled(TRUE)
        }
      }

      save_extraction <- function() {
        
        req(rv_record())
        
        rec <- rv_record()
        
        for (f in EXTRACTION_FIELDS) {
          
          field_id <- paste0("ext_", f)
          
          print(list(
            field = field_id,
            value = input[[field_id]]
          ))
          
          rec$extraction[[f]]$reviewed <- input[[field_id]] %||% ""
          
        }
        
        rec$extraction_status <- "done"
        
        rec$reviewer <- input$reviewer_name %||% ""
        
        rec$flag_for_discussion <- isTRUE(
          input$flag_for_discussion
        )
        
        rec$note <- input$note %||% ""
        
        save_record(
          batch_dir(),
          rec
        )
        
        paper_statuses(
          vapply(
            paper_ids(),
            function(p) paper_status(batch_dir(), p),
            character(1)
          )
        )
        
        
        rv_record(rec)
        
      }
   

      # --------------------------------------------------
      # Outputs
      # --------------------------------------------------
      
      output$has_batch <- reactive({
        !is.null(batch_dir())
      })
      
      outputOptions(
        output,
        "has_batch",
        suspendWhenHidden = FALSE
      )
      
      output$batch_picker_status <- renderUI({
        
        m <- load_message()
        
        if (is.null(m)) {
          return(NULL)
        }
        
        div(
          class = paste(
            "batch-picker-status",
            if (identical(m$type, "ok"))
              "ok"
            else
              "err"
          ),
          m$text
        )
      })
      
      output$paper_list <- renderUI({
        ids <- paper_ids()
        statuses <- paper_statuses()
        
        make_link <- function(i) {
          p <- ids[[i]]
          st <- statuses[[i]]
          
          cls <- switch(
            st,
            completed = "done",
            partial = "partial",
            "pending"
          )
          
          actionLink(
            session$ns(paste0("goto_", make.names(p))),
            tagList(
              span(class = "status-dot"),
              span(p)
            ),
            class = paste("sidebar-paper", cls)
          )
        }
        
        pending_idx <- which(statuses == "pending")
        partial_idx <- which(statuses == "partial")
        done_idx <- which(statuses == "completed")
        
        tagList(
          if (length(pending_idx))
            tagList(
              div(
                class = "paper-group-title",
                sprintf(
                  "To review (%d)",
                  length(pending_idx)
                )
              ),
              lapply(pending_idx, make_link)
            ),
          
          if (length(partial_idx))
            tagList(
              div(
                class = "paper-group-title",
                sprintf(
                  "In progress (%d)",
                  length(partial_idx)
                )
              ),
              lapply(partial_idx, make_link)
            ),
          
          if (length(done_idx))
            tagList(
              div(
                class = "paper-group-title",
                sprintf(
                  "Completed (%d)",
                  length(done_idx)
                )
              ),
              lapply(done_idx, make_link)
            )
        )
      })
      
      output$pdf_frame <- renderUI({
        
        req(rv_record())
        
        rec <- rv_record()
        
        pdf_rel <- rec$pdf_file %||% ""
        
        if (pdf_rel == "") {
          return(
            div(
              class = "no-data-placeholder",
              "No PDF available."
            )
          )
        }
        
        tags$iframe(
          src = paste0(
            "/pdfs_/",
            basename(pdf_rel)
          ),
          width = "100%",
          height = "900px",
          style = "border:none;"
        )
        
      })
      
      output$extraction_fields <- renderUI({
        
        req(rv_record())
        
        rec <- rv_record()
        
        tagList(
          
          lapply(
            EXTRACTION_FIELDS,
            function(f) {
              
              tagAppendAttributes(
                
                textAreaInput(
                  inputId = session$ns(paste0("ext_", f)),
                  label = gsub("_", " ", f),
                  value = current_value(rec$extraction[[f]]) %||% "",
                  rows = extraction_field_rows(f)
                ),
                
                class = "review-box"
                
              )
              
            }
          )
          
        )
        
      })
      
      output$qa_items <- renderUI({
        
        req(rv_record())
        
        rec <- rv_record()
        
        tagList(
          
          lapply(
            QA_SECTIONS,
            function(sec) {
              
              tagList(
                
                tags$h4(
                  paste(sec$id, sec$title)
                ),
                
                lapply(
                  names(sec$items),
                  function(key) {
                    
                    item <- rec$qa[[key]]
                    
                    verdict <- current_qa_verdict(item)
                    
                    evidence <- item$ai_evidence %||% ""
                    
                    div(
                      class = "qa-item",
                      
                      tags$p(
                        strong(key),
                        " ",
                        sec$items[[key]]
                      ),
                      
                      selectInput(
                        inputId = session$ns(
                          paste0(
                            "qa_verdict_",
                            qa_id(key)
                          )
                        ),
                        label = "Verdict",
                        choices = qa_verdict_choices(key),
                        selected = verdict %||% "Unclear"
                      ),
                      
                      textAreaInput(
                        inputId = session$ns(
                          paste0(
                            "qa_evidence_",
                            qa_id(key)
                          )
                        ),
                        label = "Evidence",
                        value = evidence,
                        rows = 3
                      )
                      
                    )
                    
                  }
                )
                
              )
              
            }
          )
          
        )
        
      })
      
      # --------------------------------------------------
      # Navigation
      # --------------------------------------------------
      
      observeEvent(
        eventExpr = input$load_batch_btn,
        handlerExpr = {
          
          do_load(input$batch_path)
          
        },
        ignoreInit = TRUE
      )
      
      observeEvent(
        paper_ids(),
        {
          
          ids <- paper_ids()
          
          lapply(
            ids,
            function(p) {
              
              observeEvent(
                input[[paste0("goto_", make.names(p))]],
                {
                  current_paper(p)
                  
                },
                ignoreInit = TRUE
              )
              
            }
          )
          
        }
      )
     
      observeEvent(
        current_paper(),
        {
          
          req(batch_dir())
          req(current_paper())
          
          rec <- load_record(
            batch_dir(),
            current_paper()
          )
          
          rv_record(rec)

        },
        ignoreInit = FALSE
      )
      
      # --------------------------------------------------
      # Record Synchronisation
      # --------------------------------------------------
      
      observeEvent(
        rv_record(),
        {
          
          req(rv_record())
          
          rec <- rv_record()
          
          updateTextInput(
            session,
            session$ns("reviewer_name"),
            value = rec$reviewer %||% ""
          )
          
          updateCheckboxInput(
            session,
            session$ns("flag_for_discussion"),
            value = isTRUE(rec$flag_for_discussion)
          )
          
          updateTextAreaInput(
            session,
            session$ns("note"),
            value = rec$note %||% ""
          )
          
        },
        ignoreInit = TRUE
      )

      observeEvent(
        rv_record(),
        {
          
          rec <- rv_record()
          
          req(rec)
          
          later::later(
            function() {
              
              for (f in EXTRACTION_FIELDS) {
                
                session$sendCustomMessage(
                  "setAiBaseline",
                  list(
                    id = session$ns(paste0("ext_", f)),
                    ai = rec$extraction[[f]]$ai %||% ""
                  )
                )
                
              }
              
            },
            delay = 0.5
          )
          
        },
        ignoreInit = TRUE
      )
      
      observe({
        
        invalidateLater(2000)
        
        print(
          grep(
            "^ext_",
            names(input),
            value = TRUE
          )
        )
        
      })
      
      # --------------------------------------------------
      # Save Actions
      # --------------------------------------------------
      
      observeEvent(
        input$save_extraction_btn,
        {
          
          save_extraction()
          
          print(
            paste(
              "Saved extraction:",
              rv_record()$paper_id
            )
          )
          
        },
        ignoreInit = TRUE
      )
      
    }
  )
  
}


