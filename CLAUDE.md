# SES Publications Dashboard

This is a streamlined publication dashboard for the School of Earth and Sustainability (SES) at Northern Arizona University. The system mines Google Scholar for faculty publications and creates a website to display publications with key statistics.

## System Architecture

### Data Sources
- **Google Scholar**: Primary source for publication data via the R `scholar` package
- **Google Sheets**: Intermediate storage for efficiency and manual curation
  - Publications database: `1HMUJzmD91MlU7zDpWqHmuPwsmjqJIzE5HjaBj3NAMEw`
  - Student database: `1FuWlVun83yUZKl49r1o71MsZSKaD5Mw14n-ssmEpLVE`
- **Hugo/Blox Builder**: Static site generator for the final website

### Database Structure
The publications database includes:
- Standard bibliographic fields (Title, Authors, Journal, Year, Citations)
- **SES_Faculty**: All SES faculty co-authors (enhanced matching with first initials)
- **SES_Grad_Students**: Graduate student co-authors (automatically detected)
- **SES_Undergrad_Students**: Undergraduate co-authors (manually added)
- **Verified**: Flag for manually verified/curated records
- **Include_In_Reports**: Control visibility in reports
- **Additional_Notes**: Manual annotations
- **simpleTitle**: Normalized title for deduplication (no spaces, alphanumeric only)

## Key Scripts

### Primary Update Script
- **`update_database.R`**: Main update script (calls the streamlined system)
- **`update_publications_2025.R`**: Core logic for database updates

### What the Update System Does
1. **Downloads current database** and creates timestamped backup
2. **Fetches ALL publications** from Google Scholar for citation updates
3. **Updates citation counts** for all existing publications
4. **Identifies NEW publications** from 2025 or later only (avoids duplicates)
5. **Enhanced faculty matching** using first initials from `facultygooglescholarids.csv`
6. **Improved student detection** with enhanced pattern matching (handles "EJ Baransky" patterns)
7. **Filters non-peer-reviewed publications** based on journal keywords (meeting, conference, abstract, rxiv, preprint, nsf award, etc.)
8. **Full author list retrieval** (prevents truncation with "...")
9. **Preserves verified records** except for citation updates
10. **Uploads clean results** to Google Sheets

### Faculty Data Format
`facultygooglescholarids.csv` contains:
- **First Initial**: Used for enhanced name matching (e.g., "D" for Darrell)
- **Last Name**: Faculty surname
- **ID**: Google Scholar ID
- **StartYear/EndYear**: Publication date range to consider

### Helper Scripts
- **`R/load_students.R`**: Loads student data with exclusions (McKay, Thompson)
- **`update_citations_only.R`**: Separate process to update all citation counts
- **`reading google scholar.R`**: Original exploration script (reference only)

## Update Strategy

The system now uses a **conservative approach**:
- Only adds publications from **2025 or newer** to avoid duplicate issues
- Updates **all citation counts** to keep data current
- Preserves existing database integrity and manual curation
- Enhanced faculty matching reduces false negatives
- Automatic student detection maintains comprehensive tracking

## Website Generation
- Uses Hugo static site generator with Blox Builder theme
- Hugo configuration in `config/` directory
- Content templates in `content/` and `layouts/`
- Build scripts in `R/build.R` and `R/build2.R`

## Running Updates
```bash
# Main update command
Rscript update_database.R

# This will:
# - Create timestamped backup
# - Add only 2025+ publications
# - Update all citation counts
# - Preserve verified records
# - Upload results to Google Sheets
```

The system is designed to be run regularly without causing data integrity issues or duplicates.