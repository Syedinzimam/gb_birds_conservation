################################################################################
# SCRIPT 03: EXPLORATORY DATA ANALYSIS
# Project: Conservation Priority Assessment of Birds in Gilgit-Baltistan
# Author: Syed Inzimam Ali Shah
# Date: December 2025
# Purpose: Explore and visualize cleaned bird occurrence data
################################################################################

# Clear workspace
rm(list = ls())

# ============================================================================
# 1. LOAD REQUIRED LIBRARIES
# ============================================================================

library(tidyverse)      # Data manipulation and visualization
library(sf)             # Spatial data handling
library(rnaturalearth)  # Country/region boundaries
library(ggplot2)        # Advanced plotting
library(viridis)        # Color palettes
library(scales)         # Scale functions for plots

cat("Libraries loaded successfully!\n\n")

# ============================================================================
# 2. SET WORKING DIRECTORY AND CREATE OUTPUT FOLDERS
# ============================================================================

setwd("C:/gb-birds-conservation")

# Create output folders
dir.create("outputs", showWarnings = FALSE)
dir.create("outputs/figures", showWarnings = FALSE)
dir.create("outputs/tables", showWarnings = FALSE)

cat("Output folders created!\n\n")

# ============================================================================
# 3. LOAD CLEANED DATA
# ============================================================================

cat("Loading cleaned data...\n")

# Load main dataset
birds <- read.csv("data/processed/birds_combined.csv", stringsAsFactors = FALSE)

# Load species list
species_list <- read.csv("data/processed/species_list.csv", stringsAsFactors = FALSE)

# Convert date column back to Date format
birds$date <- as.Date(birds$date)

cat("Data loaded successfully!\n")
cat("Total records:", nrow(birds), "\n")
cat("Unique species:", n_distinct(birds$species), "\n\n")

# ============================================================================
# 4. BASIC SUMMARY STATISTICS
# ============================================================================

cat("=== BASIC STATISTICS ===\n\n")

# Overall summary
cat("Dataset overview:\n")
cat("Total observations:", nrow(birds), "\n")
cat("Unique species:", n_distinct(birds$species), "\n")
cat("Date range:", min(birds$year, na.rm = TRUE), "-", 
    max(birds$year, na.rm = TRUE), "\n")
cat("Spatial extent:\n")
cat("  Latitude:", round(min(birds$latitude, na.rm = TRUE), 2), "to", 
    round(max(birds$latitude, na.rm = TRUE), 2), "\n")
cat("  Longitude:", round(min(birds$longitude, na.rm = TRUE), 2), "to", 
    round(max(birds$longitude, na.rm = TRUE), 2), "\n\n")

# Data source breakdown
cat("Records by data source:\n")
source_summary <- table(birds$data_source)
print(source_summary)
cat("\n")

# ============================================================================
# 5. TEMPORAL PATTERNS
# ============================================================================

cat("Analyzing temporal patterns...\n")

# Records by year
records_by_year <- birds %>%
  count(year) %>%
  arrange(year)

# Records by season
records_by_season <- birds %>%
  count(season) %>%
  filter(!is.na(season))

# Records by month
records_by_month <- birds %>%
  count(month) %>%
  filter(!is.na(month))

cat("Temporal summaries created\n\n")

# ============================================================================
# 6. SPECIES FREQUENCY ANALYSIS
# ============================================================================

cat("Analyzing species frequency...\n")

# Calculate frequency categories
species_frequency <- species_list %>%
  mutate(
    frequency_category = case_when(
      total_records >= 100 ~ "Very Common (100+)",
      total_records >= 50 ~ "Common (50-99)",
      total_records >= 20 ~ "Moderate (20-49)",
      total_records >= 10 ~ "Uncommon (10-19)",
      total_records >= 5 ~ "Rare (5-9)",
      TRUE ~ "Very Rare (1-4)"
    )
  )

# Count species in each category
frequency_table <- table(species_frequency$frequency_category)

cat("Species frequency distribution:\n")
print(frequency_table)
cat("\n")

# ============================================================================
# 7. VISUALIZATION 1: TEMPORAL TRENDS
# ============================================================================

cat("Creating temporal trend plots...\n")

