################################################################################
# SCRIPT 04: CONSERVATION PRIORITY ASSESSMENT
# Project: Conservation Priority Assessment of Birds in Gilgit-Baltistan
# Author: Syed Inzimam Ali Shah
# Date: December 2025
# Purpose: Identify priority species and areas for conservation using local criteria
################################################################################

# Clear workspace
rm(list = ls())

# ============================================================================
# 1. LOAD REQUIRED LIBRARIES
# ============================================================================

library(tidyverse)    # Data manipulation and visualization
library(sf)           # Spatial data handling
library(viridis)      # Color palettes

cat("Libraries loaded successfully!\n\n")

# ============================================================================
# 2. SET WORKING DIRECTORY
# ============================================================================

setwd("C:/gb-birds-conservation")

cat("Working directory set!\n\n")

# ============================================================================
# 3. LOAD DATA
# ============================================================================

cat("Loading data...\n")

# Load main bird dataset
birds <- read.csv("data/processed/birds_combined.csv", stringsAsFactors = FALSE)
birds$date <- as.Date(birds$date)

# Load species list
species_list <- read.csv("data/processed/species_list.csv", stringsAsFactors = FALSE)

cat("Data loaded successfully!\n")
cat("Total observations:", nrow(birds), "\n")
cat("Total species:", nrow(species_list), "\n\n")

# ============================================================================
# 4. SPECIES-LEVEL PRIORITY SCORING
# ============================================================================

cat("Calculating species priority scores...\n\n")

# ---- 4.1 RARITY SCORE ----
# Species with fewer observations are higher priority
cat("Calculating rarity scores...\n")

species_priority <- species_list %>%
  mutate(
    # Rarity score: inverse of log(records)
    # Very rare species (1-5 records) get high scores
    rarity_score = case_when(
      total_records <= 5 ~ 100,
      total_records <= 10 ~ 80,
      total_records <= 20 ~ 60,
      total_records <= 50 ~ 40,
      total_records <= 100 ~ 20,
      TRUE ~ 10
    )
  )

cat("Rarity scores calculated\n")

# ---- 4.2 RANGE RESTRICTION SCORE ----
# Species found in fewer locations are higher priority
cat("Calculating range restriction scores...\n")

# Calculate number of grid cells each species occupies
grid_size <- 0.1

species_range <- birds %>%
  mutate(
    grid_lon = round(longitude / grid_size) * grid_size,
    grid_lat = round(latitude / grid_size) * grid_size
  ) %>%
  group_by(species) %>%
  summarise(
    n_grid_cells = n_distinct(paste(grid_lon, grid_lat)),
    lat_range = max(latitude) - min(latitude),
    lon_range = max(longitude) - min(longitude),
    .groups = "drop"
  )

# Add range restriction score
species_range <- species_range %>%
  mutate(
    range_score = case_when(
      n_grid_cells <= 2 ~ 100,
      n_grid_cells <= 5 ~ 80,
      n_grid_cells <= 10 ~ 60,
      n_grid_cells <= 20 ~ 40,
      n_grid_cells <= 50 ~ 20,
      TRUE ~ 10
    )
  )

cat("Range restriction scores calculated\n")

# ---- 4.3 TEMPORAL TREND SCORE ----
# Species declining over time are higher priority
cat("Calculating temporal trend scores...\n")

# Calculate observations in early vs recent years
# Split data into two periods: before 2020 and 2020+
species_trend <- birds %>%
  mutate(
    period = ifelse(year < 2020, "early", "recent")
  ) %>%
  group_by(species, period) %>%
  summarise(n_obs = n(), .groups = "drop") %>%
  pivot_wider(names_from = period, values_from = n_obs, values_fill = 0) %>%
  mutate(
    # Calculate trend (positive = increasing, negative = declining)
    trend = recent - early,
    trend_score = case_when(
      # Declining species (observed before but not recently)
      early > 0 & recent == 0 ~ 100,
      # Declining trend
      trend < -5 ~ 80,
      trend < 0 ~ 60,
      # Stable
      trend >= 0 & trend <= 5 ~ 40,
      # Increasing
      TRUE ~ 20
    )
  )

cat("Temporal trend scores calculated\n")

