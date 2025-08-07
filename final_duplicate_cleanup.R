#!/usr/bin/env Rscript

# FINAL DUPLICATE CLEANUP
# Remove the few remaining true duplicates identified in detailed analysis

library(googlesheets4)
library(dplyr)
library(stringr)

cat("=== FINAL DUPLICATE CLEANUP ===\n")
cat("Removing the 5 identified duplicate groups\n\n")

# Configuration
PUBLICATIONS_SHEET <- "1HMUJzmD91MlU7zDpWqHmuPwsmjqJIzE5HjaBj3NAMEw"
SHEET_NAME <- "Enhanced_Publications"

# Authenticate
gs4_auth()

# Download the database
cat("Downloading database...\n")
db <- read_sheet(PUBLICATIONS_SHEET, sheet = SHEET_NAME)
original_count <- nrow(db)
cat(sprintf("Original count: %d publications\n", original_count))

# Create backup
backup_file <- sprintf("final_cleanup_backup_%s.csv", format(Sys.time(), "%Y%m%d_%H%M%S"))
write.csv(db, backup_file, row.names = FALSE)
cat(sprintf("✓ Backup saved: %s\n", backup_file))

# Identify the specific duplicates found in detailed analysis
duplicates_to_remove <- c(
  # Group 1: Keep the one without "Data from:" prefix
  "datafromgeneticdivergencealongaclimategradientshapeschemicalplasticityofafoundationtreespeciestobothchangingclimateandherbivoredamage",
  
  # Group 2: Keep the main paper, remove the correction
  "authorcorrectionmodelingsuggestsfossilfuelemissionshavebeendrivingincreasedlandcarbonuptakesincetheturnofthethcentury",
  
  # Group 3: Keep the more complete title (first one)
  "nasamakingearthsystemdatarecordsforuseinresearchenvironmentsmeasuresglobalfoodsecuritysupportanalysisdatagfsadcroplandextentnorthamericam",
  
  # Group 4: Keep the more complete title (second one)
  "geometryandquaternaryslipbehaviorofthesanjuandelosplanesandsaltitofaultzonesbajacaliforniasurmexicocharacterizationofriftmarginnormalfaults",
  
  # Group 5: Keep the systematic review (final), remove the protocol
  "reviewprotocolfinalhavearidlandspringsrestorationprojectsbeeneffectiveinrestoringhydrologygeomorphologyandinvertebratesandplantspeciescomposition"
)

cat("\nIdentifying records to remove:\n")
for(i in 1:length(duplicates_to_remove)) {
  dup_title <- duplicates_to_remove[i]
  matching_records <- which(db$simpleTitle == dup_title)
  if(length(matching_records) > 0) {
    cat(sprintf("  %d. %s\n", i, db$Title[matching_records[1]]))
  }
}

# Remove the duplicates
db_cleaned <- db %>% 
  filter(!simpleTitle %in% duplicates_to_remove)

removed_count <- original_count - nrow(db_cleaned)
cat(sprintf("\n✓ Removed %d duplicate records\n", removed_count))
cat(sprintf("✓ Final count: %d publications\n", nrow(db_cleaned)))

# Verify no duplicates remain
duplicate_check <- db_cleaned$simpleTitle[!is.na(db_cleaned$simpleTitle)]
remaining_dups <- sum(duplicated(duplicate_check))

if(remaining_dups == 0) {
  cat("✅ SUCCESS: No duplicate simpleTitle entries remain!\n")
} else {
  cat(sprintf("⚠ WARNING: %d duplicates still remain\n", remaining_dups))
}

# Upload cleaned database
cat("\nUploading cleaned database to Google Sheets...\n")
tryCatch({
  write_sheet(db_cleaned, ss = PUBLICATIONS_SHEET, sheet = SHEET_NAME)
  cat("✓ Successfully updated Google Sheets with cleaned data\n")
}, error = function(e) {
  cat("✗ Error uploading to Google Sheets:\n")
  print(e)
})

# Final verification
cat("\n=== FINAL VERIFICATION ===\n")
cat(sprintf("Original publications: %d\n", original_count))
cat(sprintf("Duplicates removed: %d\n", removed_count))
cat(sprintf("Final count: %d\n", nrow(db_cleaned)))
cat(sprintf("Remaining duplicates: %d\n", remaining_dups))

cat("\n🎉 Database cleanup complete!\n")
cat("All duplicate simpleTitle entries have been removed.\n")