# Plot 1: Records per year
p1 <- ggplot(records_by_year, aes(x = year, y = n)) +
  geom_line(color = "#2c7bb6", size = 1.2) +
  geom_point(color = "#2c7bb6", size = 2) +
  labs(
    title = "Bird Observations Over Time in Gilgit-Baltistan",
    x = "Year",
    y = "Number of Records"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(size = 14, face = "bold"),
    axis.title = element_text(size = 12),
    axis.text = element_text(size = 10)
  )

ggsave("outputs/figures/01_temporal_trend.png", p1, 
       width = 10, height = 6, dpi = 300)

# Plot 2: Records by season
p2 <- ggplot(records_by_season, aes(x = reorder(season, -n), y = n, fill = season)) +
  geom_col() +
  scale_fill_manual(values = c(
    "Spring" = "#66c2a5",
    "Summer" = "#fc8d62",
    "Autumn" = "#8da0cb",
    "Winter" = "#e78ac3"
  )) +
  labs(
    title = "Seasonal Distribution of Bird Observations",
    x = "Season",
    y = "Number of Records"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(size = 14, face = "bold"),
    axis.title = element_text(size = 12),
    axis.text = element_text(size = 10),
    legend.position = "none"
  )

ggsave("outputs/figures/02_seasonal_distribution.png", p2, 
       width = 8, height = 6, dpi = 300)

# Plot 3: Records by month
p3 <- ggplot(records_by_month, aes(x = month, y = n)) +
  geom_col(fill = "#2c7bb6") +
  scale_x_continuous(breaks = 1:12, 
                     labels = c("Jan", "Feb", "Mar", "Apr", "May", "Jun",
                                "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")) +
  labs(
    title = "Monthly Distribution of Bird Observations",
    x = "Month",
    y = "Number of Records"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(size = 14, face = "bold"),
    axis.title = element_text(size = 12),
    axis.text = element_text(size = 10)
  )

ggsave("outputs/figures/03_monthly_distribution.png", p3, 
       width = 10, height = 6, dpi = 300)

cat("Temporal plots saved\n\n")

# ============================================================================
# 8. VISUALIZATION 2: SPECIES PATTERNS
# ============================================================================

cat("Creating species pattern plots...\n")

# Plot 4: Species frequency distribution
frequency_order <- c("Very Rare (1-4)", "Rare (5-9)", "Uncommon (10-19)",
                     "Moderate (20-49)", "Common (50-99)", "Very Common (100+)")

species_frequency$frequency_category <- factor(
  species_frequency$frequency_category,
  levels = frequency_order
)

p4 <- ggplot(species_frequency, aes(x = frequency_category)) +
  geom_bar(fill = "#2c7bb6") +
  labs(
    title = "Species Frequency Distribution",
    x = "Frequency Category",
    y = "Number of Species"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(size = 14, face = "bold"),
    axis.title = element_text(size = 12),
    axis.text.x = element_text(angle = 45, hjust = 1, size = 10)
  )

ggsave("outputs/figures/04_species_frequency.png", p4, 
       width = 10, height = 6, dpi = 300)

# Plot 5: Top 20 most recorded species
top20_species <- species_list %>%
  arrange(desc(total_records)) %>%
  head(20)

p5 <- ggplot(top20_species, aes(x = reorder(species, total_records), y = total_records)) +
  geom_col(fill = "#2c7bb6") +
  coord_flip() +
  labs(
    title = "Top 20 Most Recorded Bird Species",
    x = "Species",
    y = "Number of Records"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(size = 14, face = "bold"),
    axis.title = element_text(size = 12),
    axis.text = element_text(size = 9)
  )

ggsave("outputs/figures/05_top20_species.png", p5, 
       width = 10, height = 8, dpi = 300)

cat("Species pattern plots saved\n\n")

# ============================================================================
# 9. VISUALIZATION 3: SPATIAL DISTRIBUTION
# ============================================================================

cat("Creating spatial distribution maps...\n")

# Convert to spatial object
birds_sf <- st_as_sf(birds, 
                     coords = c("longitude", "latitude"),
                     crs = 4326)

# Get Pakistan boundary for context
pakistan <- ne_countries(country = "Pakistan", returnclass = "sf", scale = "medium")

# Define GB bounding box
gb_bbox <- st_bbox(c(xmin = 72.0, ymin = 34.0, xmax = 77.5, ymax = 37.0), 
                   crs = st_crs(4326))

