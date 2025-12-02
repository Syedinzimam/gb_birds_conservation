################################################################################
# SCRIPT 02: DATA CLEANING AND STANDARDIZATION
# Project: Conservation Priority Assessment of Birds in Gilgit-Baltistan
# Author: Syed Inzimam Ali Shah
# Date: December 2025
# Purpose: Clean, standardize, and combine GBIF and iNaturalist data
################################################################################

# Clear workspace
rm(list = ls())

# ============================================================================
# 1. LOAD REQUIRED LIBRARIES
# ============================================================================

library(tidyverse)    # For data manipulation
library(lubridate)    # For date handling

cat("Libraries loaded successfully!\n\n")

# ============================================================================
# 2. SET WORKING DIRECTORY
# ============================================================================

setwd("C:/gb-birds-conservation")

cat("Working directory set!\n\n")

# ============================================================================
# 3. LOAD RAW DATA
# ============================================================================

cat("Loading raw data files...\n")

# Load GBIF data
gbif_raw <- read.csv("data/raw/gbif_raw.csv", stringsAsFactors = FALSE)

# Load iNaturalist data
inat_raw <- read.csv("data/raw/inat_raw.csv", stringsAsFactors = FALSE)

cat("GBIF records loaded:", nrow(gbif_raw), "\n")
cat("iNaturalist records loaded:", nrow(inat_raw), "\n\n")

# ============================================================================
# 4. STANDARDIZE GBIF DATA
# ============================================================================

cat("Standardizing GBIF data...\n")

# Select and rename important columns to create consistent structure
# Keep only the columns we need for analysis
gbif_clean <- gbif_raw %>%
  select(
    species,                    # Species name
    scientificName,             # Full scientific name
    decimalLatitude,            # Latitude coordinate
    decimalLongitude,           # Longitude coordinate
    eventDate,                  # Date of observation
    year,                       # Year
    month,                      # Month
    day,                        # Day
    basisOfRecord,              # Type of record (observation, specimen, etc.)
    individualCount,            # Number of individuals observed
    locality,                   # Location description
    stateProvince,              # Province/state
    coordinateUncertaintyInMeters,  # Accuracy of coordinates
    occurrenceID                # Unique record ID
  ) %>%
  rename(
    latitude = decimalLatitude,
    longitude = decimalLongitude,
    date = eventDate,
    basis = basisOfRecord,
    count = individualCount,
    uncertainty = coordinateUncertaintyInMeters,
    record_id = occurrenceID
  ) %>%
  mutate(
    data_source = "GBIF",       # Add source column
    date = as.Date(date),       # Convert to date format
    record_id = as.character(record_id)  # Convert to character for combining
  )

cat("GBIF data standardized:", nrow(gbif_clean), "records\n\n")

# ============================================================================
# 5. STANDARDIZE iNATURALIST DATA
# ============================================================================

cat("Standardizing iNaturalist data...\n")

# Select and rename columns to match GBIF structure
inat_clean <- inat_raw %>%
  select(
    scientific_name,            # Scientific name
    common_name,                # Common name
    latitude,                   # Latitude coordinate
    longitude,                  # Longitude coordinate
    observed_on,                # Date of observation
    quality_grade,              # Quality (research, needs_id, casual)
    place_guess,                # Location description
    user_login,                 # Observer username
    id                          # Unique record ID
  ) %>%
  rename(
    scientificName = scientific_name,
    species = scientific_name,  # Use scientific name as species
    date = observed_on,
    locality = place_guess,
    observer = user_login,
    record_id = id
  ) %>%
  mutate(
    data_source = "iNaturalist",
    basis = "HumanObservation",
    date = as.Date(date),
    year = year(date),
    month = month(date),
    day = day(date),
    stateProvince = "Gilgit-Baltistan",
    latitude = as.numeric(latitude),
    longitude = as.numeric(longitude),
    count = 1,                  # iNat records are typically single observations
    uncertainty = NA,           # iNat doesn't provide this metric
    record_id = as.character(record_id)  # Convert to character for combining
  )

cat("iNaturalist data standardized:", nrow(inat_clean), "records\n\n")

# ============================================================================
# 6. COMBINE DATASETS
# ============================================================================

cat("Combining GBIF and iNaturalist data...\n")

# Combine both datasets
# bind_rows automatically handles columns that don't match
combined_data <- bind_rows(gbif_clean, inat_clean)

cat("Combined dataset created:", nrow(combined_data), "records\n\n")

# ============================================================================
# 7. DATA QUALITY FILTERS
# ============================================================================

cat("Applying data quality filters...\n")

# Store original count for comparison
original_count <- nrow(combined_data)

# Filter 1: Remove records without species identification
combined_data <- combined_data %>%
  filter(!is.na(species) & species != "" & species != "NA")

cat("After removing records without species:", nrow(combined_data), "records\n")

# Filter 2: Remove records without coordinates
combined_data <- combined_data %>%
  filter(!is.na(latitude) & !is.na(longitude))

cat("After removing records without coordinates:", nrow(combined_data), "records\n")

# Filter 3: Verify coordinates are within Gilgit-Baltistan boundaries
# Same boundaries we used for download
gb_lat_min <- 34.0
gb_lat_max <- 37.0
gb_lon_min <- 72.0
gb_lon_max <- 77.5

combined_data <- combined_data %>%
  filter(
    latitude >= gb_lat_min & latitude <= gb_lat_max,
    longitude >= gb_lon_min & longitude <= gb_lon_max
  )

cat("After boundary verification:", nrow(combined_data), "records\n")

# Filter 4: Remove obvious coordinate errors (0,0 or other impossible values)
combined_data <- combined_data %>%
  filter(latitude != 0 | longitude != 0)

