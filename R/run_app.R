#' Run the Shiny Application
#'
#' @param ... Arguments passed to golem_opts, retrieved inside the app via
#'   `golem::get_golem_options()`. Two are recognised:
#'   \describe{
#'     \item{`batch_dir`}{Path to a `batch_N/` folder (as written by
#'       \code{\link{split_for_review}}) to open immediately. Without it,
#'       the app opens with a folder picker instead.}
#'     \item{`reviewer`}{Reviewer name to pre-fill on save. Without it,
#'       the reviewer types their own name in the app.}
#'   }
#'   See `?golem::get_golem_options` for more details.
#' @inheritParams shiny::shinyApp
#'
#' @examples
#' \dontrun{
#' run_app()
#' run_app(batch_dir = "review_batches/batch_1", reviewer = "Jane Doe")
#' }
#'
#' @export
#' @importFrom shiny shinyApp
#' @importFrom golem with_golem_options
run_app <- function(
	onStart = NULL,
	options = list(),
	enableBookmarking = NULL,
	uiPattern = "/",
	...
) {
	with_golem_options(
		app = shinyApp(
			ui = app_ui,
			server = app_server,
			onStart = onStart,
			options = options,
			enableBookmarking = enableBookmarking,
			uiPattern = uiPattern
		),
		golem_opts = list(...)
	)
}
