# =============================================================================
# 00_helpers.R
# -----------------------------------------------------------------------------
# Shared packages, constants and small helper functions used by the analysis
# scripts. Every other script starts with:
#
#     source("R/00_helpers.R")
#
# All paths assume the working directory is the project root (i.e. open
# schools.Rproj in RStudio before running anything).
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(stringr)
  library(janitor)
  library(purrr)
  library(ggplot2)
  library(scales)
  library(sf)
  library(leaflet)
  library(rjson)
})

options(scipen = 999)  # print rates as decimals rather than scientific notation


# ---- Constants ---------------------------------------------------------------

# The ten local authorities that make up Greater Manchester.
GM_LAS <- c("Bolton", "Bury", "Manchester", "Oldham", "Rochdale",
            "Salford", "Stockport", "Tameside", "Trafford", "Wigan")

# DfE performance-table NFTYPE codes -> readable school type
# (from data/data_dictionaries/ks4_abbreviations.xlsx).
NFTYPE_LABELS <- c(
  AC      = "Academy Sponsor Led",
  CY      = "Community School",
  VA      = "Voluntary Aided School",
  VC      = "Voluntary Controlled School",
  FD      = "Foundation School",
  CTC     = "City Technology College",
  CYS     = "Community Special School",
  FDS     = "Foundation Special School",
  NMSS    = "Non-maintained Special School",
  IND     = "Independent School",
  FESI    = "Further Education Sector Institution",
  CHS     = "Community Hospital School",
  FHS     = "Foundation Hospital School",
  PRU     = "Pupil Referral Unit",
  MODFC   = "Institution funded by other Government department",
  INDSPS  = "Other Independent Special School",
  ACS     = "Academy Special",
  ACC     = "Academy Converter",
  F       = "Free School - Mainstream",
  FS      = "Special Free School",
  ACCS    = "Converter Special Academy",
  FAP     = "Free School AP",
  FUTC    = "Free School UTC (University Technical College)",
  FSS     = "Free School - Studio School",
  F1619   = "Free School - 16-19",
  ACCAP   = "Academy - Converter Alternative Provision (AP)",
  ACAP    = "Academy - Sponsor led Alternative Provision (AP)",
  ACC1619 = "Academy 16-19 Converter",
  AC1619  = "Academy 16-19 Sponsor Led",
  AP      = "Alternative Provision"
)

# Breaks for the pseudo-log x axis used on suspension-rate plots
# (rates are heavily right-skewed with many zeros, so a plain log fails).
SUSP_RATE_BREAKS <- c(0, 0.01, 0.1, 1, 10, 100)
scale_x_pseudolog <- function(...) {
  scale_x_continuous(trans  = pseudo_log_trans(base = 10, sigma = 0.01),
                     breaks = SUSP_RATE_BREAKS, ...)
}


# ---- Data helpers ------------------------------------------------------------

#' Convert DfE percentage strings ("23%", "SUPP", "NE") to numbers.
#' Suppressed / not-applicable codes become NA.
pct_to_num <- function(x) suppressWarnings(as.numeric(gsub("%", "", x)))

#' Convert DfE numeric columns stored as text ("z", "x", "c" codes) to numbers.
to_num <- function(x) suppressWarnings(as.numeric(x))

#' Local-authority lookup: GIAS LA code (e.g. 352) -> LA name (e.g. "Manchester").
load_la_lookup <- function() {
  read.csv("data/EnglishLaNameCodes.csv") %>%
    clean_names() %>%
    select(lea     = get_information_about_schools_gias_local_authority_la_code,
           la_name = english_local_authority_la_name)
}


# ---- Geocoding ---------------------------------------------------------------

#' Look up one postcode with the free getthedata.com API.
#' Returns c(longitude, latitude); NAs if the postcode isn't found.
geocode_postcode <- function(postcode) {
  url <- paste0("http://api.getthedata.com/postcode/", gsub(" ", "+", postcode))
  res <- tryCatch(fromJSON(paste(readLines(url, warn = FALSE), collapse = "")),
                  error = function(e) NULL)
  lng <- res$data$longitude
  lat <- res$data$latitude
  c(longitude = if (is.null(lng)) NA_real_ else as.numeric(lng),
    latitude  = if (is.null(lat)) NA_real_ else as.numeric(lat))
}

#' Add `longitude` / `latitude` columns to a data frame by geocoding its
#' postcode column (one API call per row, so keep the data frame small).
add_coordinates <- function(df, postcode_col = "pcode") {
  if (nrow(df) == 0) return(mutate(df, longitude = numeric(), latitude = numeric()))
  coords <- do.call(rbind, lapply(df[[postcode_col]], geocode_postcode))
  df$longitude <- coords[, "longitude"]
  df$latitude  <- coords[, "latitude"]
  df
}


# ---- Output helpers ----------------------------------------------------------

#' Save a leaflet map as an HTML file in outputs/maps/.
#' The file is self-contained (single file) when pandoc is available, which it
#' is inside RStudio; otherwise a supporting *_files/ folder is written too.
save_map <- function(map, filename) {
  dir.create("outputs/maps", recursive = TRUE, showWarnings = FALSE)
  has_pandoc <- nzchar(Sys.which("pandoc")) || nzchar(Sys.getenv("RSTUDIO_PANDOC"))
  htmlwidgets::saveWidget(map, file.path(normalizePath("outputs/maps"), filename),
                          selfcontained = has_pandoc)
  invisible(map)
}
