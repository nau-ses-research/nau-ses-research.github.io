#!/usr/bin/env Rscript

# MAIN DATABASE UPDATE SCRIPT
# This is the primary script to update the SES Publications Database
# 
# What it does:
# - Adds only NEW publications from 2025 or later (avoids duplicate issues)
# - Updates citation counts for ALL existing publications
# - Preserves verified records and manual curation
# - Uses enhanced faculty matching with first initials
# - Includes student analysis for new publications

# Run the streamlined update system
cat("Running SES Publications Database Update...\n\n")
source("update_publications_2025.R")