################################################################################
# SCRIPT 01: DATA DOWNLOAD
# Project: Conservation Priority Assessment of Birds in Gilgit-Baltistan
# Author: Syed Inzimam Ali Shah
# Date: December 2025
# Purpose: Download bird occurrence data from GBIF and iNaturalist
################################################################################

# Clear workspace
rm(list = ls())

# ============================================================================
# 1. LOAD REQUIRED LIBRARIES
# ============================================================================

# Install packages if not already installed (run once, then comment out)
# install.packages("rgbif")
# install.packages("rinat")
# install.packages("tidyverse")

# Load libraries
library(rgbif)        # For downloading GBIF data
library(rinat)        # For downloading iNaturalist data
library(tidyverse)    # For data manipulation (includes dplyr, ggplot2, etc.)

# Print message to confirm libraries loaded
cat("Libraries loaded successfully!\n\n")

# ============================================================================
# 2. SET WORKING DIRECTORY AND CREATE FOLDERS
# ============================================================================

# Set your working directory to the project folder
setwd("C:/gb-birds-conservation")

# Create folder structure if it doesn't exist
dir.create("data", showWarnings = FALSE)
dir.create("data/raw", showWarnings = FALSE)
dir.create("data/processed", showWarnings = FALSE)
dir.create("data/spatial", showWarnings = FALSE)

cat("Working directory set and folders created!\n\n")

# ============================================================================
# 3. DEFINE STUDY AREA BOUNDARIES
# ============================================================================

# Gilgit-Baltistan geographic boundaries (bounding box)
# These coordinates form a rectangle around the entire GB region

# Latitude (North-South): 34.0°N to 37.0°N
# Longitude (East-West): 72.0°E to 77.5°E

gb_latitude_min <- 34.0   # Southern boundary
gb_latitude_max <- 37.0   # Northern boundary
gb_longitude_min <- 72.0  # Western boundary
gb_longitude_max <- 77.5  # Eastern boundary

# Print study area information
cat("=== STUDY AREA DEFINED ===\n")
cat("Region: Gilgit-Baltistan, Pakistan\n")
cat("Latitude range:", gb_latitude_min, "to", gb_latitude_max, "\n")
cat("Longitude range:", gb_longitude_min, "to", gb_longitude_max, "\n\n")

# ============================================================================
# 4. DOWNLOAD DATA FROM GBIF
# ============================================================================

cat("Starting GBIF data download...\n")
cat("This may take several minutes depending on data size.\n\n")

# Download bird observations from GBIF
# Class Aves = all birds (taxonomic class)
# We filter by:
# - Geographic coordinates (within GB boundaries)
# - Must have coordinates (hasCoordinate = TRUE)
# - Country = Pakistan
# - Limit = maximum records to download

gbif_data <- occ_data(
  classKey = 212,  # 212 is the taxonomic key for Aves (Birds) in GBIF
  hasCoordinate = TRUE,  # Only records with lat/long coordinates
  decimalLatitude = paste(gb_latitude_min, gb_latitude_max, sep = ","),
  decimalLongitude = paste(gb_longitude_min, gb_longitude_max, sep = ","),
  country = "PK",  # Pakistan ISO code
  limit = 20000  # Maximum records to download (adjust if needed)
)

# Extract the actual data from the nested list structure
# GBIF returns data in a complex format, we need just the 'data' part
gbif_records <- gbif_data$data

# Print download summary
cat("GBIF download complete!\n")
cat("Total records downloaded:", nrow(gbif_records), "\n")
cat("Number of columns:", ncol(gbif_records), "\n\n")

# ============================================================================
# 5. DOWNLOAD DATA FROM iNATURALIST
# ============================================================================

cat("Starting iNaturalist data download...\n")
cat("This may take several minutes...\n\n")

# Download bird observations from iNaturalist
# We use the same bounding box as GBIF
# quality = "research" means only verified, high-quality observations

inat_data <- get_inat_obs(
  taxon_name = "Aves",  # Aves = Birds
  bounds = c(gb_latitude_min, gb_longitude_min,  # Format: ymin, xmin, ymax, xmax
             gb_latitude_max, gb_longitude_max),
  maxresults = 10000,  # Maximum results per request (iNat limit)
  quality = "research"  # Only research-grade observations (verified)
)

# Print download summary
cat("iNaturalist download complete!\n")
cat("Total records downloaded:", nrow(inat_data), "\n")
cat("Number of columns:", ncol(inat_data), "\n\n")