# ---- 4.4 COMBINE ALL SCORES ----
cat("Combining priority scores...\n")

species_priority <- species_priority %>%
  left_join(species_range, by = "species") %>%
  left_join(species_trend %>% select(species, trend, trend_score), by = "species")

# Calculate overall priority score (weighted average)
# Weights: Rarity 40%, Range 30%, Trend 30%
species_priority <- species_priority %>%
  mutate(
    # Replace NA trend scores with 50 (neutral) for species without temporal data
    trend_score = ifelse(is.na(trend_score), 50, trend_score),
    
    # Calculate weighted priority score
    priority_score = (rarity_score * 0.40) + 
      (range_score * 0.30) + 
      (trend_score * 0.30),
    
    # Categorize priority level
    priority_level = case_when(
      priority_score >= 80 ~ "Critical Priority",
      priority_score >= 60 ~ "High Priority",
      priority_score >= 40 ~ "Medium Priority",
      TRUE ~ "Low Priority"
    )
  ) %>%
  arrange(desc(priority_score))

cat("Species priority scoring complete!\n\n")

# ============================================================================
# 5. IDENTIFY TOP PRIORITY SPECIES
# ============================================================================

cat("=== TOP PRIORITY SPECIES ===\n\n")

# Filter high and critical priority species
priority_species <- species_priority %>%
  filter(priority_level %in% c("Critical Priority", "High Priority")) %>%
  select(species, scientificName, priority_score, priority_level,
         total_records, n_grid_cells, rarity_score, range_score, trend_score)

cat("Critical Priority species:", 
    sum(species_priority$priority_level == "Critical Priority"), "\n")
cat("High Priority species:", 
    sum(species_priority$priority_level == "High Priority"), "\n")
cat("Medium Priority species:", 
    sum(species_priority$priority_level == "Medium Priority"), "\n")
cat("Low Priority species:", 
    sum(species_priority$priority_level == "Low Priority"), "\n\n")

# Show top 20 priority species
cat("Top 20 priority species for conservation monitoring:\n")
print(head(priority_species, 20))
cat("\n")

# ============================================================================
# 6. SPATIAL PRIORITY ASSESSMENT
# ============================================================================

cat("Calculating spatial priority areas...\n")

# Create grid for spatial analysis
birds_grid <- birds %>%
  mutate(
    grid_lon = round(longitude / grid_size) * grid_size,
    grid_lat = round(latitude / grid_size) * grid_size
  )

# Calculate metrics for each grid cell
grid_priority <- birds_grid %>%
  group_by(grid_lon, grid_lat) %>%
  summarise(
    # Basic richness
    species_richness = n_distinct(species),
    total_observations = n(),
    
    # Priority species metrics
    # Join with priority species to count how many priority species in each cell
    .groups = "drop"
  )

# Calculate priority species richness per cell
priority_species_list <- priority_species$species

priority_richness <- birds_grid %>%
  filter(species %in% priority_species_list) %>%
  group_by(grid_lon, grid_lat) %>%
  summarise(
    priority_species_richness = n_distinct(species),
    .groups = "drop"
  )

# Merge with main grid
grid_priority <- grid_priority %>%
  left_join(priority_richness, by = c("grid_lon", "grid_lat")) %>%
  mutate(priority_species_richness = ifelse(is.na(priority_species_richness), 
                                            0, priority_species_richness))

# Calculate sampling effort (number of unique dates)
sampling_effort <- birds_grid %>%
  group_by(grid_lon, grid_lat) %>%
  summarise(
    n_survey_dates = n_distinct(date),
    .groups = "drop"
  )

grid_priority <- grid_priority %>%
  left_join(sampling_effort, by = c("grid_lon", "grid_lat"))

# Calculate effort-corrected richness
# This accounts for sampling bias
grid_priority <- grid_priority %>%
  mutate(
    # Species per survey date (effort-corrected richness)
    corrected_richness = species_richness / log(n_survey_dates + 1)
  )

