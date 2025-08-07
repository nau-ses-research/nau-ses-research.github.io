# Helper function to load student data
# This is sourced by update_database.R

library(googlesheets4)
library(dplyr)
library(stringr)

load_students <- function(students_sheet_id = "1FuWlVun83yUZKl49r1o71MsZSKaD5Mw14n-ssmEpLVE") {
  
  # Load alumni
  alumni <- read_sheet(students_sheet_id, sheet = "Alumni") %>%
    rename(First = FIRST, Last = LAST) %>%
    filter(!is.na(First), !is.na(Last), First != "", Last != "") %>%
    mutate(
      full_name = paste(First, Last),
      start_year = case_when(
        str_detect(toupper(DEGREE), "PHD|DOCTOR") ~ YEAR - 5,
        str_detect(toupper(DEGREE), "MS|MASTER") ~ YEAR - 2,
        TRUE ~ YEAR - 3
      ),
      advisor = Advisor
    ) %>%
    select(full_name, First, Last, advisor, start_year)
  
  # Helper to parse years from start semester
  parse_year <- function(s) {
    if(is.na(s)) return(NA)
    year_match <- str_extract(s, "\\d{2,4}")
    if(is.na(year_match)) return(NA)
    year_num <- as.numeric(year_match)
    if(year_num < 100) year_num <- 2000 + year_num
    year_num
  }
  
  # Load current students
  get_current <- function(sheet) {
    data <- read_sheet(students_sheet_id, sheet = sheet)
    data %>%
      filter(!is.na(First), !is.na(Last)) %>%
      mutate(
        full_name = paste(First, Last),
        advisor = if("Advisor" %in% names(data)) Advisor else NA,
        start_year = if("Start Semester" %in% names(data)) sapply(`Start Semester`, parse_year) else NA
      ) %>%
      select(full_name, First, Last, advisor, start_year)
  }
  
  current_students <- bind_rows(
    get_current("Current ESP"), get_current("Current GLG"),
    get_current("Current PhD"), get_current("Current CSS")
  )
  
  # Combine and exclude Nicholas McKay and Lisa Thompson
  all_students <- bind_rows(alumni, current_students) %>%
    distinct(full_name, .keep_all = TRUE) %>%
    filter(!(First == "Nicholas" & Last == "McKay")) %>%
    filter(!(First == "Lisa" & Last == "Thompson"))
  
  return(all_students)
}