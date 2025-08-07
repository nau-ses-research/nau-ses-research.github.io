#!/usr/bin/env Rscript

# UPDATE ALL FACULTY MATCHING WITH ENHANCED SYSTEM
# Re-analyze all publications using the improved first initial + last name matching

library(googlesheets4)
library(dplyr)
library(stringr)

cat("=== UPDATE ALL FACULTY MATCHING ===\n")
cat("Re-analyzing ALL publications with enhanced first initial + last name matching\n")
cat("Started:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

PUBLICATIONS_SHEET <- "1HMUJzmD91MlU7zDpWqHmuPwsmjqJIzE5HjaBj3NAMEw"

# Authenticate
gs4_auth()

# Step 1: Download current database
cat("STEP 1: Downloading current database...\n")
current_db <- read_sheet(PUBLICATIONS_SHEET, sheet = "Enhanced_Publications")
cat(sprintf("✓ Downloaded %d publications\n", nrow(current_db)))

verified_count <- sum(current_db$Verified == TRUE, na.rm = TRUE)
cat(sprintf("✓ %d verified records (faculty info will be updated but verification preserved)\n", verified_count))

# Create backup
backup_file <- sprintf("faculty_update_backup_%s.csv", format(Sys.time(), "%Y%m%d_%H%M%S"))
write.csv(current_db, backup_file, row.names = FALSE)
cat(sprintf("✓ Backup saved: %s\n", backup_file))

# Step 2: Load enhanced faculty data
cat("\nSTEP 2: Loading enhanced faculty data...\n")
faculty_data <- read.csv("facultygooglescholarids.csv") %>%
  rename(FirstInitial = `First.Initial`, LastName = `Last.Name`) %>%
  mutate(FullName = paste(FirstInitial, LastName)) %>%
  filter(!is.na(LastName), LastName != "")  # Include all faculty, even those without Scholar IDs

cat(sprintf("✓ Loaded %d faculty members for matching\n", nrow(faculty_data)))

# Step 3: Enhanced faculty matching function
cat("\nSTEP 3: Setting up enhanced faculty matching...\n")

extract_faculty_enhanced <- function(authors) {
  if(is.na(authors) || authors == "" || is.null(authors)) return("")
  
  # Clean the author string
  author_lower <- tolower(str_replace_all(authors, "[^a-zA-Z, .]", ""))
  faculty_matches <- c()
  
  for(i in 1:nrow(faculty_data)) {
    faculty <- faculty_data[i, ]
    first_initial <- tolower(faculty$FirstInitial)
    last_name <- tolower(faculty$LastName)
    
    # Skip very short last names to avoid false matches
    if(nchar(last_name) < 3) next
    
    # Multiple matching strategies with first initial requirements
    patterns <- c(
      # "D Kaufman", "D. Kaufman", "D.S. Kaufman"
      paste0("\\b", first_initial, "\\s*\\.?\\s*[a-z]*\\s*", last_name, "\\b"),
      # "Kaufman, D", "Kaufman, DS", "Kaufman, D.S."
      paste0("\\b", last_name, "\\s*,\\s*", first_initial, "[a-z\\.\\s]*\\b"),
      # Full names like "Darrell Kaufman", "David Kaufman" 
      paste0("\\b", first_initial, "[a-z]{2,}\\s+", last_name, "\\b"),
      # Middle initial patterns "D S Kaufman", "D. S. Kaufman"
      paste0("\\b", first_initial, "\\s*\\.?\\s*[a-z]\\s*\\.?\\s*", last_name, "\\b")
    )
    
    # Check if any pattern matches
    if(any(sapply(patterns, function(p) str_detect(author_lower, p)))) {
      faculty_matches <- c(faculty_matches, faculty$FullName)
    }
  }
  
  return(paste(unique(faculty_matches), collapse = ", "))
}

# Step 4: Process all publications in batches
cat("\nSTEP 4: Re-analyzing faculty matches for all publications...\n")

batch_size <- 200
n_batches <- ceiling(nrow(current_db) / batch_size)
updated_faculty <- character(nrow(current_db))

for(b in 1:n_batches) {
  start_idx <- (b-1) * batch_size + 1
  end_idx <- min(b * batch_size, nrow(current_db))
  
  # Process batch
  batch_results <- sapply(current_db$Authors[start_idx:end_idx], extract_faculty_enhanced)
  updated_faculty[start_idx:end_idx] <- batch_results
  
  if(b %% 5 == 0 || b == n_batches) {
    cat(sprintf("  Processed batch %d/%d\n", b, n_batches))
  }
}

# Step 5: Compare results and update
cat("\nSTEP 5: Analyzing improvements...\n")

# Create updated database
updated_db <- current_db %>%
  mutate(SES_Faculty_OLD = SES_Faculty,  # Keep old version for comparison
         SES_Faculty = updated_faculty)

# Count improvements
old_with_faculty <- sum(current_db$SES_Faculty != "" & !is.na(current_db$SES_Faculty))
new_with_faculty <- sum(updated_db$SES_Faculty != "" & !is.na(updated_db$SES_Faculty))
improvements <- new_with_faculty - old_with_faculty

cat(sprintf("Faculty matching results:\n"))
cat(sprintf("  Before: %d publications with faculty identified\n", old_with_faculty))
cat(sprintf("  After:  %d publications with faculty identified\n", new_with_faculty))
cat(sprintf("  Improvement: +%d publications\n", improvements))

# Show sample improvements
improved_pubs <- updated_db[
  (is.na(updated_db$SES_Faculty_OLD) | updated_db$SES_Faculty_OLD == "") & 
  (updated_db$SES_Faculty != "" & !is.na(updated_db$SES_Faculty)), 
]

if(nrow(improved_pubs) > 0) {
  cat(sprintf("\nSample newly identified faculty matches:\n"))
  for(i in 1:min(5, nrow(improved_pubs))) {
    cat(sprintf("%d. %s (%d) - %s\n", i, 
               substr(improved_pubs$Title[i], 1, 50),
               improved_pubs$Year[i], 
               improved_pubs$SES_Faculty[i]))
  }
}

# Show sample changes (where old had faculty but new is different)
changed_pubs <- updated_db[
  !is.na(updated_db$SES_Faculty_OLD) & updated_db$SES_Faculty_OLD != "" &
  updated_db$SES_Faculty != updated_db$SES_Faculty_OLD,
]

if(nrow(changed_pubs) > 0) {
  cat(sprintf("\nSample updated faculty assignments:\n"))
  for(i in 1:min(3, nrow(changed_pubs))) {
    cat(sprintf("%d. %s (%d)\n", i, 
               substr(changed_pubs$Title[i], 1, 50),
               changed_pubs$Year[i]))
    cat(sprintf("   Old: %s\n", changed_pubs$SES_Faculty_OLD[i]))
    cat(sprintf("   New: %s\n", changed_pubs$SES_Faculty[i]))
  }
}

# Step 6: Create final database (remove comparison column)
cat("\nSTEP 6: Preparing final database...\n")
final_db <- updated_db %>%
  select(-SES_Faculty_OLD) %>%  # Remove comparison column
  arrange(desc(Year), Title)

# Step 7: Save and upload
cat("\nSTEP 7: Saving and uploading updated database...\n")

# Save locally
write.csv(final_db, "faculty_enhanced_database.csv", row.names = FALSE)

# Upload to Google Sheets
tryCatch({
  write_sheet(final_db, ss = PUBLICATIONS_SHEET, sheet = "Enhanced_Publications")
  cat("✓ Successfully updated Google Sheets\n")
}, error = function(e) {
  cat("✗ Error uploading to Google Sheets:\n")
  print(e)
})

# Step 8: Final faculty statistics
cat("\nSTEP 8: Updated faculty statistics...\n")

# Count publications per faculty
faculty_counts <- final_db %>%
  filter(SES_Faculty != "" & !is.na(SES_Faculty)) %>%
  mutate(faculty_list = strsplit(SES_Faculty, ", ")) %>%
  tidyr::unnest(faculty_list) %>%
  count(faculty_list, name = "publication_count") %>%
  arrange(desc(publication_count))

cat("Top faculty by publication count:\n")
for(i in 1:min(10, nrow(faculty_counts))) {
  cat(sprintf("  %s: %d publications\n", faculty_counts$faculty_list[i], faculty_counts$publication_count[i]))
}

# Final summary
cat(sprintf("\n=== FACULTY MATCHING UPDATE COMPLETE ===\n"))
cat(sprintf("Total publications: %d\n", nrow(final_db)))
cat(sprintf("Publications with faculty: %d (%.1f%%)\n", new_with_faculty, 100*new_with_faculty/nrow(final_db)))
cat(sprintf("New faculty identifications: %d\n", improvements))
cat(sprintf("Enhanced matching used first initials + last names\n"))
cat(sprintf("Verified records preserved: %d\n", verified_count))
cat(sprintf("Backup created: %s\n", backup_file))
cat("Completed:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")

cat("\n✓ Enhanced faculty matching complete!\n")