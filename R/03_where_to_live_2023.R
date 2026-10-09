# =============================================================================
# 03_where_to_live_2023.R               (formerly where_to_live.R, 2025-26)
# -----------------------------------------------------------------------------
# Where in Greater Manchester (or England) are the strongest non-faith primary
# schools, and which of them are close to a Metrolink tram stop?
#
#   Part 1 - National benchmarks for KS2 and KS4 results.
#   Part 2 - England-wide map of non-faith primaries with a high share of
#            pupils at the KS2 "higher standard".
#   Part 3 - Top 10% of GM non-faith primaries, and where a 1 km radius
#            around each school overlaps a 1 km radius around a Metrolink stop.
#   Part 4 - Neighbourhood look-ups: Altrincham, Sale, Stretford/Hulme.
#
# Inputs : data/2022-2023/england_ks2final.csv
#          data/2022-2023/england_ks4final.csv
#          data/EnglishLaNameCodes.csv
#          data/TfGMMetroRailStops.csv
# Outputs: outputs/maps/all_elementary_high_achievers.html
#          outputs/maps/overlap_elementary_transport.html
#          outputs/maps/overlap_elementary_transport_w_points.html
#
# NOTE: this script uses the 2022/23 KS2 file because it relies on its columns
# (pcode, town, reldenom, ptrwm_high ...). The newer 2024/25 KS2 file
# (data/ks2_school_attainment_data.csv) has a different layout and is used in
# 05_shortlist_2025.R instead.
# =============================================================================

source("R/00_helpers.R")

# Faith designation values that mean "no religious character".
NON_FAITH <- c("Does not apply", "None")


# ---- Load data ---------------------------------------------------------------

la_lookup <- load_la_lookup()

ks2_2223 <- read.csv("data/2022-2023/england_ks2final.csv") %>%
  clean_names() %>%
  left_join(la_lookup, by = "lea") %>%
  mutate(perc_high_attainment_ks1 = pct_to_num(ptks1group_h),  # % high prior attainers at KS1
         perc_high_ks2            = pct_to_num(ptrwm_high))    # % at higher standard in RWM

ks4_2223 <- read.csv("data/2022-2023/england_ks4final.csv") %>%
  clean_names() %>%
  left_join(la_lookup, by = "lea") %>%
  mutate(score = to_num(att8scr),
         # Didsbury High has no Attainment 8 in this file; value entered by hand.
         score = ifelse(schname == "Didsbury High School", 57.1, score))

gm_primary   <- ks2_2223 %>% filter(la_name %in% GM_LAS)
gm_secondary <- ks4_2223 %>% filter(la_name %in% GM_LAS)


# =============================================================================
# PART 1: National benchmarks
# =============================================================================

summary(ks4_2223$score)          # Attainment 8 across England
summary(ks2_2223$perc_high_ks2)  # % at KS2 higher standard across England


# =============================================================================
# PART 2: England - non-faith primaries with >11% at the higher standard
# (11% is roughly the national upper quartile in 2022/23)
# =============================================================================

high_achievers_eng <- ks2_2223 %>%
  filter(perc_high_ks2 > 11, reldenom %in% NON_FAITH) %>%
  add_coordinates("pcode")   # ~1,000 API calls: takes a few minutes

england_map <- leaflet(high_achievers_eng) %>%
  addTiles() %>%
  addMarkers(~longitude, ~latitude,
             popup = ~paste("School: ", schname, ", High achievers: ", perc_high_ks2))
england_map
save_map(england_map, "all_elementary_high_achievers.html")


# =============================================================================
# PART 3: Greater Manchester - top 10% non-faith primaries near a tram stop
# =============================================================================

# Top 20 GM secondaries open to boys, by Attainment 8 (for reference)
gm_secondary %>%
  filter(egender %in% c("BOYS", "MIXED")) %>%
  arrange(desc(score)) %>%
  head(20) %>%
  select(schname, score) %>%
  View()

# Primaries in the top 10% for "% at higher standard", no religious character
p90_high <- quantile(gm_primary$perc_high_ks2, probs = 0.90, na.rm = TRUE)

top_gm_primary <- gm_primary %>%
  filter(perc_high_ks2 >= p90_high, reldenom == "Does not apply") %>%
  add_coordinates("pcode") %>%
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326, remove = FALSE)

# Metrolink stops (TfGM open data, WGS84 lat/long)
metrolink <- read.csv("data/TfGMMetroRailStops.csv") %>%
  clean_names() %>%
  st_as_sf(coords = c("gpslon", "gpslat"), crs = 4326, remove = FALSE)

# Buffer in British National Grid (metres), then intersect: the resulting
# polygons are areas within 1 km of BOTH a good school and a tram stop.
schools_buffer   <- top_gm_primary %>% st_transform(27700) %>% st_buffer(1000)
metrolink_buffer <- metrolink      %>% st_transform(27700) %>% st_buffer(1000)
overlap          <- st_intersection(schools_buffer, metrolink_buffer) %>%
  st_transform(4326)

overlap_map <- leaflet() %>%
  addTiles() %>%
  addPolygons(data = overlap, col = "red")
save_map(overlap_map, "overlap_elementary_transport.html")

overlap_map_points <- overlap_map %>%
  addCircles(data = top_gm_primary, col = "green",
             popup = ~paste("School: ", schname, ", High achievers: ", perc_high_ks2)) %>%
  addCircles(data = metrolink, col = "purple", popup = ~rstnam)
overlap_map_points
save_map(overlap_map_points, "overlap_elementary_transport_w_points.html")


# =============================================================================
# PART 4: Neighbourhood look-ups (all primaries, any faith status)
# =============================================================================

#' Map every primary in a subset of gm_primary, coloured green, with popups.
map_primaries <- function(df) {
  df <- add_coordinates(df, "pcode")
  leaflet() %>%
    addTiles() %>%
    addCircles(data = df, lng = ~longitude, lat = ~latitude, col = "green",
               popup = ~paste("School: ", schname, ", High achievers: ", perc_high_ks2))
}

map_primaries(gm_primary %>% filter(town == "Altrincham"))
map_primaries(gm_primary %>% filter(town == "Sale"))
map_primaries(gm_primary %>% filter(str_detect(pcode, "M15|M16|M32")))  # Hulme / Old Trafford / Stretford

# Secondaries in and around Stretford, Sale, Urmston and Chorlton
gm_secondary %>%
  filter(str_detect(pcode, "M15|M16|M21|M32|M33|M41")) %>%
  select(schname, att8scr) %>%
  View()
