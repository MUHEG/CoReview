
EXTRACTION_FIELDS <- c(
  "Author_Year", "Country", "Population", "Type_of_EE", "Time_Horizon",
  "Perspective", "Study_Design_n", "Year_of_Pricing", "Discounting",
  "Cost_Components", "Consequence_Measures", "Intervention_Type",
  "Comparator", "Results"
)

# Extraction fields are short (a phrase or short list) except these two,
# which routinely hold a paragraph -- sized so the box roughly fits what's
# actually typically there instead of every field getting the same box.
EXTRACTION_FIELD_ROWS <- c(Consequence_Measures = 2, Results = 5)
extraction_field_rows <- function(field) {
  v <- unname(EXTRACTION_FIELD_ROWS[field])
  if (is.na(v)) 1 else v
}