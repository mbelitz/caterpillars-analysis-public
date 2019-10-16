# Functions for working with and analyzing Caterpillars Count! data

###################################
# Function for substituting values based on a condition using dplyr::mutate
# Modification of dplyr's mutate function that only acts on the rows meeting a condition
mutate_cond <- function(.data, condition, ..., envir = parent.frame()) {
  condition <- eval(substitute(condition), .data, envir)
  .data[condition, ] <- .data[condition, ] %>% mutate(...)
  .data
}


# Function for calculating the mode of a series of values
# --in this particular use case, if there multiple modes, we want the largest value
Mode = function(x){ 
  if (!is.numeric(x)) {
    stop("values must be numeric for mode calculation")
  }
  ta = table(x)
  tam = max(ta)
  mod = as.numeric(names(ta)[ta == tam])
  return(max(mod))
}




####################################
# Function for calculating and displaying arthropod phenology by week
meanDensityByWeek = function(surveyData, # merged dataframe of Survey and arthropodSighting tables for a single site
                            ordersToInclude = 'All',       # which arthropod orders to calculate density for (codes)
                            
                            minLength = 0,         # minimum arthropod size to include 
                            jdRange = c(1,365),
                            outlierCount = 10000,
                            plot = FALSE,
                            plotVar = 'fracSurveys', # 'meanDensity' or 'fracSurveys' or 'meanBiomass'
                            minSurveyCoverage = 0.8, # minimum proportion of unique survey branches examined per week in order to include the week as a data point
                            allDates = TRUE,
                            new = TRUE,
                            color = 'black',
                            allCats = TRUE,
                            ...)                  
  
{
  
  if(length(ordersToInclude)==1 & ordersToInclude[1]=='All') {
    ordersToInclude = unique(surveyData$Group)
  }
  
  numUniqueBranches = length(unique(surveyData$PlantFK))
  
  firstFilter = surveyData %>%
    filter(julianday >= jdRange[1], julianday <= jdRange[2]) %>%
    mutate(julianweek = 7*floor(julianday/7) + 4)
  
  effortByWeek = firstFilter %>%
    group_by(julianweek) %>%
    summarize(nSurveyBranches = n_distinct(PlantFK),
              nSurveys = n_distinct(ID)) %>%
    mutate(modalBranchesSurveyed = Mode(5*ceiling(nSurveyBranches/5)),
           nSurveySets = nSurveys/modalBranchesSurveyed,
           modalSurveySets = Mode(round(nSurveySets)),
           okWeek = ifelse(nSurveySets/modalSurveySets >= minSurveyCoverage, 1, 0))

  if (allDates) {
    effortByWeek$okWeek = 1
  }
  
  if (!allCats) {
    secondFilter = firstFilter %>%
      filter(Hairy != 1, Tented != 1, Rolled != 1)
  } else {
    secondFilter = firstFilter
  }
  
  arthCount = secondFilter %>%
    filter(Length >= minLength, 
           Group %in% ordersToInclude) %>%
    mutate(Quantity2 = ifelse(Quantity > outlierCount, 1, Quantity)) %>% #outlier counts replaced with 1
    group_by(julianweek) %>%
    summarize(totalCount = sum(Quantity2, na.rm = T),
              numSurveysGTzero = length(unique(ID[Quantity > 0]))) %>% 
    right_join(effortByWeek, by = 'julianweek') %>%
    #next line replaces 3 fields with 0 if the totalCount is NA
    filter(okWeek == 1) %>%
    mutate_cond(is.na(totalCount), totalCount = 0, numSurveysGTzero = 0) %>%
    mutate(meanDensity = totalCount/nSurveys,
           fracSurveys = 100*numSurveysGTzero/nSurveys) %>%
    data.frame()
  
  if (plot & new) {
    plot(arthCount$julianweek, arthCount[, plotVar], type = 'l', 
         col = color, las = 1, ...)
    points(arthCount$julianweek, arthCount[, plotVar], pch = 16, col = color, ...)
  } else if (plot & new==F) {
    points(arthCount$julianweek, arthCount[, plotVar], type = 'l', col = color, ...)
    points(arthCount$julianweek, arthCount[, plotVar], pch = 16, col = color, ...)
  }
  return(arthCount)
}



