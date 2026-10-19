#' The application server-side
#'
#' @param input,output,session Internal parameters for {shiny}.
#'     DO NOT REMOVE.
#' @import shiny
#' @importFrom golem get_golem_options
#' @noRd
app_server <- function(input, output, session) {

  mod_CoReview_main_server(
    "CoReview_main_1",
    initial_batch_dir = golem::get_golem_options("batch_dir"),
    reviewer = golem::get_golem_options("reviewer")
  )

}
