#!/usr/bin/env Rscript

# Generate dynamic statistics for SES Publications Website
# This script calculates key metrics from the publication database

library(googlesheets4)
library(dplyr)
library(stringr)
library(lubridate)

cat("Generating SES Publication Statistics for Website...\n")

# Authenticate and load data
gs4_auth()
pub_db <- read_sheet("1HMUJzmD91MlU7zDpWqHmuPwsmjqJIzE5HjaBj3NAMEw", sheet = "Enhanced_Publications")

# Clean and prepare data
pub_db <- pub_db %>%
  filter(!is.na(Year), Year >= 2009) %>%  # Focus on recent years
  filter(Include_In_Reports == TRUE | is.na(Include_In_Reports)) %>%  # Include only reportable publications
  mutate(
    Citations = ifelse(is.na(Citations), 0, Citations),
    SES_Faculty = ifelse(is.na(SES_Faculty), "", SES_Faculty),
    SES_Grad_Students = ifelse(is.na(SES_Grad_Students), "", SES_Grad_Students),
    SES_Undergrad_Students = ifelse(is.na(SES_Undergrad_Students), "", SES_Undergrad_Students)
  )

# ═══════════════════════════════════════════════════════════════════════════════════════
# KEY STATISTICS FOR FRONT PAGE
# ═══════════════════════════════════════════════════════════════════════════════════════

# Overall faculty statistics (since 2009)
faculty_pubs <- pub_db %>% filter(SES_Faculty != "")
total_faculty_pubs <- nrow(faculty_pubs)
total_citations <- sum(faculty_pubs$Citations, na.rm = TRUE)

# Calculate H-index for the department
citations_sorted <- sort(faculty_pubs$Citations, decreasing = TRUE)
h_index <- 1
while(h_index <= length(citations_sorted) && citations_sorted[h_index] >= h_index) {
  h_index <- h_index + 1
}
h_index <- h_index - 1

# Graduate student statistics
grad_pubs <- pub_db %>% filter(SES_Grad_Students != "")
total_grad_pubs <- nrow(grad_pubs)
grad_citations <- sum(grad_pubs$Citations, na.rm = TRUE)

# Count unique graduate students
all_grad_students <- paste(grad_pubs$SES_Grad_Students, collapse = ", ")
unique_grad_students <- unique(trimws(unlist(strsplit(all_grad_students, ","))))
unique_grad_students <- unique_grad_students[unique_grad_students != ""]
total_grad_students <- length(unique_grad_students)

# Top journals for graduate students
grad_journals <- grad_pubs$Journal[!is.na(grad_pubs$Journal) & grad_pubs$Journal != ""]
journal_counts <- sort(table(grad_journals), decreasing = TRUE)
top_journals <- names(journal_counts)[1:min(5, length(journal_counts))]

# Last year statistics (2024 or current year - 1)
last_year <- year(Sys.Date()) - 1
last_year_pubs <- pub_db %>% filter(Year == last_year)

faculty_last_year <- nrow(last_year_pubs %>% filter(SES_Faculty != ""))
grad_last_year <- nrow(last_year_pubs %>% filter(SES_Grad_Students != ""))
undergrad_last_year <- nrow(last_year_pubs %>% filter(SES_Undergrad_Students != ""))

# Count unique journals
all_journals <- pub_db$Journal[!is.na(pub_db$Journal) & pub_db$Journal != ""]
unique_journals <- length(unique(all_journals))

# Count actively publishing faculty (published since 2023)
current_year <- year(Sys.Date())
actively_publishing_cutoff <- current_year - 2  # Since 2023 (2 years ago)
recent_faculty_pubs <- pub_db %>% 
  filter(SES_Faculty != "", Year >= actively_publishing_cutoff)
actively_publishing_faculty <- unique(unlist(strsplit(paste(recent_faculty_pubs$SES_Faculty, collapse = ", "), ", ")))
actively_publishing_faculty <- actively_publishing_faculty[actively_publishing_faculty != ""]
actively_publishing_count <- length(actively_publishing_faculty)

# ═══════════════════════════════════════════════════════════════════════════════════════
# CREATE PULL QUOTES
# ═══════════════════════════════════════════════════════════════════════════════════════

quote1 <- sprintf(
  "Over the past 16 years, faculty from NAU's School of Earth and Sustainability have published **%s** peer-reviewed scientific studies in the world's leading journals, with a total of **%s** citations. Since 2009, the School has a collective H-Index of **%d**.",
  format(total_faculty_pubs, big.mark = ","),
  format(total_citations, big.mark = ","),
  h_index
)

# Format top journals nicely
top_journals_formatted <- paste(top_journals, collapse = ", ")
quote2 <- sprintf(
  "Since 2009, **%d** SES Graduate students have published **%s** publications in **%d** journals, including %s. These articles have been cited **%s** times.",
  total_grad_students,
  format(total_grad_pubs, big.mark = ","),
  unique_journals,
  top_journals_formatted,
  format(grad_citations, big.mark = ",")
)

quote3 <- sprintf(
  "In %d, SES Faculty published **%d** articles, Graduate students published **%d**, and Undergraduates published **%d** papers in the scientific literature.",
  last_year,
  faculty_last_year,
  grad_last_year,
  undergrad_last_year
)

# ═══════════════════════════════════════════════════════════════════════════════════════
# SAVE STATISTICS
# ═══════════════════════════════════════════════════════════════════════════════════════

stats_list <- list(
  # Pull quotes
  quote1 = quote1,
  quote2 = quote2,
  quote3 = quote3,
  
  # Key numbers
  total_faculty_pubs = total_faculty_pubs,
  total_citations = total_citations,
  h_index = h_index,
  total_grad_pubs = total_grad_pubs,
  total_grad_students = total_grad_students,
  grad_citations = grad_citations,
  unique_journals = unique_journals,
  faculty_last_year = faculty_last_year,
  grad_last_year = grad_last_year,
  undergrad_last_year = undergrad_last_year,
  last_year = last_year,
  actively_publishing_count = actively_publishing_count,
  
  # Data for visualizations
  pub_data = pub_db,
  faculty_pubs = faculty_pubs,
  grad_pubs = grad_pubs,
  top_journals = top_journals
)

# Save to RDS file for use in website generation
saveRDS(stats_list, "website_stats.rds")

cat("✅ Statistics generated and saved to website_stats.rds\n")
cat("\n📊 KEY METRICS:\n")
cat(sprintf("• Faculty publications (2009+): %s\n", format(total_faculty_pubs, big.mark = ",")))
cat(sprintf("• Total citations: %s\n", format(total_citations, big.mark = ",")))
cat(sprintf("• Department H-index: %d\n", h_index))
cat(sprintf("• Graduate student publications: %s\n", format(total_grad_pubs, big.mark = ",")))
cat(sprintf("• Unique grad students publishing: %d\n", total_grad_students))
cat(sprintf("• Publications in %d: Faculty %d, Grad %d, Undergrad %d\n", 
            last_year, faculty_last_year, grad_last_year, undergrad_last_year))
cat(sprintf("• Actively publishing faculty (since %d): %d\n", actively_publishing_cutoff, actively_publishing_count))

cat("\n🎯 Ready for website generation!\n")