# =============================================================================
# 05_shortlist_2025.R                   (formerly new2025stats.R, Sept 2026)
# -----------------------------------------------------------------------------
# Build a shortlist of Manchester primary schools for a Reception
# application, combining:
#   * KS2 results 2024/25 (% at expected and higher standard, RWM combined)
#   * suspensions 2024/25
#   * admissions 2026: places, unfilled places and the furthest distance
#     offered (the effective "catchment"), from 01_scrape_admissions_2026.R
#   * straight-line distance from home
#
# Each school gets a composite score; schools we could realistically get into
# are mapped and coloured by that score.
#
# A final section maps the top 20% of English secondaries on Attainment 8.
#
# Inputs : data/ks2_school_attainment_data.csv              (KS2 2024/25)
#          data/edubasealldata20260126.csv                   (GIAS school locations)
#          data/suspensions-and-permanent-exclusions-in-england_2024-25/data/exc_school.csv
#          data/manchester_primary_school_places.csv        (from script 01)
#          data/202425_performance_tables_schools_revised.csv (KS4 2024/25)
# Outputs: outputs/maps/schools_to_look_at.html
#          outputs/maps/secondary_top20pc_attainment8.html
# =============================================================================

source("R/00_helpers.R")

# Home location (WGS84 decimal degrees) used for distance-to-school.
HOME_LON <- NA_real_  # ADD YOUR HOME COORDS HERE (longitude, e.g. -2.24)
HOME_LAT <- NA_real_  # ADD YOUR HOME COORDS HERE (latitude, e.g. 53.48)
if (is.na(HOME_LON) || is.na(HOME_LAT)) stop("Set HOME_LON / HOME_LAT at the top of 05_shortlist_2025.R")

# How much more distance counts than each attainment / behaviour measure in
# the composite score (see Part 3).
DIST_WEIGHT <- 10

METRES_PER_MILE <- 1609.344


# =============================================================================
# PART 1: Load and join KS2 results, locations and suspensions
# =============================================================================

ks2 <- read.csv("data/ks2_school_attainment_data.csv") %>% clean_names()

# School locations from the full GIAS (Get Information About Schools) extract:
# URN -> British National Grid easting/northing
locations <- read.csv("data/edubasealldata20260126.csv", encoding = "latin1") %>%
  select(URN, Easting, Northing)

sus <- read.csv("data/suspensions-and-permanent-exclusions-in-england_2024-25/data/exc_school.csv") %>%
  filter(time_period == 202425) %>%
  select(school_urn, perm_excl_rate, susp_rate, one_plus_susp_rate)

# One row per school: whole cohort, reading/writing/maths combined, 2024/25
ks2_all <- ks2 %>%
  filter(time_period == 202425,
         breakdown == "Total",
         subject == "Reading, writing and maths") %>%
  left_join(locations, by = c("school_urn" = "URN")) %>%
  left_join(sus, by = "school_urn") %>%
  mutate(across(c(expected_standard_pupil_percent, higher_standard_pupil_percent,
                  perm_excl_rate, susp_rate, one_plus_susp_rate), to_num))


# ---- Do schools with more suspensions get worse results? ----------------------

#' Scatter of a KS2 measure against % of pupils suspended, with Co-op Academy
#' New Islington highlighted in red.
plot_vs_suspensions <- function(y_col) {
  highlight <- ks2_all %>% filter(grepl("New Islington", school_name))
  ggplot(ks2_all, aes(x = one_plus_susp_rate, y = .data[[y_col]])) +
    geom_point() +
    geom_smooth() +
    scale_x_pseudolog() +
    geom_point(data = highlight, colour = "red", size = 4) +
    labs(x = "% pupils with 1+ suspension (2024/25)", y = y_col)
}

plot_vs_suspensions("higher_standard_pupil_percent")
plot_vs_suspensions("expected_standard_pupil_percent")


# =============================================================================
# PART 2: Add admissions ("catchment") data for Manchester primaries
# =============================================================================

mcr_schools <- read.csv("data/manchester_primary_school_places.csv")