####################################
# Function for calculating and displaying arthropod phenology by day,
# or if surveys were split up over multiple days, then lumped by survey set
meanDensityByDay = function(surveyData, # merged dataframe of Survey and arthropodSighting tables for a single site
                             ordersToInclude = 'All',       # which arthropod orders to calculate density for (codes)
                             
                             minLength = 0,         # minimum arthropod size to include 
                             jdRange = c(1,365),
                             outlierCount = 10000,
                             plot = FALSE,
                             plotVar = 'fracSurveys', # 'meanDensity' or 'fracSurveys' or 'meanBiomass'
                             minSurveyCoverage = 0.8, # minimum proportion of unique survey branches examined per week in order to include the week as a data point
                             allDates = TRUE,         # plot data for all dates for which any survey data exist; if FALSE, only dates where # surveys==# unique branches +/- 20%
                             new = TRUE,
                             color = 'black',
                             allCats = TRUE,
                             ...)                  

{
  
  if(length(ordersToInclude)==1 & ordersToInclude[1]=='All') {
    ordersToInclude = unique(surveyData$Group)
  }
  
  numUniqueBranches = length(unique(surveyData$PlantFK))
  
  firstFilter = surveyData %>%
    filter(julianday >= jdRange[1], julianday <= jdRange[2])
    
  effortByDay = firstFilter %>%
    group_by(julianday) %>%
    summarize(nSurveyBranches = n_distinct(PlantFK),
              nSurveys = n_distinct(ID)) %>%
    mutate(modalBranchesSurveyed = Mode(5*ceiling(nSurveyBranches/5)),
           nSurveySets = nSurveys/modalBranchesSurveyed,
           modalSurveySets = Mode(round(nSurveySets)),
           okDay = ifelse(nSurveySets/modalSurveySets >= minSurveyCoverage, 1, 0))
  
  if (allDates) {
    effortByDay$okDay = 1
  }

  if (!allCats) {
    secondFilter = firstFilter %>%
      filter(Hairy != 1, Tented != 1, Rolled != 1)
  } else {
    secondFilter = firstFilter
  }
  
  arthCount = secondFilter %>%
    filter(Length >= minLength, 
           Group %in% ordersToInclude) %>%
    mutate(Quantity2 = ifelse(Quantity > outlierCount, 1, Quantity)) %>% #outlier counts replaced with 1
    group_by(julianday) %>%
    summarize(totalCount = sum(Quantity2, na.rm = T),
              numSurveysGTzero = length(unique(ID[Quantity > 0]))) %>% 
    right_join(effortByDay, by = 'julianday') %>%
    #next line replaces 3 fields with 0 if the totalCount is NA
    filter(okDay == 1) %>%
    mutate_cond(is.na(totalCount), totalCount = 0, numSurveysGTzero = 0) %>%
    mutate(meanDensity = totalCount/nSurveys,
           fracSurveys = 100*numSurveysGTzero/nSurveys) %>%
    data.frame()
  
  if (plot & new) {
    plot(arthCount$julianday, arthCount[, plotVar], type = 'l', 
         col = color, las = 1, ...)
    points(arthCount$julianday, arthCount[, plotVar], pch = 16, col = color, ...)
  } else if (plot & new==F) {
    points(arthCount$julianday, arthCount[, plotVar], type = 'l', col = color, ...)
    points(arthCount$julianday, arthCount[, plotVar], pch = 16, col = color, ...)
  }
  return(arthCount)
}



#########################################
# Get county name from lat-longs
# From https://stackoverflow.com/questions/13316185/r-convert-zipcode-or-lat-long-to-county
# Note: had to remove proj4string references

# The single argument to this function, pointsDF, is a data.frame in which:
#   - column 1 contains the longitude in degrees (negative in the US)
#   - column 2 contains the latitude in degrees

latlong2county <- function(pointsDF) {
  # Prepare SpatialPolygons object with one SpatialPolygon
  # per county
  require(sp)
  require(maps)
  require(maptools)
  
  counties <- map('county', fill=TRUE, col="transparent", plot=FALSE)
  IDs <- sapply(strsplit(counties$names, ":"), function(x) x[1])
  counties_sp <- map2SpatialPolygons(counties, IDs=IDs)
  
  # Convert pointsDF to a SpatialPoints object 
  pointsSP <- SpatialPoints(pointsDF)
  
  # Use 'over' to get _indices_ of the Polygons object containing each point 
  indices <- over(pointsSP, counties_sp)
  
  # Return the county names of the Polygons object containing each point
  countyNames <- sapply(counties_sp@polygons, function(x) x@ID)
  countyNames[indices]
}


