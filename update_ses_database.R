#!/usr/bin/env Rscript

# ═══════════════════════════════════════════════════════════════════════════════════════
# SES PUBLICATIONS DATABASE - COMPREHENSIVE UPDATE SYSTEM
# ═══════════════════════════════════════════════════════════════════════════════════════
#
# This is the MAIN script for updating the SES Publications Database
# 
# What it does:
# ✓ Downloads current database and creates timestamped backups
# ✓ Fetches publications from Google Scholar for all faculty
# ✓ Updates citation counts for ALL existing publications  
# ✓ Identifies NEW publications from 2025+ only (avoids duplicates)
# ✓ Gets COMPLETE author lists (no more "..." truncation!)
# ✓ Enhanced faculty matching using first initials
# ✓ Improved student detection (handles "EJ Baransky" patterns)
# ✓ Filters non-peer-reviewed publications (conference abstracts, preprints, etc.)
# ✓ Adds Date_Added timestamps to track when entries were added
# ✓ Preserves verified records and manual curation
# ✓ Uploads clean results to Google Sheets
#
# Usage: Rscript update_ses_database.R
#
# ═══════════════════════════════════════════════════════════════════════════════════════

# Load required libraries
suppressPackageStartupMessages({
  library(googlesheets4)
  library(dplyr)
  library(stringr)
  library(scholar)
  library(lubridate)
  library(purrr)
})

