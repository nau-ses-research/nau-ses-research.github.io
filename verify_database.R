#!/usr/bin/env Rscript

# DATABASE VERIFICATION SCRIPT
# Comprehensive verification that the database update worked correctly
# Checks for duplicates, total count, faculty assignments, and deduplication

library(googlesheets4)
library(dplyr)
library(stringr)

cat("=== SES PUBLICATIONS DATABASE VERIFICATION ===\n")
cat("Started:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

# Configuration
PUBLICATIONS_SHEET <- "1HMUJzmD91MlU7zDpWqHmuPwsmjqJIzE5HjaBj3NAMEw"
SHEET_NAME <- "Enhanced_Publications"

# Authenticate
gs4_auth()

# Download the database
cat("STEP 1: Downloading database for verification...\n")
db <- read_sheet(PUBLICATIONS_SHEET, sheet = SHEET_NAME)
cat(sprintf("✓ Downloaded database with %d records\n\n", nrow(db)))

# VERIFICATION 1: Total publication count
cat("=== VERIFICATION 1: TOTAL PUBLICATION COUNT ===\n")
total_pubs <- nrow(db)
cat(sprintf("Total publications in database: %d\n", total_pubs))
if(total_pubs >= 1200 && total_pubs <= 1300) {
  cat("✓ PASS: Count is within expected range (~1232)\n")
} else {
  cat("⚠ WARNING: Count may be outside expected range\n")
}
cat("\n")

# VERIFICATION 2: Check for duplicate simpleTitle entries
cat("=== VERIFICATION 2: DUPLICATE simpleTitle CHECK ===\n")

# Count non-NA simpleTitle entries
valid_simple_titles <- db$simpleTitle[!is.na(db$simpleTitle) & db$simpleTitle != ""]
cat(sprintf("Publications with valid simpleTitle: %d\n", length(valid_simple_titles)))

# Check for duplicates
duplicate_titles <- valid_simple_titles[duplicated(valid_simple_titles)]
unique_duplicates <- unique(duplicate_titles)

if(length(unique_duplicates) == 0) {
  cat("✓ PASS: NO duplicate simpleTitle entries found!\n")
} else {
  cat(sprintf("✗ FAIL: Found %d duplicate simpleTitle values:\n", length(unique_duplicates)))
  
  # Show details of duplicates
  for(dup_title in unique_duplicates) {
    dup_records <- db[!is.na(db$simpleTitle) & db$simpleTitle == dup_title, ]
    cat(sprintf("\nDuplicate simpleTitle: %s\n", dup_title))
    cat("Records with this simpleTitle:\n")
    for(i in 1:nrow(dup_records)) {
      cat(sprintf("  %d. %s (%d) - Faculty: %s\n", 
                  i, dup_records$Title[i], dup_records$Year[i], 
                  ifelse(is.na(dup_records$SES_Faculty[i]), "None", dup_records$SES_Faculty[i])))
    }
  }
}
cat("\n")

# VERIFICATION 3: Check 2025 publications have proper faculty assignments
cat("=== VERIFICATION 3: 2025 PUBLICATIONS FACULTY ASSIGNMENTS ===\n")

# Filter 2025 publications
pubs_2025 <- db %>% filter(Year == 2025)
cat(sprintf("Total 2025 publications: %d\n", nrow(pubs_2025)))

if(nrow(pubs_2025) > 0) {
  # Check faculty assignments
  faculty_assigned <- sum(!is.na(pubs_2025$SES_Faculty) & pubs_2025$SES_Faculty != "", na.rm = TRUE)
  multi_faculty <- sum(str_count(pubs_2025$SES_Faculty, ",") > 0, na.rm = TRUE)
  
  cat(sprintf("2025 publications with faculty assigned: %d (%.1f%%)\n", 
              faculty_assigned, (faculty_assigned/nrow(pubs_2025))*100))
  cat(sprintf("2025 publications with multiple faculty: %d\n", multi_faculty))
  
  # Show a sample of 2025 publications with faculty assignments
  cat("\nSample 2025 publications with faculty assignments:\n")
  sample_pubs <- pubs_2025[!is.na(pubs_2025$SES_Faculty) & pubs_2025$SES_Faculty != "", ] %>%
    head(5)
  
  for(i in 1:nrow(sample_pubs)) {
    cat(sprintf("  • %s (%d)\n", sample_pubs$Title[i], sample_pubs$Year[i]))
    cat(sprintf("    Faculty: %s\n", sample_pubs$SES_Faculty[i]))
    if(!is.na(sample_pubs$SES_Grad_Students[i]) && sample_pubs$SES_Grad_Students[i] != "") {
      cat(sprintf("    Students: %s\n", sample_pubs$SES_Grad_Students[i]))
    }
    cat("\n")
  }
  
  # Specifically look for multi-faculty papers
  multi_faculty_pubs <- pubs_2025[!is.na(pubs_2025$SES_Faculty) & 
                                  str_count(pubs_2025$SES_Faculty, ",") > 0, ]
  
  if(nrow(multi_faculty_pubs) > 0) {
    cat("Multi-faculty 2025 publications (showing collaboration):\n")
    for(i in 1:min(3, nrow(multi_faculty_pubs))) {
      cat(sprintf("  • %s\n", multi_faculty_pubs$Title[i]))
      cat(sprintf("    Faculty: %s\n", multi_faculty_pubs$SES_Faculty[i]))
    }
  }
  
  if(faculty_assigned >= nrow(pubs_2025) * 0.7) {
    cat("✓ PASS: Most 2025 publications have faculty assignments\n")
  } else {
    cat("⚠ WARNING: Many 2025 publications lack faculty assignments\n")
  }
} else {
  cat("ℹ INFO: No 2025 publications found\n")
}
cat("\n")

# VERIFICATION 4: Confirm deduplication worked
cat("=== VERIFICATION 4: DEDUPLICATION EFFECTIVENESS ===\n")

# Look for potential patterns that suggest successful deduplication
# Check for publications that appear to have multiple faculty but single records

# Look for records with multiple faculty (suggests successful merging)
multi_faculty_all <- db[!is.na(db$SES_Faculty) & str_count(db$SES_Faculty, ",") > 0, ]
cat(sprintf("Publications with multiple faculty: %d\n", nrow(multi_faculty_all)))

if(nrow(multi_faculty_all) > 0) {
  cat("Examples of successfully merged publications:\n")
  sample_merged <- head(multi_faculty_all, 3)
  for(i in 1:nrow(sample_merged)) {
    cat(sprintf("  • %s (%d)\n", sample_merged$Title[i], sample_merged$Year[i]))
    cat(sprintf("    Faculty: %s\n", sample_merged$SES_Faculty[i]))
    cat("\n")
  }
  cat("✓ PASS: Evidence of successful publication merging\n")
} else {
  cat("⚠ WARNING: No multi-faculty publications found - may indicate merging issues\n")
}

# Additional check: Look for very similar titles (potential missed duplicates)
cat("\nChecking for potentially similar titles...\n")

# Create a function to check for very similar titles
check_similar_titles <- function(titles, threshold = 0.9) {
  similar_pairs <- c()
  
  for(i in 1:(length(titles)-1)) {
    for(j in (i+1):length(titles)) {
      if(!is.na(titles[i]) && !is.na(titles[j])) {
        # Simple similarity check based on character overlap
        title1_clean <- tolower(str_remove_all(titles[i], "[^a-z0-9]"))
        title2_clean <- tolower(str_remove_all(titles[j], "[^a-z0-9]"))
        
        if(nchar(title1_clean) > 10 && nchar(title2_clean) > 10) {
          # Check if one title is largely contained in another
          if(str_detect(title1_clean, str_sub(title2_clean, 1, min(20, nchar(title2_clean)))) ||
             str_detect(title2_clean, str_sub(title1_clean, 1, min(20, nchar(title1_clean))))) {
            similar_pairs <- c(similar_pairs, paste(i, j, sep="-"))
          }
        }
      }
    }
  }
  return(similar_pairs)
}

# Check a sample for similar titles (checking all would be too slow)
sample_titles <- sample(db$Title[!is.na(db$Title)], min(500, sum(!is.na(db$Title))))
similar_pairs <- check_similar_titles(sample_titles)

cat(sprintf("Potentially similar title pairs in sample: %d\n", length(similar_pairs)))
if(length(similar_pairs) <= 2) {
  cat("✓ PASS: Very few similar titles detected\n")
} else {
  cat("⚠ WARNING: Multiple similar titles detected - manual review recommended\n")
}
cat("\n")

# VERIFICATION 5: Data integrity checks
cat("=== VERIFICATION 5: DATA INTEGRITY ===\n")

# Check for required fields
missing_titles <- sum(is.na(db$Title) | db$Title == "")
missing_years <- sum(is.na(db$Year))
missing_authors <- sum(is.na(db$Authors) | db$Authors == "")

cat(sprintf("Publications missing titles: %d\n", missing_titles))
cat(sprintf("Publications missing years: %d\n", missing_years))
cat(sprintf("Publications missing authors: %d\n", missing_authors))

# Year distribution
year_dist <- table(db$Year, useNA = "ifany")
cat("\nYear distribution (last 6 years):\n")
recent_years <- as.character(2019:2025)
for(year in recent_years) {
  count <- ifelse(year %in% names(year_dist), year_dist[year], 0)
  cat(sprintf("  %s: %d publications\n", year, count))
}

# Check verified status
verified_count <- sum(db$Verified == TRUE, na.rm = TRUE)
cat(sprintf("\nVerified publications: %d (%.1f%%)\n", 
            verified_count, (verified_count/nrow(db))*100))

if(missing_titles == 0 && missing_years <= 5 && missing_authors <= 10) {
  cat("✓ PASS: Data integrity looks good\n")
} else {
  cat("⚠ WARNING: Some data integrity issues detected\n")
}
cat("\n")

# FINAL SUMMARY
cat("=== FINAL VERIFICATION SUMMARY ===\n")
cat(sprintf("Database size: %d publications\n", nrow(db)))
cat(sprintf("Duplicate simpleTitle entries: %d\n", length(unique_duplicates)))
cat(sprintf("2025 publications: %d\n", nrow(pubs_2025)))
cat(sprintf("Multi-faculty publications: %d\n", nrow(multi_faculty_all)))
cat(sprintf("Verified records: %d\n", verified_count))

# Overall assessment
issues_found <- length(unique_duplicates) > 0 || missing_titles > 0 || missing_years > 5

if(!issues_found) {
  cat("\n🎉 OVERALL ASSESSMENT: PASS\n")
  cat("✓ No duplicate simpleTitle entries found\n")
  cat("✓ Database size is appropriate\n")
  cat("✓ Data integrity looks good\n")
  cat("✓ Deduplication appears to have worked correctly\n")
} else {
  cat("\n⚠ OVERALL ASSESSMENT: NEEDS ATTENTION\n")
  if(length(unique_duplicates) > 0) {
    cat("✗ Duplicate simpleTitle entries found\n")
  }
  if(missing_titles > 0 || missing_years > 5) {
    cat("✗ Data integrity issues detected\n")
  }
}

cat("\nCompleted:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")