############################################
# Function for calculating summary stats about survey effort at individual sites
siteEffortSummary = function(fullDataset, 
                       year = format(Sys.Date(), "%Y"), 
                       surveyThreshold = 0.8,            # proprortion of surveys conducted to be considered a good sampling day
                       minJulianWeek = 102,              # beginning of seasonal window for tabulating # of good weeks
                       maxJulianWeek = 214)              # end of seasonal window for tabulating # of good weeks
  {
  
  summary = filter(fullDataset, Year == year) %>%
    mutate(julianweek = 7*floor(julianday/7) + 4) %>%
    group_by(Name, julianweek, medianGreenup) %>%
    summarize(nSurveysPerWeek = n_distinct(ID)) %>%
    group_by(Name, medianGreenup) %>%
    summarize(nSurveys = sum(nSurveysPerWeek, na.rm = TRUE),
              medianSurveysPerWeek = round(median(nSurveysPerWeek, na.rm = T), 1),
              nWeeks = n_distinct(julianweek),
              nGoodWeeks = n_distinct(julianweek[julianweek >= minJulianWeek & julianweek <= maxJulianWeek & nSurveysPerWeek > surveyThreshold*medianSurveysPerWeek]),
              medianEffortDeviation = median(abs(nSurveysPerWeek - medianSurveysPerWeek)),
              firstDate = min(julianweek),
              lastDate = max(julianweek),
              firstGoodDate = min(julianweek[nSurveysPerWeek > surveyThreshold*medianSurveysPerWeek]),
              lastGoodDate = max(julianweek[nSurveysPerWeek > surveyThreshold*medianSurveysPerWeek]),
              firstGDateAfterGreenup = firstGoodDate - medianGreenup[1],
              lastGDateAfterGreenup = lastGoodDate - medianGreenup[1])
  
  return(summary)
}


########################################
# Criteria for inclusion (records refers to survey events)
siteSummary = function(fullDataset, year, minNumRecords = 40, minNumWeeks = 5, write = TRUE) {
  out = fullDataset %>%
    filter(Year == year) %>%
    group_by(Name, Region, Latitude, Longitude) %>%
    summarize(nSurveys = n_distinct(ID),
              nDates = n_distinct(LocalDate),
              nWeeks = n_distinct(julianweek),
              nCat = sum(Group == 'caterpillar', na.rm = TRUE),
              pctCat = round(sum(Quantity[Group == 'caterpillar'] > 0)/nSurveys, 3),
              nArth = sum(Quantity, na.rm = TRUE),
              nLgArth = sum(Quantity[Length >= 10], na.rm = TRUE),
              nArthsPerSurvey = nArth/nSurveys,
              nLgArthsPerSurvey = nLgArth/nSurveys,
              pctSurvsLgArths = round(sum(Length >= 10, na.rm = TRUE)/nSurveys, 3),
              nPhoto = sum(Photo, na.rm = TRUE),
              pctPhoto = round(nPhoto/n_distinct(arthID), 3)) %>%
    arrange(desc(Latitude)) %>%
    filter(nSurveys >= minNumRecords, nWeeks >= minNumWeeks, Name != "Example Site") %>%
    mutate(county = latlong2county(data.frame(lon = Longitude, lat = Latitude)))
  
  if (write) {
    write.table(out, paste('data/siteSummary', year, '.txt', sep = ''), sep = '\t', row.names = F)
  }
  return(out)
}