cat("After removing coordinate errors:", nrow(combined_data), "records\n")

# Filter 5: Remove records with very high uncertainty (>10km)
# Only applies to GBIF records that have this field
combined_data <- combined_data %>%
  filter(is.na(uncertainty) | uncertainty <= 10000)

cat("After uncertainty filter:", nrow(combined_data), "records\n")

# Print summary of filtering
records_removed <- original_count - nrow(combined_data)
percent_removed <- round((records_removed / original_count) * 100, 1)

cat("\nQuality filtering summary:\n")
cat("Records removed:", records_removed, "(", percent_removed, "%)\n")
cat("Records retained:", nrow(combined_data), "\n\n")

# ============================================================================
# 8. REMOVE DUPLICATES
# ============================================================================

cat("Removing duplicate records...\n")

# Count before removing duplicates
before_dedup <- nrow(combined_data)

# Remove exact duplicates based on species, location, and date
# This catches the same observation recorded in both databases
combined_data <- combined_data %>%
  distinct(species, latitude, longitude, date, .keep_all = TRUE)

# Calculate duplicates removed
duplicates_removed <- before_dedup - nrow(combined_data)

cat("Duplicates removed:", duplicates_removed, "\n")
cat("Final dataset size:", nrow(combined_data), "records\n\n")

# ============================================================================
# 9. TAXONOMY STANDARDIZATION
# ============================================================================

cat("Standardizing species names...\n")

# Count species before cleaning
species_before <- n_distinct(combined_data$species)

# Remove subspecies designations to get species-level names
# Example: "Passer domesticus domesticus" becomes "Passer domesticus"
combined_data <- combined_data %>%
  mutate(
    # Extract first two words (genus and species)
    species_clean = word(species, 1, 2),
    # Keep original for reference
    original_name = species,
    # Use cleaned name as main species column
    species = species_clean
  ) %>%
  select(-species_clean)

# Count species after cleaning
species_after <- n_distinct(combined_data$species)

cat("Species names before standardization:", species_before, "\n")
cat("Species names after standardization:", species_after, "\n\n")

# ============================================================================
# 10. ADD TEMPORAL CATEGORIES
# ============================================================================

cat("Adding temporal categories...\n")

# Add season based on month
combined_data <- combined_data %>%
  mutate(
    season = case_when(
      month %in% c(12, 1, 2) ~ "Winter",
      month %in% c(3, 4, 5) ~ "Spring",
      month %in% c(6, 7, 8) ~ "Summer",
      month %in% c(9, 10, 11) ~ "Autumn",
      TRUE ~ NA_character_
    )
  )

# Add decade for temporal analysis
combined_data <- combined_data %>%
  mutate(
    decade = floor(year / 10) * 10
  )

cat("Temporal categories added\n\n")

# ============================================================================
# 11. CREATE SPECIES LIST
# ============================================================================

cat("Creating species list...\n")

# Create a comprehensive species list with counts
species_list <- combined_data %>%
  group_by(species, scientificName) %>%
  summarise(
    total_records = n(),
    gbif_records = sum(data_source == "GBIF"),
    inat_records = sum(data_source == "iNaturalist"),
    first_year = min(year, na.rm = TRUE),
    last_year = max(year, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(desc(total_records))

cat("Species list created:", nrow(species_list), "unique species\n\n")

# ============================================================================
# 12. SUMMARY STATISTICS
# ============================================================================

cat("=== CLEANED DATA SUMMARY ===\n\n")

cat("Total records:", nrow(combined_data), "\n")
cat("Unique species:", n_distinct(combined_data$species), "\n")
cat("GBIF records:", sum(combined_data$data_source == "GBIF"), "\n")
cat("iNaturalist records:", sum(combined_data$data_source == "iNaturalist"), "\n\n")

cat("Temporal coverage:\n")
cat("Year range:", min(combined_data$year, na.rm = TRUE), "to", 
    max(combined_data$year, na.rm = TRUE), "\n")
cat("Records by decade:\n")
print(table(combined_data$decade))
cat("\n")

cat("Seasonal distribution:\n")
print(table(combined_data$season))
cat("\n")

cat("Top 10 most recorded species:\n")
print(head(species_list, 10))
cat("\n")

# ============================================================================
# 13. SAVE CLEANED DATA
# ============================================================================

cat("Saving cleaned data...\n")

# Save main combined dataset
write.csv(combined_data, 
          "data/processed/birds_combined.csv", 
          row.names = FALSE)

# Save species list
write.csv(species_list, 
          "data/processed/species_list.csv", 
          row.names = FALSE)

# Create and save cleaning summary
cleaning_summary <- data.frame(
  Cleaning_Date = Sys.Date(),
  Original_Records = original_count,
  Records_Removed = records_removed,
  Percent_Removed = percent_removed,
  Duplicates_Removed = duplicates_removed,
  Final_Records = nrow(combined_data),
  Unique_Species = n_distinct(combined_data$species),
  GBIF_Records = sum(combined_data$data_source == "GBIF"),
  iNat_Records = sum(combined_data$data_source == "iNaturalist"),
  Year_Min = min(combined_data$year, na.rm = TRUE),
  Year_Max = max(combined_data$year, na.rm = TRUE)
)

write.csv(cleaning_summary, 
          "data/processed/cleaning_summary.csv", 
          row.names = FALSE)

cat("\nFiles saved in data/processed/:\n")
cat("  - birds_combined.csv (main dataset)\n")
cat("  - species_list.csv (species summary)\n")
cat("  - cleaning_summary.csv (cleaning report)\n\n")

cat("=== DATA CLEANING COMPLETE ===\n")

# ============================================================================
# END OF SCRIPT
# ============================================================================