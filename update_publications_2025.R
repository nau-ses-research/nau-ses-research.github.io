#!/usr/bin/env Rscript

# STREAMLINED PUBLICATION UPDATE SYSTEM
# Only adds publications from 2025 or newer
# Updates all citation counts
# Preserves verified records except for citation updates

library(googlesheets4)
library(dplyr)
library(stringr)
library(scholar)
library(lubridate)

cat("=== STREAMLINED SES PUBLICATIONS UPDATE ===\n")
cat("Adding 2025+ publications and updating all citation counts\n")
cat("Started:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

# Configuration
PUBLICATIONS_SHEET <- "1HMUJzmD91MlU7zDpWqHmuPwsmjqJIzE5HjaBj3NAMEw"
STUDENTS_SHEET <- "1FuWlVun83yUZKl49r1o71MsZSKaD5Mw14n-ssmEpLVE"
CURRENT_YEAR <- year(Sys.Date())

# Authenticate
gs4_auth()

# Step 1: Download current database
cat("STEP 1: Downloading current database...\n")
current_db <- read_sheet(PUBLICATIONS_SHEET, sheet = "Enhanced_Publications")
cat(sprintf("✓ Downloaded %d publications\n", nrow(current_db)))

verified_count <- sum(current_db$Verified == TRUE, na.rm = TRUE)
cat(sprintf("✓ %d verified records will be preserved\n", verified_count))

# Create timestamped backup (safe format)
backup_file <- sprintf("backup_%s.rds", format(Sys.time(), "%Y%m%d_%H%M%S"))
saveRDS(current_db, backup_file)
cat(sprintf("✓ Backup saved: %s\n", backup_file))

# Step 2: Load faculty data with first initials
cat("\nSTEP 2: Loading faculty data...\n")
faculty_data <- read.csv("facultygooglescholarids.csv") %>%
  rename(FirstInitial = `First.Initial`, LastName = `Last.Name`) %>%
  mutate(
    FullName = paste(FirstInitial, LastName),
    EndYear = ifelse(is.na(EndYear), CURRENT_YEAR, EndYear)
  ) %>%
  filter(!is.na(ID), ID != "")  # Only process faculty with Scholar IDs

cat(sprintf("✓ Loaded %d faculty members with Google Scholar IDs\n", nrow(faculty_data)))

# Load student data
source("R/load_students.R")
all_students <- load_students(STUDENTS_SHEET)
cat(sprintf("✓ Loaded %d students\n", nrow(all_students)))

# Step 3: Fetch ALL publications from Google Scholar (for citation updates)
cat("\nSTEP 3: Fetching publications from Google Scholar...\n")
all_scholar_pubs <- data.frame()

for(i in 1:nrow(faculty_data)) {
  faculty <- faculty_data[i, ]
  cat(sprintf("  %s %s... ", faculty$FirstInitial, faculty$LastName))
  
  tryCatch({
    pubs <- get_publications(faculty$ID)
    if(nrow(pubs) > 0) {
      # Filter by year range and add metadata
      pubs <- pubs %>%
        filter(year >= faculty$StartYear & year <= faculty$EndYear) %>%
        mutate(
          simpleTitle = tolower(str_remove_all(title, "[^A-Za-z0-9]")),
          source_faculty = faculty$FullName,
          source_id = faculty$ID,
          source_first_initial = faculty$FirstInitial,
          source_last_name = faculty$LastName
        )
      
      all_scholar_pubs <- bind_rows(all_scholar_pubs, pubs)
      cat(sprintf("%d pubs\n", nrow(pubs)))
    } else {
      cat("0 pubs\n")
    }
    
    Sys.sleep(1)  # Rate limiting
    
  }, error = function(e) {
    cat("ERROR\n")
  })
}

cat(sprintf("✓ Collected %d total publications from Google Scholar\n", nrow(all_scholar_pubs)))

# Step 4: Update citation counts for all existing publications
cat("\nSTEP 4: Updating citation counts...\n")
citation_updates <- 0

# Create lookup table for faster matching (using ALL publications, not just recent)
citation_lookup <- all_scholar_pubs %>%
  group_by(simpleTitle) %>%
  summarise(max_citations = max(cites, na.rm = TRUE), .groups = 'drop')

cat(sprintf("Created citation lookup with %d unique titles\n", nrow(citation_lookup)))

# Update citations
for(i in 1:nrow(current_db)) {
  if(i %% 200 == 0) cat(".")
  
  if(!is.na(current_db$simpleTitle[i]) && current_db$simpleTitle[i] != "") {
    lookup_result <- citation_lookup[citation_lookup$simpleTitle == current_db$simpleTitle[i], ]
    
    if(nrow(lookup_result) > 0 && !is.na(lookup_result$max_citations[1]) && lookup_result$max_citations[1] >= 0) {
      new_citations <- lookup_result$max_citations[1]
      old_citations <- ifelse(is.na(current_db$Citations[i]), 0, current_db$Citations[i])
      
      if(new_citations != old_citations) {
        current_db$Citations[i] <- new_citations
        citation_updates <- citation_updates + 1
      }
    }
  }
}

cat(sprintf(" done\n✓ Updated citations for %d publications\n", citation_updates))

# Step 5: Identify NEW publications from 2025 or later
cat("\nSTEP 5: Identifying new 2025+ publications...\n")
recent_pubs <- all_scholar_pubs %>%
  filter(year >= 2025)

cat(sprintf("Found %d publications from 2025+\n", nrow(recent_pubs)))

# Function to filter non-peer-reviewed publications
is_excluded_publication <- function(journal_name) {
  if(is.na(journal_name) || journal_name == "") return(FALSE)
  
  exclusion_patterns <- c(
    # Conference abstracts and proceedings
    "meeting", "abstracts", "conference", "joint", "abstract", "symposium",
    "proceedings", "workshop", "congress", "summit",
    # Preprints and non-peer-reviewed
    "rxiv", "preprint", "nsf award"
  )
  
  journal_lower <- tolower(journal_name)
  return(any(sapply(exclusion_patterns, function(p) str_detect(journal_lower, p))))
}

# First, deduplicate within the new publications (same paper from multiple faculty)
if(nrow(recent_pubs) > 0) {
  cat("Deduplicating within 2025+ publications...\n")
  
  # Group by simpleTitle and merge faculty information
  deduplicated_recent <- recent_pubs %>%
    group_by(simpleTitle) %>%
    summarise(
      title = first(title),
      author = first(author),
      journal = first(journal),
      number = first(number),
      year = first(year),
      cites = max(cites, na.rm = TRUE),  # Take highest citation count
      pubid = first(pubid),
      # Combine all faculty sources for this publication
      combined_faculty = paste(unique(paste(source_first_initial, source_last_name)), collapse = ", "),
      combined_source_ids = paste(unique(source_id), collapse = ", "),
      .groups = 'drop'
    ) %>%
    mutate(
      source_faculty = combined_faculty,
      source_id = first(str_split(combined_source_ids, ", ")[[1]])  # Use first ID for Scholar_ID_Source
    )
  
  internal_dups_removed <- nrow(recent_pubs) - nrow(deduplicated_recent)
  cat(sprintf("✓ Removed %d internal duplicates from 2025+ publications\n", internal_dups_removed))
  
  # Now filter against existing database
  existing_titles <- current_db$simpleTitle[!is.na(current_db$simpleTitle)]
  genuinely_new <- deduplicated_recent[!deduplicated_recent$simpleTitle %in% existing_titles, ]
  
  external_dups_filtered <- nrow(deduplicated_recent) - nrow(genuinely_new)
  cat(sprintf("✓ Filtered %d publications that already exist in database\n", external_dups_filtered))
  
  # Filter out non-peer-reviewed publications
  if(nrow(genuinely_new) > 0) {
    pre_filter_count <- nrow(genuinely_new)
    genuinely_new <- genuinely_new[!sapply(genuinely_new$journal, is_excluded_publication), ]
    excluded_count <- pre_filter_count - nrow(genuinely_new)
    cat(sprintf("✓ Filtered out %d non-peer-reviewed publications (conference abstracts, preprints, etc.)\n", excluded_count))
  }
  
  cat(sprintf("✓ %d final publications to add\n", nrow(genuinely_new)))
} else {
  genuinely_new <- data.frame()
}

# Step 6: Process new publications with enhanced faculty matching
if(nrow(genuinely_new) > 0) {
  cat("\nSTEP 6: Processing new publications...\n")
  
  # Enhanced faculty matching using first initials
  extract_faculty_with_initials <- function(authors, pre_combined_faculty = NULL) {
    # If we already have combined faculty from deduplication, use that as starting point
    if(!is.null(pre_combined_faculty) && !is.na(pre_combined_faculty) && pre_combined_faculty != "") {
      return(pre_combined_faculty)
    }
    
    if(is.na(authors) || authors == "") return("")
    
    author_lower <- tolower(str_replace_all(authors, "[^a-zA-Z, .]", ""))
    faculty_matches <- c()
    
    for(j in 1:nrow(faculty_data)) {
      faculty <- faculty_data[j, ]
      first_initial <- tolower(faculty$FirstInitial)
      last_name <- tolower(faculty$LastName)
      
      # Skip very short last names
      if(nchar(last_name) < 3) next
      
      # Look for patterns like "D Kaufman", "D. Kaufman", or "Darrell Kaufman"
      patterns <- c(
        paste0("\\b", first_initial, "\\s*\\.?\\s*", last_name, "\\b"),  # "D Kaufman" or "D. Kaufman"
        paste0("\\b", last_name, "\\b.*\\b", first_initial, "\\b"),      # "Kaufman, D"
        paste0("\\b", first_initial, "[a-z]*\\s+", last_name, "\\b")     # "Darrell Kaufman"
      )
      
      if(any(sapply(patterns, function(p) str_detect(author_lower, p)))) {
        faculty_matches <- c(faculty_matches, faculty$FullName)
      }
    }
    
    return(paste(unique(faculty_matches), collapse = ", "))
  }
  
  # Enhanced graduate student matching function
  match_grad_students <- function(authors, pub_year) {
    if(is.na(authors) || authors == "") return("")
    
    authors_clean <- str_replace_all(authors, "[^a-zA-Z, ]", "")
    authors_lower <- tolower(authors_clean)
    matches <- c()
    
    for(k in 1:nrow(all_students)) {
      student <- all_students[k, ]
      first <- tolower(student$First)
      last <- tolower(student$Last)
      
      if(nchar(first) < 2 || nchar(last) < 3) next
      if(!str_detect(authors_lower, paste0("\\b", last, "\\b"))) next
      
      first_initial <- substr(first, 1, 1)
      
      # Enhanced patterns including middle initials (fixes Eva Baransky issue)
      patterns <- c(
        paste0("\\b", first, "\\s+", last, "\\b"),                    # "Eva Baransky"
        paste0("\\b", first_initial, "\\s+", last, "\\b"),            # "E Baransky"
        paste0("\\b", first_initial, "[a-z]\\s+", last, "\\b"),       # "EJ Baransky"
        paste0("\\b", first_initial, "[a-z]+\\s+", last, "\\b"),      # "Eva Baransky" (full first)
        paste0("\\b", last, "\\s*,\\s*", first_initial, "\\b"),       # "Baransky, E"
        paste0("\\b", last, "\\s*,\\s*", first_initial, "[a-z]\\b")   # "Baransky, EJ"
      )
      
      if(any(sapply(patterns, function(p) str_detect(authors_lower, p)))) {
        timeline_ok <- is.na(student$start_year) || is.na(pub_year) || pub_year >= student$start_year
        if(timeline_ok) {
          proper_name <- paste(str_to_title(student$First), str_to_title(student$Last))
          matches <- c(matches, proper_name)
        }
      }
    }
    
    return(paste(unique(matches), collapse = ", "))
  }
  
  # Process new publications
  new_records <- genuinely_new %>%
    mutate(
      Title = title,
      Authors = author,
      Journal = journal,
      Number = number,
      Year = year,
      Citations = cites,
      SES_Faculty = mapply(extract_faculty_with_initials, author, source_faculty, SIMPLIFY = TRUE),
      SES_Grad_Students = mapply(match_grad_students, author, year),
      SES_Undergrad_Students = "",  # For manual entry
      Verified = FALSE,
      Additional_Notes = "",
      Include_In_Reports = TRUE,
      PubID = pubid,
      Scholar_ID_Source = source_id,
      Date_Added = format(Sys.Date(), "%Y-%m-%d"),  # Add current date
      simpleTitle = simpleTitle
    ) %>%
    select(Title, Authors, Journal, Number, Year, Citations, SES_Faculty, 
           SES_Grad_Students, SES_Undergrad_Students, Verified, Additional_Notes, 
           Include_In_Reports, PubID, Scholar_ID_Source, Date_Added, simpleTitle)
  
  cat(sprintf("✓ Processed %d new publications\n", nrow(new_records)))
}

# Step 7: Create final database
cat("\nSTEP 7: Creating updated database...\n")
if(nrow(genuinely_new) > 0) {
  # Ensure Date_Added column exists in current_db and is character type
  if(!"Date_Added" %in% names(current_db)) {
    current_db$Date_Added <- NA_character_
  } else {
    # Convert Date_Added to character if it's datetime
    current_db$Date_Added <- as.character(current_db$Date_Added)
  }
  
  final_db <- bind_rows(current_db, new_records) %>%
    arrange(desc(Year), Title)
} else {
  final_db <- current_db %>%
    arrange(desc(Year), Title)
}

# Step 8: Upload to Google Sheets
cat("\nSTEP 8: Uploading to Google Sheets...\n")
tryCatch({
  write_sheet(final_db, ss = PUBLICATIONS_SHEET, sheet = "Enhanced_Publications")
  cat("✓ Successfully updated Google Sheets\n")
}, error = function(e) {
  cat("✗ Error uploading to Google Sheets:\n")
  print(e)
})

# Final summary
cat(sprintf("\n=== UPDATE SUMMARY ===\n"))
cat(sprintf("Total publications: %d\n", nrow(final_db)))
cat(sprintf("New 2025+ publications added: %d\n", ifelse(exists("new_records"), nrow(new_records), 0)))
cat(sprintf("Citation updates: %d\n", citation_updates))
cat(sprintf("Verified records preserved: %d\n", verified_count))
cat(sprintf("Backup created: %s\n", backup_file))
cat("Completed:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")

cat("\n✓ Streamlined update complete!\n")