#########################################
# Create a site x julianweek matrix filled with number of surveys in that site-week
siteSurveysPerWeek = function(fullDataset, 
                       year = format(Sys.Date(), "%Y"),
                       relativeToGreenup = FALSE)
{
  
  if (relativeToGreenup) {
    weekMatrix = filter(fullDataset, Year == year, Name != "Example Site") %>%
      mutate(julianweekGreenup = 7*floor((julianday - medianGreenup)/7) + 4) %>%
      distinct(Name, julianweekGreenup, ID) %>%
      count(Name, julianweekGreenup) %>%
      spread(key = julianweekGreenup, value = n)
  } else {
    weekMatrix = filter(fullDataset, Year == year, Name != "Example Site") %>%
      distinct(Name, julianweek, ID) %>%
      count(Name, julianweek) %>%
      spread(key = julianweek, value = n)
  }

  weekMatrix[is.na(weekMatrix)] = 0
  return(weekMatrix)
}



##########################################
# Plot weekly phenology for an aggregation of sites compared to the weekly
# phenology of each individual site
aggregateComponentPlot = function(dataset, ...) {
  
  meanDensityByWeek(dataset, ordersToInclude='caterpillar', plot = TRUE, new = TRUE, allDates = FALSE,
                    lwd = 4, xlab = "Julian day", ylab = "% of surveys", ...)
  
  sites = unique(dataset$Name)
  colors = rainbow(length(sites))
  i = 0
  for (s in sites) {
    i = i+1
    meanDensityByWeek(dataset[dataset$Name == s, ], ordersToInclude = 'caterpillar', 
                      plot = TRUE, new = FALSE, col = colors[i], allDates = FALSE, ...)
  }
  legend("topleft", legend = sites, lwd = 2, col = colors, bty = 'n')
  
}


######################################
# If a sitename string is too long, find the best space position for breaking into
# two separate lines. If it is not too long return NA.

breakPosition = function(string, maxCharsPerLine = 25) {
  
  if (nchar(string) <= maxCharsPerLine) {
    lineBreak = NA
  } else {
    breaks = gregexpr(" ", string)
    lineBreak = min(breaks[[1]][breaks[[1]] >= nchar(string)/2])
  }
  return(lineBreak)
}



###########################################
# Split up long site names across two lines by introducing \n in the middle at a space break

siteNameForPlotting = function(sitename, maxCharsPerLine = 25) {
  breakPos = breakPosition(sitename, maxCharsPerLine)
  
  newname = ifelse(is.na(breakPos), sitename, 
                   paste(substr(sitename, 1, breakPos - 1), "\n", 
                         substr(sitename, breakPos + 1, nchar(sitename)), sep = ""))
  return(newname)
}



###########################################
# Create multi-panel phenology plot for a set of sites

