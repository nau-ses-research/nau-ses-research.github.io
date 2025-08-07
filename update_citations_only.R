#!/usr/bin/env Rscript

# CITATION UPDATE PROCESS
# Separate process to update citation counts for all publications
# Uses simple Google Scholar search to match by simpleTitle

library(googlesheets4)
library(dplyr)
library(stringr)
library(scholar)

cat("=== CITATION UPDATE PROCESS ===\n")
cat("Updating citation counts for all publications in database\n")
cat("Started:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

PUBLICATIONS_SHEET <- "1HMUJzmD91MlU7zDpWqHmuPwsmjqJIzE5HjaBj3NAMEw"

# Authenticate
gs4_auth()

# Step 1: Download current database
cat("STEP 1: Downloading current database...\n")
current_db <- read_sheet(PUBLICATIONS_SHEET, sheet = "Enhanced_Publications")
cat(sprintf("✓ Downloaded %d publications\n", nrow(current_db)))

verified_count <- sum(current_db$Verified == TRUE, na.rm = TRUE)
cat(sprintf("✓ %d verified records (citations will be updated, other fields preserved)\n", verified_count))

# Create backup
backup_file <- sprintf("citation_backup_%s.csv", format(Sys.time(), "%Y%m%d_%H%M%S"))
write.csv(current_db, backup_file, row.names = FALSE)
cat(sprintf("✓ Backup saved: %s\n", backup_file))

# Step 2: Load faculty data for Scholar IDs
cat("\nSTEP 2: Loading faculty data...\n")
faculty_data <- read.csv("facultygooglescholarids.csv") %>%
  rename(FirstInitial = `First.Initial`, LastName = `Last.Name`) %>%
  filter(!is.na(ID), ID != "")

cat(sprintf("✓ Loaded %d faculty members with Scholar IDs\n", nrow(faculty_data)))

# Step 3: Fetch ALL publications for citation lookup
cat("\nSTEP 3: Fetching all publications for citation updates...\n")
citation_lookup <- data.frame()

for(i in 1:nrow(faculty_data)) {
  faculty <- faculty_data[i, ]
  cat(sprintf("  %s %s... ", faculty$FirstInitial, faculty$LastName))
  
  tryCatch({
    pubs <- get_publications(faculty$ID)
    
    if(nrow(pubs) > 0) {
      # Create lookup table with simpleTitle and citations
      faculty_citations <- pubs %>%
        mutate(simpleTitle = tolower(str_remove_all(title, "[^A-Za-z0-9]"))) %>%
        select(simpleTitle, cites, title) %>%
        filter(!is.na(simpleTitle), simpleTitle != "")
      
      citation_lookup <- bind_rows(citation_lookup, faculty_citations)
      cat(sprintf("%d pubs\n", nrow(pubs)))
    } else {
      cat("0 pubs\n")
    }
    
    Sys.sleep(1)  # Rate limiting
    
  }, error = function(e) {
    cat("ERROR\n")
  })
}

cat(sprintf("✓ Collected %d publications for citation lookup\n", nrow(citation_lookup)))

# Step 4: Create optimized lookup table (max citations per title)
cat("\nSTEP 4: Creating citation lookup table...\n")
citation_table <- citation_lookup %>%
  group_by(simpleTitle) %>%
  summarise(
    max_citations = max(cites, na.rm = TRUE),
    sample_title = first(title),
    .groups = 'drop'
  ) %>%
  filter(!is.na(max_citations), max_citations >= 0)

cat(sprintf("✓ Created lookup table with %d unique titles\n", nrow(citation_table)))

# Step 5: Update citations in database
cat("\nSTEP 5: Updating citations in database...\n")
citation_updates <- 0
no_match_count <- 0

for(i in 1:nrow(current_db)) {
  if(i %% 100 == 0) cat(sprintf("  Progress: %d/%d\n", i, nrow(current_db)))
  
  if(!is.na(current_db$simpleTitle[i]) && current_db$simpleTitle[i] != "") {
    # Look up citation count
    lookup_match <- citation_table[citation_table$simpleTitle == current_db$simpleTitle[i], ]
    
    if(nrow(lookup_match) > 0) {
      new_citations <- lookup_match$max_citations[1]
      old_citations <- ifelse(is.na(current_db$Citations[i]), 0, current_db$Citations[i])
      
      if(!is.na(new_citations) && new_citations >= 0 && new_citations != old_citations) {
        current_db$Citations[i] <- new_citations
        citation_updates <- citation_updates + 1
        if(citation_updates <= 5) {  # Show first few updates
          cat(sprintf("    Updated '%s': %d -> %d citations\n", 
                     substr(current_db$Title[i], 1, 40), old_citations, new_citations))
        }
      }
    } else {
      no_match_count <- no_match_count + 1
    }
  }
}

cat(sprintf("✓ Updated citations for %d publications\n", citation_updates))
cat(sprintf("ℹ No citation data found for %d publications\n", no_match_count))

# Step 6: Verify verified records are preserved
verification_check <- sum(current_db$Verified == TRUE, na.rm = TRUE)
if(verification_check == verified_count) {
  cat("✓ All verified records properly preserved\n")
} else {
  cat("⚠ Warning: Verified record count changed!\n")
}

# Step 7: Upload updated database
cat("\nSTEP 7: Uploading updated database...\n")
tryCatch({
  write_sheet(current_db, ss = PUBLICATIONS_SHEET, sheet = "Enhanced_Publications")
  cat("✓ Successfully updated Google Sheets\n")
}, error = function(e) {
  cat("✗ Error uploading to Google Sheets:\n")
  print(e)
})

# Step 8: Summary statistics
cat("\nSTEP 8: Citation statistics...\n")
total_citations <- sum(current_db$Citations, na.rm = TRUE)
avg_citations <- mean(current_db$Citations, na.rm = TRUE)
max_citations <- max(current_db$Citations, na.rm = TRUE)
pubs_with_citations <- sum(!is.na(current_db$Citations) & current_db$Citations > 0)

cat(sprintf("Total citations across all publications: %d\n", total_citations))
cat(sprintf("Average citations per publication: %.1f\n", avg_citations))
cat(sprintf("Maximum citations for single publication: %d\n", max_citations))
cat(sprintf("Publications with citation data: %d (%.1f%%)\n", 
           pubs_with_citations, 100 * pubs_with_citations / nrow(current_db)))

# Final summary
cat(sprintf("\n=== CITATION UPDATE SUMMARY ===\n"))
cat(sprintf("Total publications processed: %d\n", nrow(current_db)))
cat(sprintf("Citations updated: %d\n", citation_updates))
cat(sprintf("No citation data: %d\n", no_match_count))
cat(sprintf("Verified records preserved: %d\n", verified_count))
cat(sprintf("Backup created: %s\n", backup_file))
cat("Completed:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")

cat("\n✓ Citation update complete!\n")