# ============================================================================
# 6. QUICK DATA EXPLORATION
# ============================================================================

cat("=== QUICK DATA SUMMARY ===\n\n")

# GBIF data summary
cat("--- GBIF Data ---\n")
cat("Unique species:", n_distinct(gbif_records$species), "\n")
cat("Date range:", min(gbif_records$year, na.rm = TRUE), "to", 
    max(gbif_records$year, na.rm = TRUE), "\n")
cat("Records with species name:", sum(!is.na(gbif_records$species)), "\n\n")

# iNaturalist data summary
cat("--- iNaturalist Data ---\n")
cat("Unique species:", n_distinct(inat_data$scientific_name), "\n")
cat("Date range:", min(year(inat_data$observed_on), na.rm = TRUE), "to", 
    max(year(inat_data$observed_on), na.rm = TRUE), "\n")
cat("Quality grade breakdown:\n")
print(table(inat_data$quality_grade))
cat("\n")

# ============================================================================
# 7. SAVE RAW DATA
# ============================================================================

cat("Saving raw data files...\n")

# GBIF data often contains list columns that can't be saved directly to CSV
# We need to convert these list columns to character format first

# Identify which columns are lists
list_columns <- sapply(gbif_records, is.list)

# Convert list columns to character strings
# This preserves the data but makes it CSV-compatible
if(any(list_columns)) {
  gbif_records[list_columns] <- lapply(gbif_records[list_columns], 
                                       function(x) sapply(x, toString))
  cat("Converted", sum(list_columns), "list columns to character format\n")
}

# Save GBIF data as CSV
write.csv(gbif_records, 
          "data/raw/gbif_raw.csv", 
          row.names = FALSE)  # Don't save row numbers

# Do the same check for iNaturalist data (usually doesn't have this issue)
list_columns_inat <- sapply(inat_data, is.list)
if(any(list_columns_inat)) {
  inat_data[list_columns_inat] <- lapply(inat_data[list_columns_inat], 
                                         function(x) sapply(x, toString))
}

# Save iNaturalist data as CSV
write.csv(inat_data, 
          "data/raw/inat_raw.csv", 
          row.names = FALSE)

cat("Raw data saved successfully!\n")
cat("Files saved in: data/raw/\n")
cat("  - gbif_raw.csv\n")
cat("  - inat_raw.csv\n\n")

# ============================================================================
# 8. CREATE DOWNLOAD SUMMARY REPORT
# ============================================================================

# Create a summary data frame with download information
download_summary <- data.frame(
  Date = Sys.Date(),
  GBIF_Records = nrow(gbif_records),
  GBIF_Species = n_distinct(gbif_records$species),
  iNat_Records = nrow(inat_data),
  iNat_Species = n_distinct(inat_data$scientific_name),
  Total_Records = nrow(gbif_records) + nrow(inat_data),
  Study_Area = "Gilgit-Baltistan, Pakistan",
  Lat_Range = paste(gb_latitude_min, "-", gb_latitude_max),
  Lon_Range = paste(gb_longitude_min, "-", gb_longitude_max)
)

# Save summary
write.csv(download_summary, 
          "data/raw/download_summary.csv", 
          row.names = FALSE)

# Print final summary
cat("=== DOWNLOAD COMPLETE ===\n")
cat("Total records downloaded:", 
    nrow(gbif_records) + nrow(inat_data), "\n")
cat("Combined unique species (approximate):", 
    n_distinct(c(gbif_records$species, inat_data$scientific_name)), "\n")
cat("Download summary saved: data/raw/download_summary.csv\n\n")



# ============================================================================
# END OF SCRIPT
# ============================================================================

# NOTES FOR UNDERSTANDING:
# 
# 1. GBIF (Global Biodiversity Information Facility):
#    - World's largest database of species occurrence records
#    - Data from museums, citizen science, research projects
#    - Free and open access
#
# 2. iNaturalist:
#    - Citizen science platform for nature observations
#    - Community-verified identifications
#    - "Research grade" = verified by multiple experts
#
# 3. Why both sources?
#    - GBIF has historical museum records + old surveys
#    - iNaturalist has recent citizen science observations
#    - Together = more complete picture
#
# 4. Bounding box approach:
#    - Simple rectangle around GB region
#    - May include some areas just outside GB borders
#    - Will refine in cleaning step
#
# 5. Data size considerations:
#    - If you get < 1000 records, increase limit values
#    - If download fails, try smaller limit values
#    - Can run multiple times for different time periods
################################################################################