# Calculate area priority score
# Weights: Priority species 50%, Corrected richness 30%, Total richness 20%
grid_priority <- grid_priority %>%
  mutate(
    # Normalize scores to 0-100 scale
    priority_spp_norm = (priority_species_richness / 
                           max(priority_species_richness, na.rm = TRUE)) * 100,
    corrected_rich_norm = (corrected_richness / 
                             max(corrected_richness, na.rm = TRUE)) * 100,
    total_rich_norm = (species_richness / 
                         max(species_richness, na.rm = TRUE)) * 100,
    
    # Calculate area priority score
    area_priority_score = (priority_spp_norm * 0.50) + 
      (corrected_rich_norm * 0.30) + 
      (total_rich_norm * 0.20),
    
    # Categorize area priority
    area_priority_level = case_when(
      area_priority_score >= 70 ~ "Critical Priority",
      area_priority_score >= 50 ~ "High Priority",
      area_priority_score >= 30 ~ "Medium Priority",
      TRUE ~ "Low Priority"
    )
  )

cat("Spatial priority assessment complete!\n\n")

# ============================================================================
# 7. IDENTIFY TOP PRIORITY AREAS
# ============================================================================

cat("=== TOP PRIORITY AREAS ===\n\n")

priority_areas <- grid_priority %>%
  filter(area_priority_level %in% c("Critical Priority", "High Priority")) %>%
  arrange(desc(area_priority_score)) %>%
  select(grid_lon, grid_lat, area_priority_score, area_priority_level,
         species_richness, priority_species_richness, corrected_richness)

cat("Critical Priority areas:", 
    sum(grid_priority$area_priority_level == "Critical Priority"), "grid cells\n")
cat("High Priority areas:", 
    sum(grid_priority$area_priority_level == "High Priority"), "grid cells\n\n")

cat("Top 10 priority areas for conservation:\n")
print(head(priority_areas, 10))
cat("\n")

# ============================================================================
# 8. SAVE RESULTS
# ============================================================================

cat("Saving conservation priority results...\n")

# Save species priority list
write.csv(species_priority, 
          "outputs/tables/species_conservation_priorities.csv", 
          row.names = FALSE)

# Save top priority species
write.csv(priority_species, 
          "outputs/tables/high_priority_species.csv", 
          row.names = FALSE)

# Save spatial priority grid
write.csv(grid_priority, 
          "outputs/tables/area_conservation_priorities.csv", 
          row.names = FALSE)

# Save top priority areas
write.csv(priority_areas, 
          "outputs/tables/high_priority_areas.csv", 
          row.names = FALSE)

cat("Results saved!\n\n")

# ============================================================================
# 9. VISUALIZATIONS
# ============================================================================

cat("Creating conservation priority visualizations...\n")

# Load spatial data for maps
library(rnaturalearth)
pakistan <- ne_countries(country = "Pakistan", returnclass = "sf", scale = "medium")

# ---- Visualization 1: Priority Species Distribution ----
cat("Creating priority species distribution map...\n")

priority_obs <- birds %>%
  filter(species %in% priority_species_list)

p1 <- ggplot() +
  geom_sf(data = pakistan, fill = "grey90", color = "grey50") +
  geom_point(data = priority_obs, 
             aes(x = longitude, y = latitude, color = species),
             alpha = 0.6, size = 1.5) +
  coord_sf(xlim = c(72.0, 77.5), ylim = c(34.0, 37.0)) +
  labs(
    title = "Distribution of Priority Species in Gilgit-Baltistan",
    x = "Longitude",
    y = "Latitude",
    color = "Species"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(size = 14, face = "bold"),
    legend.position = "none"
  )

ggsave("outputs/figures/11_priority_species_distribution.png", p1, 
       width = 10, height = 8, dpi = 300)

# ---- Visualization 2: Area Priority Map ----
cat("Creating area priority heatmap...\n")

p2 <- ggplot() +
  geom_sf(data = pakistan, fill = "grey90", color = "grey50") +
  geom_tile(data = grid_priority, 
            aes(x = grid_lon, y = grid_lat, fill = area_priority_score)) +
  scale_fill_viridis_c(name = "Priority\nScore", option = "magma") +
  coord_sf(xlim = c(72.0, 77.5), ylim = c(34.0, 37.0)) +
  labs(
    title = "Conservation Priority Areas in Gilgit-Baltistan",
    subtitle = "Based on rarity, range restriction, and trends",
    x = "Longitude",
    y = "Latitude"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(size = 14, face = "bold"),
    plot.subtitle = element_text(size = 11)
  )

