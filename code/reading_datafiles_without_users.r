# Reading in Caterpillars Count! database files
library(dplyr)
library(lubridate)

# Function for substituting values based on a condition using dplyr::mutate
# Modification of dplyr's mutate function that only acts on the rows meeting a condition
mutate_cond <- function(.data, condition, ..., envir = parent.frame()) {
  condition <- eval(substitute(condition), .data, envir)
  .data[condition, ] <- .data[condition, ] %>% mutate(...)
  .data
}


# Read in data files
sites = read.csv(paste('data/', list.files('data')[grep('Site.csv', list.files('data'))], sep = ''), header = TRUE, stringsAsFactors = FALSE)

surveys = read.csv(paste('data/', list.files('data')[grep('Survey.csv', list.files('data'))], sep = ''), header = TRUE, stringsAsFactors = FALSE)

arths = read.csv(paste('data/', list.files('data')[grep('ArthropodSighting.csv', list.files('data'))], sep = ''), header = TRUE, stringsAsFactors = FALSE)

plants = read.csv(paste('data/', list.files('data')[grep('Plant.csv', list.files('data'))], sep = ''), header = TRUE, stringsAsFactors = FALSE)

surveys$LocalDate = as.Date(surveys$LocalDate, format = "%Y-%m-%d")
surveys$Year = as.numeric(format(surveys$LocalDate, "%Y"))
surveys$julianday = yday(surveys$LocalDate)
surveys$julianweek = 7*floor(surveys$julianday/7) + 4

arths$Photo = ifelse(arths$PhotoURL == "", 0, 1)

fullDataset = surveys %>%
  dplyr::select(ID, UserFKOfObserver, PlantFK, LocalDate, julianday, Year, ObservationMethod, Notes, WetLeaves, PlantSpecies, NumberOfLeaves,
         AverageLeafLength, HerbivoryScore) %>%
  left_join(arths[, !names(arths) %in% "PhotoURL"], by = c('ID' = 'SurveyFK')) %>%
  left_join(plants, by = c('PlantFK' = 'ID')) %>%
  left_join(sites[, c('ID', 'Name', 'Latitude', 'Longitude', 'Region')], by = c('SiteFK' = 'ID')) %>% 
  mutate_cond(is.na(Quantity), Quantity = 0, Group) %>%
  rename(surveyNotes = Notes.x, bugNotes = Notes.y, arthID = ID.y)