multiSitePhenoPlot = function(fullDataset, 
                              year, 
                              siteSummary, 
                              write = TRUE, 
                              monthRange = NULL, # 2-value vector with beginning and ending months for plotting;
                              # e.g., start of May - end of August would be c(5,8).
                              # If NULL, xlim will vary by site based on when surveys were conducted
                              REVI = FALSE,      # plot window of red-eyed vireo nestlings estimated from eBird
                              # (requires manual addition of REVI columns to siteSummary)
                              filename,
                              panelRows = 4,
                              panelCols = 6,
                              colRGB = c(0, .5, 0), #vector of R, G, and B color values
                              cex.main = 1.5,
                              cex.lab = 1,
                              cex.axis = 1,
                              cex.text = 1.5,
                              ...) {
  
  if (write) {
    pdf(paste('figs/', filename, '.pdf', sep = ''), height = 8.5, width = 11)
  }
  
  # Concatenate region name to the end of site name (if it's not already there)
  siteSummary$siteNameRegion = apply(siteSummary, 1, function(x) 
    ifelse(substr(x[1], nchar(x[1])-3, nchar(x[1])) == paste(", ", x[2], sep = ""),
           x[1], paste(x[1], ", ", x[2], sep = "")))
  
  
  
  par(mfrow = c(panelRows, panelCols), mar = c(3, 2, 3, 1), oma = c(5, 5, 0, 0))
  
  counter = 0
  
  for (site in siteSummary$Name) {
    
    counter = counter + 1
    sitedata = fullDataset %>%
      filter(Name == site, Year == year)
    
    siteLabel = siteNameForPlotting(siteSummary$siteNameRegion[siteSummary$Name == site], maxCharsPerLine = 23)
    
    # goofy temporary correction for long name
    siteLabel[siteLabel == "Litzsinger Road Ecology Center\nWoodland Site A, MO"] = "Litzsinger Road Ecology\nCenter Site A, MO"
    
    
    # x-axis labels
    jds = c(1, 32, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335)
    dates = c("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")
    
    # x-axis range
    if (is.null(monthRange)) {
      # make sure xlim endpoints coincide with month labels
      if(length(unique(sitedata$julianday)) == 1) {
        minPos = which(jds == max(jds[jds <= min(sitedata$julianday)]))
        maxPos = which(jds == min(jds[jds >= max(sitedata$julianday)]))
      } else {
        minPos = max(which(jds == min(jds[jds >= min(sitedata$julianday)])) - 1, 1)    
        maxPos = min(which(jds == max(jds[jds <= max(sitedata$julianday)])) + 1, 12)
      }
    } else {
      minPos = monthRange[1]
      maxPos = monthRange[2]+1
    }
    monthLabs = minPos:(maxPos-1)
    
    # Caterpillar phenology
    caterpillarPhenology = meanDensityByWeek(sitedata, ordersToInclude = 'caterpillar', 
                                            plot = FALSE, plotVar = 'fracSurveys', allDates = FALSE, ...)
    
    
    caterpillarPhenology = meanDensityByWeek(sitedata, ordersToInclude = 'caterpillar', 
                                            plot = TRUE, plotVar = 'fracSurveys', allDates = FALSE, xlab = 'Date',
                                            ylab = 'Percent of surveys', lwd = 3, 
                                            xaxt = 'n', xaxs = 'i', cex.lab = cex.lab, cex.axis = cex.axis,
                                            xlim = c(jds[minPos], jds[maxPos]),
                                            ylim = c(0, max(1, 1.3*max(caterpillarPhenology$fracSurveys))), 
                                            main = siteLabel, cex.main = cex.main,
                                            col = rgb(colRGB[1], colRGB[2], colRGB[3]), ...)
    
    text(jds[minPos] + 5, 1.2*max(caterpillarPhenology$fracSurveys), paste(siteSummary$nSurveys[siteSummary$Name == site], "surveys"),
         col = 'blue', cex = cex.text, adj = 0)
    text(jds[maxPos] - 2, 1.2*max(caterpillarPhenology$fracSurveys), paste(round(siteSummary$Latitude[siteSummary$Name == site], 1), "°N", sep = ""),
         col = 'red', cex = cex.text, adj = 1)
    
    abline(v = jds, col = 'gray50')
    mtext(dates[monthLabs], 1, at = jds[monthLabs]+14, cex = cex.axis, line = .25)
    
    if (REVI) {
      bird = siteSummary %>%
        filter(Name == site) %>%
        mutate(preArrival = yday(as.Date(LatestWeekWithFreq0, format = "%m/%d/%Y")) + 3, # +3 to shift from beg to middle of week
               peakArrival = yday(as.Date(WeekOfPeakFreq, format = "%m/%d/%Y")) + 3,
               arrival = round((preArrival + peakArrival)/2),
               hatching = arrival + 35,
               fledging = hatching + 11)
      rect(bird$hatching, -5, bird$fledging, 110, col = rgb(colRGB[1], colRGB[2], colRGB[3], .1), border = NA)
    }
    
    #if (counter %% panelRows*panelCols == 0 | counter == nrow(siteSummary)) {
    #  mtext("Date", 1, outer = TRUE, line = 1, cex = 1.5)
    #  mtext("Percent of surveys with caterpillars", 2, outer = TRUE, line = 1, cex = 1.5)
    #}  
  } #end site
  
  mtext("Date", 1, outer = TRUE, line = 1, cex = 1.5)
  mtext("Percent of surveys with caterpillars", 2, outer = TRUE, line = 1, cex = 1.5)
  
  if (write) {
    dev.off()
  }
}  






############################################################
# Interpolate phenology values on a daily basis for the purpose
# of color coding line segements over time