# Plot 6: Simple point map
p6 <- ggplot() +
  geom_sf(data = pakistan, fill = "grey90", color = "grey50") +
  geom_sf(data = birds_sf, alpha = 0.3, size = 0.5, color = "#2c7bb6") +
  coord_sf(xlim = c(72.0, 77.5), ylim = c(34.0, 37.0)) +
  labs(
    title = "Spatial Distribution of Bird Observations",
    subtitle = "Gilgit-Baltistan, Pakistan",
    x = "Longitude",
    y = "Latitude"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(size = 14, face = "bold"),
    plot.subtitle = element_text(size = 11)
  )

ggsave("outputs/figures/06_spatial_distribution.png", p6, 
       width = 10, height = 8, dpi = 300)

# Plot 7: Hexagonal binning for density
p7 <- ggplot() +
  geom_sf(data = pakistan, fill = "grey90", color = "grey50") +
  stat_bin_hex(data = birds, aes(x = longitude, y = latitude), bins = 30) +
  scale_fill_viridis_c(name = "Number of\nRecords", option = "plasma") +
  coord_sf(xlim = c(72.0, 77.5), ylim = c(34.0, 37.0)) +
  labs(
    title = "Bird Observation Density in Gilgit-Baltistan",
    x = "Longitude",
    y = "Latitude"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(size = 14, face = "bold"),
    legend.position = "right"
  )

ggsave("outputs/figures/07_observation_density.png", p7, 
       width = 10, height = 8, dpi = 300)

cat("Spatial maps saved\n\n")

# ============================================================================
# 10. VISUALIZATION 4: DATA SOURCE COMPARISON
# ============================================================================

cat("Creating data source comparison plots...\n")

# Plot 8: Records by source over time
source_temporal <- birds %>%
  filter(year >= 2010) %>%  # Focus on recent years with data from both sources
  count(year, data_source)

p8 <- ggplot(source_temporal, aes(x = year, y = n, color = data_source, group = data_source)) +
  geom_line(size = 1.2) +
  geom_point(size = 2) +
  scale_color_manual(values = c("GBIF" = "#2c7bb6", "iNaturalist" = "#d7191c")) +
  labs(
    title = "Data Contributions Over Time",
    x = "Year",
    y = "Number of Records",
    color = "Data Source"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(size = 14, face = "bold"),
    axis.title = element_text(size = 12),
    legend.position = "bottom"
  )

ggsave("outputs/figures/08_data_source_temporal.png", p8, 
       width = 10, height = 6, dpi = 300)

cat("Data source plots saved\n\n")

# ============================================================================
# 11. CREATE SUMMARY TABLES
# ============================================================================

cat("Creating summary tables...\n")

# Table 1: Top 30 species
top30_table <- species_list %>%
  arrange(desc(total_records)) %>%
  head(30) %>%
  select(species, scientificName, total_records, first_year, last_year)

write.csv(top30_table, 
          "outputs/tables/top30_species.csv", 
          row.names = FALSE)

# Table 2: Rare species (fewer than 5 records)
rare_species <- species_list %>%
  filter(total_records < 5) %>%
  arrange(total_records, species)

write.csv(rare_species, 
          "outputs/tables/rare_species.csv", 
          row.names = FALSE)

cat("Rare species identified:", nrow(rare_species), "\n")

# Table 3: Yearly summary
yearly_summary <- birds %>%
  group_by(year) %>%
  summarise(
    total_records = n(),
    unique_species = n_distinct(species),
    gbif_records = sum(data_source == "GBIF"),
    inat_records = sum(data_source == "iNaturalist")
  ) %>%
  arrange(year)

write.csv(yearly_summary, 
          "outputs/tables/yearly_summary.csv", 
          row.names = FALSE)

cat("Summary tables saved\n\n")

# ============================================================================
# 12. SPATIAL GRID ANALYSIS (Species Richness)
# ============================================================================

cat("Calculating species richness by grid cells...\n")

# Create a grid over the study area
# Grid cell size: 0.1 degrees (approximately 10km)
grid_size <- 0.1

# Round coordinates to create grid cells
birds_grid <- birds %>%
  mutate(
    grid_lon = round(longitude / grid_size) * grid_size,
    grid_lat = round(latitude / grid_size) * grid_size
  )