cat("═══════════════════════════════════════════════════════════════════════════════════════\n")
cat("                    SES PUBLICATIONS DATABASE UPDATE SYSTEM                           \n")
cat("═══════════════════════════════════════════════════════════════════════════════════════\n")
cat("Started:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

# ═══════════════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════════════

PUBLICATIONS_SHEET <- "1HMUJzmD91MlU7zDpWqHmuPwsmjqJIzE5HjaBj3NAMEw"
STUDENTS_SHEET <- "1FuWlVun83yUZKl49r1o71MsZSKaD5Mw14n-ssmEpLVE"
CURRENT_YEAR <- year(Sys.Date())

# ═══════════════════════════════════════════════════════════════════════════════════════
# HELPER FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════════════

# Function to get complete author lists (fixes truncation issue)
get_complete_authors_safe <- function(scholar_id, pubid, current_author) {
  if(is.na(current_author) || !str_detect(current_author, "\\.\\.\\.")) {
    return(current_author)  # Return as-is if no truncation
  }
  
  tryCatch({
    cat("    [Fetching complete authors]...")
    complete_authors <- get_complete_authors(scholar_id, pubid = pubid)
    cat(" done\n")
    return(complete_authors)
  }, error = function(e) {
    cat(" failed\n")
    return(current_author)  # Return original if fetch fails
  })
}

# ═══════════════════════════════════════════════════════════════════════════════════════
# STEP 1: AUTHENTICATION AND DATA DOWNLOAD
# ═══════════════════════════════════════════════════════════════════════════════════════

cat("STEP 1: Connecting to Google Sheets and downloading current database...\n")
gs4_auth()

current_db <- read_sheet(PUBLICATIONS_SHEET, sheet = "Enhanced_Publications")
cat(sprintf("✓ Downloaded %d publications\n", nrow(current_db)))

verified_count <- sum(current_db$Verified == TRUE, na.rm = TRUE)
cat(sprintf("✓ %d verified records will be preserved\n", verified_count))

# Create timestamped backup
backup_file <- sprintf("database_backup_%s.rds", format(Sys.time(), "%Y%m%d_%H%M%S"))
saveRDS(current_db, backup_file)
cat(sprintf("✓ Backup saved: %s\n", backup_file))

# ═══════════════════════════════════════════════════════════════════════════════════════
# STEP 2: LOAD FACULTY AND STUDENT DATA
# ═══════════════════════════════════════════════════════════════════════════════════════

cat("\nSTEP 2: Loading faculty and student data...\n")

# Load faculty data with first initials
faculty_data <- read.csv("facultygooglescholarids.csv") %>%
  rename(FirstInitial = `First.Initial`, LastName = `Last.Name`) %>%
  mutate(
    FullName = paste(FirstInitial, LastName),
    EndYear = ifelse(is.na(EndYear), CURRENT_YEAR, EndYear)
  ) %>%
  filter(!is.na(ID), ID != "")

cat(sprintf("✓ Loaded %d faculty members with Google Scholar IDs\n", nrow(faculty_data)))

# Load student data
source("R/load_students.R")
all_students <- load_students(STUDENTS_SHEET)
cat(sprintf("✓ Loaded %d students\n", nrow(all_students)))

# ═══════════════════════════════════════════════════════════════════════════════════════
# STEP 3: FETCH PUBLICATIONS FROM GOOGLE SCHOLAR
# ═══════════════════════════════════════════════════════════════════════════════════════

cat("\nSTEP 3: Fetching publications from Google Scholar...\n")
all_scholar_pubs <- data.frame()

for(i in 1:nrow(faculty_data)) {
  faculty <- faculty_data[i, ]
  cat(sprintf("  %s %s... ", faculty$FirstInitial, faculty$LastName))
  
  tryCatch({
    pubs <- get_publications(faculty$ID)
    if(nrow(pubs) > 0) {
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

# ═══════════════════════════════════════════════════════════════════════════════════════
# STEP 4: UPDATE CITATION COUNTS
# ═══════════════════════════════════════════════════════════════════════════════════════

cat("\nSTEP 4: Updating citation counts for all existing publications...\n")
citation_updates <- 0

# Create lookup table for faster matching
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

# ═══════════════════════════════════════════════════════════════════════════════════════
# STEP 5: IDENTIFY AND PROCESS NEW 2025+ PUBLICATIONS
# ═══════════════════════════════════════════════════════════════════════════════════════

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

# Process new publications
genuinely_new <- data.frame()

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
      cites = max(cites, na.rm = TRUE),
      pubid = first(pubid),
      combined_faculty = paste(unique(paste(source_first_initial, source_last_name)), collapse = ", "),
      source_id = first(source_id),
      .groups = 'drop'
    ) %>%
    mutate(source_faculty = combined_faculty)
  
  internal_dups_removed <- nrow(recent_pubs) - nrow(deduplicated_recent)
  cat(sprintf("✓ Removed %d internal duplicates from 2025+ publications\n", internal_dups_removed))
  
  # Filter against existing database
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
  
  # STEP 5.5: Get complete author information for new publications
  if(nrow(genuinely_new) > 0) {
    cat("Getting complete author information (removing '...' truncation)...\n")
    
    truncated_count <- sum(str_detect(genuinely_new$author, "\\.\\.\\."), na.rm = TRUE)
    if(truncated_count > 0) {
      cat(sprintf("Found %d publications with truncated authors, fetching complete lists...\n", truncated_count))
      
      for(i in 1:nrow(genuinely_new)) {
        if(str_detect(genuinely_new$author[i], "\\.\\.\\.")) {
          cat(sprintf("  %d/%d: %s...", i, nrow(genuinely_new), substr(genuinely_new$title[i], 1, 50)))
          genuinely_new$author[i] <- get_complete_authors_safe(
            genuinely_new$source_id[i], 
            genuinely_new$pubid[i], 
            genuinely_new$author[i]
          )
          Sys.sleep(1)  # Rate limiting
        }
      }
      cat("✓ Complete author information retrieved\n")
    } else {
      cat("✓ No truncated author lists found\n")
    }
  }
}

# ═══════════════════════════════════════════════════════════════════════════════════════
# STEP 6: PROCESS NEW PUBLICATIONS WITH ENHANCED MATCHING
# ═══════════════════════════════════════════════════════════════════════════════════════

new_records <- data.frame()

if(nrow(genuinely_new) > 0) {
  cat("\nSTEP 6: Processing new publications with enhanced matching...\n")
  
  # Enhanced faculty matching using first initials
  extract_faculty_with_initials <- function(authors, pre_combined_faculty = NULL) {
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
      
      if(nchar(last_name) < 3) next
      
      patterns <- c(
        paste0("\\b", first_initial, "\\s*\\.?\\s*", last_name, "\\b"),
        paste0("\\b", last_name, "\\b.*\\b", first_initial, "\\b"),
        paste0("\\b", first_initial, "[a-z]*\\s+", last_name, "\\b")
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

# ═══════════════════════════════════════════════════════════════════════════════════════
# STEP 7: CREATE FINAL DATABASE
# ═══════════════════════════════════════════════════════════════════════════════════════

cat("\nSTEP 7: Creating updated database...\n")
if(nrow(new_records) > 0) {
  # Ensure Date_Added column exists in current_db and is character type
  if(!"Date_Added" %in% names(current_db)) {
    current_db$Date_Added <- NA_character_
  } else {
    current_db$Date_Added <- as.character(current_db$Date_Added)
  }
  
  final_db <- bind_rows(current_db, new_records) %>%
    arrange(desc(Year), Title)
} else {
  final_db <- current_db %>%
    arrange(desc(Year), Title)
}

# ═══════════════════════════════════════════════════════════════════════════════════════
# STEP 8: UPLOAD TO GOOGLE SHEETS
# ═══════════════════════════════════════════════════════════════════════════════════════

cat("\nSTEP 8: Uploading updated database to Google Sheets...\n")
tryCatch({
  write_sheet(final_db, ss = PUBLICATIONS_SHEET, sheet = "Enhanced_Publications")
  cat("✓ Successfully updated Google Sheets\n")
}, error = function(e) {
  cat("✗ Error uploading to Google Sheets:\n")
  print(e)
  cat("✗ Database saved locally as 'updated_database_emergency.csv'\n")
  write.csv(final_db, "updated_database_emergency.csv", row.names = FALSE)
})

# ═══════════════════════════════════════════════════════════════════════════════════════
# FINAL SUMMARY
# ═══════════════════════════════════════════════════════════════════════════════════════

cat("\n═══════════════════════════════════════════════════════════════════════════════════════\n")
cat("                                 UPDATE SUMMARY                                       \n")
cat("═══════════════════════════════════════════════════════════════════════════════════════\n")
cat(sprintf("Total publications in database: %d\n", nrow(final_db)))
cat(sprintf("New 2025+ publications added: %d\n", ifelse(exists("new_records"), nrow(new_records), 0)))
cat(sprintf("Citation counts updated: %d\n", citation_updates))
cat(sprintf("Verified records preserved: %d\n", verified_count))
if(exists("excluded_count")) {
  cat(sprintf("Non-peer-reviewed publications filtered: %d\n", excluded_count))
}
cat(sprintf("Database backup created: %s\n", backup_file))
cat("Completed:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("═══════════════════════════════════════════════════════════════════════════════════════\n")

cat("\n✅ SES Publications Database update complete!\n\n")

# Clean up backup file after successful completion
if(file.exists(backup_file)) {
  file.remove(backup_file)
  cat("✓ Backup file cleaned up\n")
}

cat("🎉 Ready for website generation and reporting!\n")