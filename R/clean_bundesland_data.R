#' clean data
#' @param .data raw data frame of sheet "Presse"
#' @return cleaned data in wide format
#' @description cleans column names, removes * from Bundesland column, merges Bundesland ISO code and removes "Gesamt"
#' and comment rows at the end of the table. Returns one row for each Bundesland.
#' @importFrom rlang .data
#' @importFrom tidyr unite
rki_clean_bundesland <- function(.data) {

  # clean column names
  tmp <- .data %>%
    janitor::clean_names()

  # bundeslaender
  bundeslaender <- tmp %>%
      dplyr::slice_head(n = 16)

  ## get annotations
  annotations <- tmp %>%
    dplyr::filter(stringr::str_starts(.data$bundesland, "\\*")) %>%
    janitor::remove_empty("cols")

  if (nrow(annotations) > 0) {
    annotations <- annotations %>%
      dplyr::rename(annotation = .data$bundesland) %>%
      dplyr::mutate(star_count = stringr::str_count(.data$annotation, "\\*"),
                    annotation = stringr::str_trim(stringr::str_replace_all(.data$annotation, "\\*", "")))
    # join annotations
    bundeslaender <- bundeslaender %>%
      dplyr::mutate(star_count = stringr::str_count(.data$bundesland, "\\*")) %>%
      dplyr::left_join(annotations, by = "star_count")
    # remove * from bundesland name column and clean up after join
    bundeslaender <- bundeslaender  %>%
      dplyr::mutate(bundesland = stringr::str_trim(stringr::str_replace_all(.data$bundesland, "\\*", ""))) %>%
      dplyr::rename(notes = annotation) %>%
      dplyr::select(-star_count)
  } else {
    # no annotations, add empty notes column
    bundeslaender$notes <- NA
  }

  # treat all "x" columns as additional, unnamed notes columns
  if (any(stringr::str_detect(colnames(bundeslaender), "^x\\d{1,}$"))) {
    bundeslaender <- bundeslaender  %>% 
        tidyr::unite("notes_col", dplyr::matches("^x\\d{1,}$"), remove = TRUE, na.rm = TRUE, sep = "\n") %>% 
        tidyr::unite("notes", notes, notes_col, remove = TRUE, na.rm = TRUE, sep = "\n") %>% 
        dplyr::mutate(notes = dplyr::if_else(notes == "", NA_character_, stringr::str_trim(notes)))
  }

  # join iso code
  mapping <- vaccc19de::BUNDESLAND_TO_ISO
  merged <- dplyr::inner_join(mapping, bundeslaender, by = "bundesland")

  if (any(is.na(merged$bundesland_iso))) {
    usethis::ui_warn("Not all Bundeslaender could be matched to ISO codes.")
  }
  return(merged)
}
