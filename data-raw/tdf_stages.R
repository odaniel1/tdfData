
library(tidyverse)
library(rvest)
library(tidygeocoder)

## ---- functions -------------------------------------------------------------

# function to return the URL for each individual wikipedia page
tdf_url <- function(year){sprintf("https://en.wikipedia.org/wiki/%s_Tour_de_France", year)}

# function to extract the table of stage details from a given year's Wikipedia page
get_tdf_stages <- function(year){

  # get table from Wikipedia
  tdf_stages <- tdf_url(year) %>%
    read_html() %>%
    html_nodes("table") %>%
    keep(~str_detect(.,"Stage characteristics")) %>%
    html_table(fill = TRUE)

  # reduce to column needed; use start with as some columns in some years have
  # citations (eg. Date[19], in 1909, instead of Date)
  tdf_stages <- tdf_stages[[1]] %>%
    select(
      matches("Stage"),
      -matches("Stage Type"),
      starts_with("Date"),
      starts_with("Distance"),
      starts_with("Course")
    )

  tdf_stages <- tdf_stages %>%
    as_tibble() %>%
    rename_with(~str_remove(., "\\[\\d+\\]")) %>%
    mutate(
      Year = year,
      Stage = as.character(Stage),
      Date = as.Date(paste(Date, Year), '%d %B %Y'),
      Distance = as.numeric(str_extract(Distance, "\\d+"))
    ) %>%
    separate(Course, c("Start", "Finish"), sep = " to ") %>%
    filter(!is.na(Stage), !is.na(Distance), Stage != "", !is.na(Date)) %>%
    as_tibble()

  return(tdf_stages)
}


## ---- data preparation ------------------------------------------------------

# vector of years that the TdF has taken place
tdf_years <- setdiff(seq(1903,2021,by=1), c(1915,1916,1917,1918, 1940,1941,1942,1943,1944,1945,1946))

# scrape all stages from Wikipedia
tdf_stages <- map(tdf_years, get_tdf_stages) %>% bind_rows()

# get all unique stage start/finish locations;filter out stages that are in another country
# (usually have the country name in brackets).
locations <-tibble(location = c(tdf_stages$Start, tdf_stages$Finish) %>% unique ) %>%
  filter(!str_detect(location,"\\(.*\\)$")) %>%
  bind_rows(tibble(location = "Paris (Champs-Élysées)")) %>%
  mutate(
    address = str_remove(location, "\\(.*"),
    address = str_remove(address, "\\[.*"),
    address = paste0(address, ", France")
  )

# get latitude/longitude coordinates for locations
lat_longs <- locations %>% geocode(address, method = 'osm') %>%
  filter(between(lat, 41,52), between(long, -5,10))

# add latitude/longitude coordinates to stage data
tdf_stages <- tdf_stages %>%
  left_join(select(lat_longs, Start = location, `Start Latitude` = lat, `Start Longitude` = long)) %>%
  left_join(select(lat_longs, Finish = location, `Finish Latitude` = lat, `Finish Longitude` = long))


## ---- save data -------------------------------------------------------------

usethis::use_data(tdf_stages, overwrite = TRUE)