interpolatePhenoByDay = function(phenodata, var = 'fracSurveys') {
  # phenodata is object created by meanDensityByDay()
  # var can be either 'fracSurveys' or 'meanDensity'
  
  days = data.frame(julianday = min(phenodata$julianday):max(phenodata$julianday))
  
  phenodat = phenodata[, c('julianday', var)]
  names(phenodat)[2] = 'x'
  
  pheno = days %>% 
    left_join(phenodat, by = 'julianday')
  
  # Find interior NAs
  intNAs = which(sapply(1:nrow(pheno), function(row) is.na(pheno$x[row]) &
                          sum(pheno$x[1:(row-1)], na.rm = TRUE) >= 0 &
                          sum(pheno$x[(row+1):nrow(pheno)], na.rm = TRUE) >= 0))
  
  if (length(intNAs) > 0) {
    for (i in intNAs) {
      preValPos = max(which(!is.na(pheno$x[1:(i-1)])))
      postValPos = min(which(!is.na(pheno$x[(i+1):nrow(pheno)]))) + i
      
      slope = (pheno$x[postValPos] - pheno$x[preValPos])/(pheno$julianday[postValPos] - pheno$julianday[preValPos])
      
      pheno$x[i] = pheno$x[preValPos] + slope*(pheno$julianday[i] - pheno$julianday[preValPos])
    }
  }
  return(pheno)
}




# Take an interpolated pheno object as returned by interpolatePheno()
# and plot phenocurve with line rainbow-colored by date
rainbowPhenoPlot = function(phenodata, minJD = 95, maxJD = 221, ...) {
  
  colors = c('#2F2C62', '#42399B', '#4A52A7', '#59AFEA', '#7BCEB8', '#A7DA64',
             '#EFF121', '#F5952D', '#E93131', '#D70131')
  col.ramp = colorRampPalette(colors)
  cols = data.frame(julianday = minJD:maxJD, 
                    col = col.ramp(length(minJD:maxJD)))
  
  phenocol = cols %>%
    left_join(phenodata, by = 'julianday')
  phenocol$col = as.character(phenocol$col)
  
  x = phenocol$julianday
  y = phenocol$x
  
  par(bg = NA)
  plot(x, y, xaxt = "n", yaxt = "n", xlab = "", ylab = "", type = 'n', bty = 'n')
  
  # Plot the colored line segments  
  sapply(1:(nrow(phenocol) - 1), function(jd) 
    segments(x0 = x[jd], y0 = y[jd], x1 = x[jd + 1], y1 = y[jd + 1], col = phenocol$col[jd], ...))
  
  # Plot month bar along the bottom
  
}


#####################################
# Plotting a rainbow color scale bar
rainbowScaleBar = function(minJD = 91, maxJD = 228, plot = TRUE) {
  colors = c('#2F2C62', '#42399B', '#4A52A7', '#59AFEA', '#7BCEB8', '#A7DA64',
             '#EFF121', '#F5952D', '#E93131', '#D70131')
  col.ramp = colorRampPalette(colors)
  cols = data.frame(julianday = minJD:maxJD, 
                    col = col.ramp(length(minJD:maxJD)))
  
  # labels
  monthLabels = data.frame(jd = c(1, 15, 32, 46, 60, 74, 91, 105, 121, 135, 152, 166, 
                                  182, 196, 213, 227, 244, 258, 274, 288, 305, 319, 335, 349),
                           
                           date = c("Jan 1", "Jan 15", "Feb 1", "Feb 15", "Mar 1", 
                                    "Mar 15", "Apr 1", "Apr 15", "May 1", "May 15", 
                                    "Jun 1", "Jun 15", "Jul 1", "Jul 15", "Aug 1", 
                                    "Aug 15", "Sep 1", "Sep 15", "Oct 1", "Oct 15", 
                                    "Nov 1", "Nov 15", "Dec 1", "Dec 15"))
  
  bar = left_join(cols, monthLabels, by = c('julianday' = 'jd'))
  bar$col = as.character(bar$col)
  
  barlabs = bar[!is.na(bar$date), ]
  
  if (plot) {
    png('figs/rainbow_scale.png', height = 600, width = 150, bg = NA)
    par(mar = c(0,0,0,0))
    plot(rep(1, nrow(bar)), -bar$julianday, pch = 15, cex = 4, col = bar$col,
         xaxt = 'n', yaxt = 'n', xlab = '', ylab = '', bty = 'n', xlim = c(.9, 3.5))
    text(rep(1.4, nrow(barlabs)), -barlabs$julianday, barlabs$date, adj = 0, cex = 3)
    dev.off()
  }
}

