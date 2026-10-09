# =============================================================================
# 04_suspensions_2025.R                 (formerly suspensions.R, Sept 2026)
# -----------------------------------------------------------------------------
# How do individual schools compare on suspensions in 2024/25?
# Plots the national distribution of school suspension rates and marks a
# school of interest on it; also gives North West / England averages.
#
# Input : data/suspensions-and-permanent-exclusions-in-england_2024-25/data/exc_school.csv
#         (DfE Explore Education Statistics:
#          https://explore-education-statistics.service.gov.uk/data-catalogue/data-set/a4b5a46f-5bed-42b5-91b8-93620a04001e)
#
# Key measures (per 100 pupils, i.e. a percentage):
#   susp_rate          - suspensions per 100 pupils (one pupil can count many times)
#   one_plus_susp_rate - % of pupils with at least one suspension
#   perm_excl_rate     - permanent exclusions per 100 pupils
# =============================================================================

source("R/00_helpers.R")


# ---- Load data (2024/25 only) ------------------------------------------------

sus <- read.csv("data/suspensions-and-permanent-exclusions-in-england_2024-25/data/exc_school.csv") %>%
  filter(time_period == 202425) %>%
  mutate(across(c(susp_rate, one_plus_susp_rate, perm_excl_rate), to_num))


# ---- Distribution plot with one school highlighted ---------------------------

#' Histogram of a rate across all schools, with `school_pattern` marked in red.
plot_rate_with_school <- function(rate_col, school_pattern, xlab) {
  school <- sus %>% filter(grepl(school_pattern, school_name, ignore.case = TRUE))

  ggplot(sus, aes(x = .data[[rate_col]])) +
    geom_histogram(bins = 30) +
    scale_x_pseudolog() +
    geom_vline(xintercept = school[[rate_col]], colour = "red", linetype = "dashed") +
    annotate("text", x = school[[rate_col]], y = Inf, label = school$school_name,
             colour = "red", angle = 90, hjust = 1.1, vjust = -0.5) +
    labs(x = xlab, y = NULL) +
    theme_minimal()
}

plot_rate_with_school("susp_rate",          "New Islington", "Suspension rate 2024/25")
plot_rate_with_school("one_plus_susp_rate", "New Islington", "% pupils with 1+ suspension 2024/25")
plot_rate_with_school("one_plus_susp_rate", "Crown Street",  "% pupils with 1+ suspension 2024/25")


# ---- Benchmarks --------------------------------------------------------------

# North West: % of pupils with at least one suspension
sus %>%
  filter(region_name == "North West") %>%
  summarise(mean = mean(one_plus_susp_rate, na.rm = TRUE),
            median = median(one_plus_susp_rate, na.rm = TRUE))

# England: suspensions per 100 pupils
sus %>%
  summarise(mean = mean(susp_rate, na.rm = TRUE),
            median = median(susp_rate, na.rm = TRUE))

# Outliers: schools with more suspensions than pupils (rate > 100)
sus %>% filter(susp_rate > 100) %>% View()