# Council and DfE names often differ ("St Anne’s RC Primary School (Crumpsall)"
# vs "St Anne's RC Primary School Crumpsall Manchester"), and many names are
# shared by schools elsewhere in England. So:
#   1. straighten curly apostrophes / non-breaking hyphens,
#   2. apply the hand-checked fixes below (keys use straight apostrophes),
#   3. otherwise drop a trailing "(Area)" from the council name,
#   4. match case-insensitively against Manchester (LA 352) schools only.
# All 139 schools match exactly one DfE record this way (checked Oct 2026).
name_fixes <- c(
  "Abbey Hey Primary School"                               = "Abbey Hey Primary Academy",
  "Abraham Moss Primary School"                            = "Abraham Moss Community School",
  "Acacias Primary School"                                 = "Acacias Community Primary School",
  "All Saints CofE Primary School (Newton Heath)"          = "All Saints C of E Primary School",
  "Ashbury Meadow Community Primary School"                = "Ashbury Meadow Primary School",
  "Briscoe Lane Primary School"                            = "Briscoe Lane Academy",
  "Cavendish Road Primary School"                          = "Cavendish Primary School",
  "Chapel Street Primary School"                           = "Chapel Street Community Primary School",
  "Chorlton Park Primary School"                           = "Chorlton Park Primary",
  "Christ the King RC Primary School"                      = "Christ The King RC Primary School Manchester",
  "Co-op Academy New Islington School"                     = "Co-op Academy New Islington",
  "Cringle Brook Community Primary School"                 = "Cringle Brook Primary School",
  "Crossacres Primary School"                              = "Crossacres Primary Academy",
  "Crosslee Primary School"                                = "Crosslee Community Primary School",
  "Higher Openshaw Community Primary School"               = "Higher Openshaw Community School",
  "Holy Name RC Primary School"                            = "Holy Name Roman Catholic Primary School Manchester",
  "Longsight Community Primary School"                     = "Longsight Community Primary",
  "Mount Carmel RC Primary School"                         = "Mount Carmel RC Primary School, a Voluntary Academy",
  "Old Hall Drive Primary School"                          = "Old Hall Drive Academy",
  "Old Moat Community Primary School"                      = "Old Moat Primary School",
  "Our Lady's RC Primary School"                           = "Our Lady's RC Primary School Manchester",
  "Park View Community Primary School"                     = "Park View Community Primary Academy",
  "Peel Hall Primary School"                               = "Peel Hall Primary Academy",
  "Sacred Heart RC Primary (Gorton)"                       = "Sacred Heart RC Primary School",
  "Seymour Road Primary School"                            = "Seymour Road Academy",
  "St John Fisher and Thomas More Catholic Primary School" = "Ss John Fisher and Thomas More Catholic Primary School",
  "St Agnes CofE Primary School"                           = "St Agnes C of E Primary School",
  "St Anne's RC Primary School (Crumpsall)"                = "St Anne's RC Primary School Crumpsall Manchester",
  "St Anthony's RC Primary School"                         = "St Anthony's Catholic Primary School",
  "St Barnabas' CofE Primary Academy"                      = "St Barnabas CofE Primary Academy",
  "St Bernard's RC Primary School"                         = "St Bernard's RC Primary School Manchester",
  "St Chad's RC Primary School"                            = "St Chad's Roman Catholic Primary School, a Voluntary Academy",
  "St Francis RC Primary School"                           = "St Francis RC Primary School, A Voluntary Academy",
  "St James' CofE Primary School (Gorton)"                 = "St James' CofE Primary School Gorton",
  "St James' CofE Primary School (Rusholme)"               = "St James' CofE Primary School, Birch-in-Rusholme",
  "St Joseph's RC Primary School"                          = "St Joseph's RC Primary School Manchester",
  "St Kentigern's RC Primary School"                       = "St Kentigern's RC Primary School, a Voluntary Academy",
  "St Margaret Mary's RC Primary School"                   = "St Margaret Mary's RC Primary School Manchester",
  "St Mary's CofE Primary School (Moss Side)"              = "St Mary's CofE Junior and Infant School",
  "St Mary's CofE Primary School (Moston)"                 = "St Mary's CofE Primary School Moston",
  "St Mary's RC Primary School (Levenshulme)"              = "St Mary's RC Primary School Manchester",
  "St Peter's R.C. Primary School"                         = "St Peter's Catholic Primary School",
  "St Philip's CofE Primary School"                        = "St Philip's Church of England Primary School",
  "St Wilfrid's CofE Primary School (Newton Heath)"        = "St Wilfrid's CofE Junior and Infant School",
  "St Wilfrid's CofE Aided Primary School (Northenden)"    = "St Wilfrid's CofE Aided Primary School Northenden",
  "The Divine Mercy RC Primary School"                     = "The Divine Mercy Roman Catholic Primary School",
  "The Olive School"                                       = "The Olive School, Manchester",
  "Unity Community Primary School"                         = "Unity Community Primary",
  "William Hulme's Grammar School Academy"                 = "William Hulme's Grammar School"
)

mcr_ks2 <- ks2_all %>%
  filter(str_starts(as.character(school_laestab), "352")) %>%   # Manchester LA
  mutate(match_key = str_to_lower(school_name)) %>%
  select(-school_name)

mcr_schools <- mcr_schools %>%
  mutate(
    clean_name = str_replace_all(school_name, c("\u2019" = "'", "\u2011" = "-")),
    dfe_name   = coalesce(unname(name_fixes[clean_name]),
                          str_remove(clean_name, "\\s*\\(.*\\)$")),
    match_key  = str_to_lower(dfe_name)
  ) %>%
  left_join(mcr_ks2, by = "match_key") %>%
  rename(easting = Easting, northing = Northing)

