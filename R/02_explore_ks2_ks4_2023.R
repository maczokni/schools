# =============================================================================
# 02_explore_ks2_ks4_2023.R            (formerly analysis.R, March 2025)
# -----------------------------------------------------------------------------
# First look at school performance in Greater Manchester using the DfE
# 2022/23 performance tables.
#
#   Part 1 - Secondary (KS4): rank GM secondaries on Attainment 8 and on the
#            % of pupils getting grade 5+ in English & maths. KS4 tables
#            include grammar and independent (private) schools.
#   Part 2 - Primary (KS2): rank GM primaries on KS2 maths scores and the share
#            of high-attaining pupils; map the top 10% for maths. KS2 tables
#            cover state-funded schools only.
#   Part 3 - Comparison with Walthamstow (E17).
#
# Inputs : data/2022-2023/england_ks2final.csv
#          data/2022-2023/england_ks4final.csv
#          data/EnglishLaNameCodes.csv
# Output : outputs/maps/maths_90th_centile_schools_excluding_private.html
# =============================================================================

source("R/00_helpers.R")


# ---- Load data ---------------------------------------------------------------

la_lookup <- load_la_lookup()

ks2_2223 <- read.csv("data/2022-2023/england_ks2final.csv") %>%
  clean_names() %>%
  left_join(la_lookup, by = "lea")

ks4_2223 <- read.csv("data/2022-2023/england_ks4final.csv") %>%
  clean_names() %>%
  left_join(la_lookup, by = "lea")


# =============================================================================
# PART 1: SECONDARY SCHOOLS (KS4) - includes grammar & independent schools
# =============================================================================

ks4_2223 <- ks4_2223 %>%
  mutate(
    school_type = unname(NFTYPE_LABELS[nftype]),
    # Attainment 8 = average grade across 8 GCSE-level subjects (x10).
    score  = to_num(att8scr),
    # Didsbury High (a newer free school) has no Attainment 8 score in the
    # 2022/23 file, so a value of 57.1 is entered by hand.
    score  = ifelse(schname == "Didsbury High School", 57.1, score),
    # % of pupils achieving grade 5+ (strong pass) in English and maths.
    passes = pct_to_num(ptl2basics_95)
  )

gm_secondary <- ks4_2223 %>% filter(la_name %in% GM_LAS)

# How many GM secondaries of each type, and which are grammars?
gm_secondary %>% count(school_type)
gm_secondary %>% filter(grepl("grammar", tolower(schname))) %>% View()

# Top 20 GM secondaries open to boys (boys-only or mixed), by Attainment 8 ...
top_20_gm_att8 <- gm_secondary %>%
  filter(egender %in% c("BOYS", "MIXED")) %>%
  arrange(desc(score)) %>%
  head(20)

top_20_gm_att8 %>% select(schname, town, pcode, score, school_type) %>% View()

# ... and by % grade 5+ in English & maths
top_20_gm_passes <- gm_secondary %>%
  filter(egender %in% c("BOYS", "MIXED")) %>%
  arrange(desc(passes)) %>%
  head(20)

top_20_gm_passes %>%
  select(schname, town, pcode, score, school_type, ptl2basics_95) %>%
  View()

# Spot checks: a Wirral grammar for reference, and secondaries in M20 / M13.
ks4_2223 %>% filter(grepl("calday", tolower(schname))) %>% View()

ks4_2223 %>%
  filter(str_starts(pcode, "M20|M13")) %>%
  select(schname, town, pcode, score, school_type, att8scr) %>%
  View()


# =============================================================================
# PART 2: PRIMARY SCHOOLS (KS2) - state-funded only
# =============================================================================

gm_primary <- ks2_2223 %>%
  filter(la_name %in% GM_LAS) %>%
  mutate(
    perc_high_attainment_ks1 = pct_to_num(ptks1group_h),  # % high prior attainers at KS1
    perc_high_ks2            = pct_to_num(ptrwm_high),    # % at higher standard in reading, writing & maths
    maths_avg                = to_num(mat_average)        # average KS2 maths scaled score (100 = expected)
  )

# Top 20 by share of high prior attainers, and by average maths score
gm_primary %>%
  arrange(desc(perc_high_attainment_ks1)) %>%
  head(20) %>%
  select(schname, town, pcode, perc_high_attainment_ks1) %>%
  View()

gm_primary %>%
  arrange(desc(maths_avg)) %>%
  head(20) %>%
  select(schname, town, pcode, mat_average, perc_high_attainment_ks1) %>%
  View()

# Distribution of maths scores across GM primaries
ggplot(gm_primary, aes(x = maths_avg)) + geom_boxplot()
summary(gm_primary$maths_avg)

# Top 10% for maths (the 90th percentile in 2022/23 was a scaled score of 108)
maths_p90 <- quantile(gm_primary$maths_avg, probs = 0.9, na.rm = TRUE)
maths_p90

top_10pc_maths <- gm_primary %>%
  filter(maths_avg >= maths_p90) %>%
  add_coordinates("pcode")

maths_map <- leaflet(top_10pc_maths) %>%
  addTiles() %>%
  addMarkers(~longitude, ~latitude,
             popup = ~paste("School: ", schname, ", Maths avg: ", maths_avg))
maths_map
save_map(maths_map, "maths_90th_centile_schools_excluding_private.html")

# Individual schools of interest
gm_primary %>%
  filter(grepl("new islington|abbott community", tolower(schname))) %>%
  select(schname, town, pcode, mat_average, read_average,
         perc_high_attainment_ks1, perc_high_ks2) %>%
  View()


# =============================================================================
# PART 3: COMPARISON - Walthamstow (E17) vs Greater Manchester vs England
# =============================================================================

walthamstow <- ks2_2223 %>%
  filter(str_starts(pcode, "E17")) %>%
  mutate(perc_high_attainment_ks1 = pct_to_num(ptks1group_h),
         perc_high_ks2            = pct_to_num(ptrwm_high),
         maths_avg                = to_num(mat_average),
         read_avg                 = to_num(read_average))

max(walthamstow$maths_avg, na.rm = TRUE)       # best E17 maths score
mean(to_num(ks2_2223$mat_average), na.rm = TRUE)  # England average
mean(gm_primary$maths_avg, na.rm = TRUE)          # GM average

walthamstow %>%
  select(schname, town, pcode, mat_average, read_average,
         perc_high_attainment_ks1, perc_high_ks2) %>%
  View()