ggsave("outputs/figures/12_conservation_priority_areas.png", p2, 
       width = 10, height = 8, dpi = 300)

# ---- Visualization 3: Priority Species Count by Area ----
cat("Creating priority species richness map...\n")

p3 <- ggplot() +
  geom_sf(data = pakistan, fill = "grey90", color = "grey50") +
  geom_tile(data = grid_priority %>% filter(priority_species_richness > 0), 
            aes(x = grid_lon, y = grid_lat, fill = priority_species_richness)) +
  scale_fill_viridis_c(name = "Priority\nSpecies", option = "plasma") +
  coord_sf(xlim = c(72.0, 77.5), ylim = c(34.0, 37.0)) +
  labs(
    title = "Priority Species Richness Across Gilgit-Baltistan",
    x = "Longitude",
    y = "Latitude"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(size = 14, face = "bold")
  )

ggsave("outputs/figures/13_priority_species_richness.png", p3, 
       width = 10, height = 8, dpi = 300)

# ---- Visualization 4: Priority Level Distribution ----
cat("Creating priority level summary plot...\n")

p4 <- ggplot(species_priority, aes(x = priority_level, fill = priority_level)) +
  geom_bar() +
  scale_fill_manual(values = c(
    "Critical Priority" = "#d73027",
    "High Priority" = "#fc8d59",
    "Medium Priority" = "#fee090",
    "Low Priority" = "#91bfdb"
  )) +
  labs(
    title = "Species Distribution by Conservation Priority Level",
    x = "Priority Level",
    y = "Number of Species"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(size = 14, face = "bold"),
    legend.position = "none"
  )

ggsave("outputs/figures/14_priority_level_distribution.png", p4, 
       width = 8, height = 6, dpi = 300)

cat("Visualizations complete!\n\n")

# ============================================================================
# 10. CONSERVATION RECOMMENDATIONS
# ============================================================================

cat("=== CONSERVATION RECOMMENDATIONS ===\n\n")

# Identify gaps (areas with high richness but low priority species)
potential_gaps <- grid_priority %>%
  filter(species_richness >= 30 & priority_species_richness == 0) %>%
  arrange(desc(species_richness))

cat("Under-surveyed areas (high richness, no priority species):", 
    nrow(potential_gaps), "cells\n")

# Identify areas needing immediate attention
critical_areas <- grid_priority %>%
  filter(area_priority_level == "Critical Priority") %>%
  arrange(desc(area_priority_score))

cat("Critical priority areas needing immediate conservation:", 
    nrow(critical_areas), "cells\n\n")

# ============================================================================
# 11. FINAL SUMMARY
# ============================================================================

cat("=== CONSERVATION PRIORITY ASSESSMENT SUMMARY ===\n\n")

cat("Species Assessment:\n")
cat("- Total species evaluated:", nrow(species_priority), "\n")
cat("- Critical priority species:", 
    sum(species_priority$priority_level == "Critical Priority"), "\n")
cat("- High priority species:", 
    sum(species_priority$priority_level == "High Priority"), "\n")
cat("- Species requiring monitoring:", nrow(priority_species), "\n\n")

cat("Spatial Assessment:\n")
cat("- Total grid cells analyzed:", nrow(grid_priority), "\n")
cat("- Critical priority areas:", 
    sum(grid_priority$area_priority_level == "Critical Priority"), "\n")
cat("- High priority areas:", 
    sum(grid_priority$area_priority_level == "High Priority"), "\n\n")

cat("Files created:\n")
cat("Tables (outputs/tables/):\n")
cat("  - species_conservation_priorities.csv\n")
cat("  - high_priority_species.csv\n")
cat("  - area_conservation_priorities.csv\n")
cat("  - high_priority_areas.csv\n\n")

cat("Figures (outputs/figures/):\n")
cat("  - 11_priority_species_distribution.png\n")
cat("  - 12_conservation_priority_areas.png\n")
cat("  - 13_priority_species_richness.png\n")
cat("  - 14_priority_level_distribution.png\n\n")

cat("=== CONSERVATION ASSESSMENT COMPLETE ===\n")

# ============================================================================
# END OF SCRIPT
# ============================================================================