# Sanity checks: should both return nothing
mcr_schools %>% filter(is.na(school_urn)) %>% pull(school_name)  # unmatched
mcr_schools %>% filter(is.na(easting))    %>% pull(school_name)  # no location

# Home in British National Grid so distances are in metres
home <- st_sfc(st_point(c(HOME_LON, HOME_LAT)), crs = 4326) %>%
  st_transform(27700) %>%
  st_coordinates()

mcr_schools <- mcr_schools %>%
  mutate(
    # Furthest distance (miles) offered in 2026. 0 = everyone who applied got in.
    # NA = places allocated by the school's own (usually faith) criteria.
    distance = case_when(
      str_detect(criteria, "^All on-time applicants (were )?offered") ~ 0,
      TRUE ~ as.numeric(str_extract(criteria, "[0-9.]+(?=\\s*miles)"))
    ),
    # Straight-line distance from home, in miles
    dist_to_home = sqrt((easting - home[, "X"])^2 + (northing - home[, "Y"])^2) / METRES_PER_MILE,
    # "In catchment" = school had spare places, or home is within the last
    # distance offered. Faith-criteria schools with no spare places come out NA.
    in_catchment = if_else(unfilled_places > 0 | dist_to_home <= distance, 1, 0)
  )


# =============================================================================
# PART 3: Composite score and shortlist map
# =============================================================================
# Each measure is z-scored across all Manchester primaries, then
#   score = z(% expected) + z(% higher) - z(% suspended) - DIST_WEIGHT * z(distance)
# so higher = better results, fewer suspensions and (above all) closer to home.

mcr_schools <- mcr_schools %>%
  mutate(
    z_expected = scale(expected_standard_pupil_percent)[, 1],
    z_higher   = scale(higher_standard_pupil_percent)[, 1],
    z_one_susp = scale(one_plus_susp_rate)[, 1],
    z_dist     = scale(dist_to_home)[, 1],
    composite_score = z_expected + z_higher - z_one_susp - DIST_WEIGHT * z_dist
  )

# Realistic options: in catchment and within 10 miles
shortlist <- mcr_schools %>%
  filter(in_catchment == 1, dist_to_home < 10) %>%
  st_as_sf(coords = c("easting", "northing"), crs = 27700, remove = FALSE, na.fail = FALSE) %>%
  st_transform(4326)

shortlist %>%
  st_drop_geometry() %>%
  arrange(desc(composite_score)) %>%
  select(school_name, composite_score, expected_standard_pupil_percent,
         higher_standard_pupil_percent, one_plus_susp_rate, dist_to_home) %>%
  View()

pal <- colorNumeric(palette = "viridis", domain = shortlist$composite_score)

shortlist_map <- leaflet() %>%
  addProviderTiles(providers$Esri.WorldStreetMap) %>%
  addCircleMarkers(data = shortlist,
                   color = ~pal(composite_score),
                   opacity = 1,
                   fillOpacity = 0.8,
                   popup = ~paste("School: ", school_name,
                                  "<br>Composite score: ", round(composite_score, 2),
                                  "<br>Expected standard %: ", expected_standard_pupil_percent,
                                  "<br>Higher standard %: ", higher_standard_pupil_percent,
                                  "<br>Permanent exclusion rate: ", perm_excl_rate,
                                  "<br>Suspension rate: ", susp_rate,
                                  "<br>One+ suspension rate: ", one_plus_susp_rate,
                                  "<br>Distance from home: ", round(dist_to_home, 2), " miles")) %>%
  addLegend(pal = pal, values = shortlist$composite_score, title = "Composite score")
shortlist_map
save_map(shortlist_map, "schools_to_look_at.html")


# =============================================================================
# PART 4: Secondary schools - top 20% in England on Attainment 8 (2024/25)
# =============================================================================

ks4 <- read.csv("data/202425_performance_tables_schools_revised.csv") %>%
  clean_names()

top20pc_secondary <- ks4 %>%
  filter(breakdown_topic == "Total") %>%
  mutate(attainment8_average = to_num(attainment8_average)) %>%
  filter(attainment8_average > quantile(attainment8_average, 0.8, na.rm = TRUE)) %>%
  left_join(locations, by = c("school_urn" = "URN"))

sum(is.na(top20pc_secondary$Easting))  # schools that couldn't be located

top20pc_secondary <- top20pc_secondary %>%
  st_as_sf(coords = c("Easting", "Northing"), crs = 27700, na.fail = FALSE) %>%
  st_transform(4326)

secondary_map <- leaflet() %>%
  addTiles() %>%
  addCircles(data = top20pc_secondary,
             color = "black",
             opacity = 1,
             popup = ~paste("School: ", school_name, "Attainment: ", attainment8_average))
secondary_map
save_map(secondary_map, "secondary_top20pc_attainment8.html")