# Calculate species richness per grid cell
richness_grid <- birds_grid %>%
  group_by(grid_lon, grid_lat) %>%
  summarise(
    species_richness = n_distinct(species),
    total_records = n(),
    .groups = "drop"
  )

# Plot 9: Species richness heatmap
p9 <- ggplot() +
  geom_sf(data = pakistan, fill = "grey90", color = "grey50") +
  geom_tile(data = richness_grid, 
            aes(x = grid_lon, y = grid_lat, fill = species_richness)) +
  scale_fill_viridis_c(name = "Species\nRichness", option = "viridis") +
  coord_sf(xlim = c(72.0, 77.5), ylim = c(34.0, 37.0)) +
  labs(
    title = "Species Richness Across Gilgit-Baltistan",
    subtitle = "Grid cell size: 0.1° (~10 km)",
    x = "Longitude",
    y = "Latitude"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(size = 14, face = "bold"),
    plot.subtitle = element_text(size = 11)
  )

ggsave("outputs/figures/09_species_richness_map.png", p9, 
       width = 10, height = 8, dpi = 300)

# Save richness grid data
write.csv(richness_grid, 
          "outputs/tables/species_richness_grid.csv", 
          row.names = FALSE)

cat("Species richness analysis complete\n\n")

# ============================================================================
# 13. OBSERVATION EFFORT ANALYSIS
# ============================================================================

cat("Analyzing observation effort...\n")

# Calculate number of unique dates per grid cell (sampling effort)
effort_grid <- birds_grid %>%
  group_by(grid_lon, grid_lat) %>%
  summarise(
    unique_dates = n_distinct(date),
    unique_observers = n_distinct(ifelse(is.na(observer), "Unknown", observer)),
    .groups = "drop"
  )

# Merge with richness data
richness_effort <- richness_grid %>%
  left_join(effort_grid, by = c("grid_lon", "grid_lat"))

# Plot 10: Richness vs Effort
p10 <- ggplot(richness_effort, aes(x = unique_dates, y = species_richness)) +
  geom_point(alpha = 0.5, color = "#2c7bb6", size = 2) +
  geom_smooth(method = "lm", color = "#d7191c", se = TRUE) +
  labs(
    title = "Species Richness vs Observation Effort",
    x = "Number of Unique Survey Dates",
    y = "Species Richness"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(size = 14, face = "bold"),
    axis.title = element_text(size = 12)
  )

ggsave("outputs/figures/10_richness_vs_effort.png", p10, 
       width = 10, height = 6, dpi = 300)

cat("Observation effort analysis complete\n\n")

# ============================================================================
# 14. FINAL SUMMARY REPORT
# ============================================================================

cat("=== EXPLORATORY ANALYSIS SUMMARY ===\n\n")

cat("Files created:\n")
cat("\nFigures (outputs/figures/):\n")
cat("  01_temporal_trend.png\n")
cat("  02_seasonal_distribution.png\n")
cat("  03_monthly_distribution.png\n")
cat("  04_species_frequency.png\n")
cat("  05_top20_species.png\n")
cat("  06_spatial_distribution.png\n")
cat("  07_observation_density.png\n")
cat("  08_data_source_temporal.png\n")
cat("  09_species_richness_map.png\n")
cat("  10_richness_vs_effort.png\n")

cat("\nTables (outputs/tables/):\n")
cat("  top30_species.csv\n")
cat("  rare_species.csv\n")
cat("  yearly_summary.csv\n")
cat("  species_richness_grid.csv\n\n")

cat("Key findings:\n")
cat("- Total species:", n_distinct(birds$species), "\n")
cat("- Rare species (<5 records):", nrow(rare_species), "\n")
cat("- Observation period:", min(birds$year, na.rm = TRUE), "-", 
    max(birds$year, na.rm = TRUE), "\n")
cat("- Peak observation month:", 
    records_by_month$month[which.max(records_by_month$n)], "\n")
cat("- Highest richness grid cell:", 
    max(richness_grid$species_richness, na.rm = TRUE), "species\n\n")

cat("=== EXPLORATORY ANALYSIS COMPLETE ===\n")

# ============================================================================
# END OF SCRIPT
# ============================================================================