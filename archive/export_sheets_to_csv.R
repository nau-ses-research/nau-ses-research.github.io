#!/usr/bin/env Rscript
# One-time export of the SES publication system's Google Sheets to raw CSVs.
# Run once at the 2026-08 cutover; the repo data/ CSVs become the system of
# record afterward. Requires a cached gargle token for nick.mckay2@gmail.com.
# Raw output goes to ~/GitHub/SES_dashboard_backups/raw_sheets/; the schema
# transformation into data/*.csv happens in scripts/convert_raw_export.py.

library(googlesheets4)

PUBLICATIONS_SHEET <- "1HMUJzmD91MlU7zDpWqHmuPwsmjqJIzE5HjaBj3NAMEw"
STUDENTS_SHEET <- "1FuWlVun83yUZKl49r1o71MsZSKaD5Mw14n-ssmEpLVE"
OUT <- path.expand("~/GitHub/SES_dashboard_backups/raw_sheets")

gs4_auth(email = "nick.mckay2@gmail.com")

pubs <- read_sheet(PUBLICATIONS_SHEET, sheet = "Enhanced_Publications", col_types = "c")
write.csv(pubs, file.path(OUT, "Enhanced_Publications.csv"), row.names = FALSE, na = "")
cat(sprintf("Enhanced_Publications: %d rows, %d cols\n", nrow(pubs), ncol(pubs)))

for (tab in c("Alumni", "Current ESP", "Current GLG", "Current PhD", "Current CSS")) {
  d <- read_sheet(STUDENTS_SHEET, sheet = tab, col_types = "c")
  write.csv(d, file.path(OUT, paste0("students_", gsub(" ", "_", tab), ".csv")),
            row.names = FALSE, na = "")
  cat(sprintf("%s: %d rows, %d cols\n", tab, nrow(d), ncol(d)))
}

cat("Export complete:", OUT, "\n")
