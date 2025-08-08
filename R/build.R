# Pre-build script for SES Publications Dashboard
# Generates statistics and renders RMarkdown files before Hugo build

cat("🔄 Pre-build: Generating website statistics...\n")

# Generate the statistics
if(!Sys.getenv("CI") == "true"){
  source("R/generate_website_stats.R")
}
cat("✅ Pre-build complete!\n")
