#!/usr/bin/env Rscript

# Build script for SES Publications Dashboard

cat("🏗️ Building SES Publications Dashboard...\n")

# Check and install blogdown if needed
if(!require(blogdown, quietly = TRUE)) {
  cat("Installing blogdown...\n")
  install.packages("blogdown", repos = "https://cran.rstudio.com/")
  library(blogdown)
}

# Install Hugo if not available
if(!blogdown::hugo_available()) {
  cat("Installing Hugo...\n")
  blogdown::install_hugo()
}

cat("Hugo installed:", blogdown::hugo_available(), "\n")

# Generate statistics first
cat("📊 Generating statistics...\n")
source("R/generate_website_stats.R")

# Build the site
cat("🔨 Building website...\n")
blogdown::build_site()

cat("✅ Website build complete!\n")
cat("📁 Output in 'public/' directory\n")