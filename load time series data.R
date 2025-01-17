require(stringr)

source("load_pedigree.R")

#getting raw data

years <- 1987:2019 # define the years we want

raw_data = read.csv("Data/frames 1976 to 2019.csv") #read in the encounter data from ID folders

raw_data$Date <- as.Date(raw_data$EncDate, format = "%d/%m/%Y") # format the dates as Dates

raw_data$IDs <- strsplit(raw_data$CleanIDs, ",") # get individual IDs in each frame

# determine whether each frame had any SRKW in it
any_srkw <- unlist(lapply(raw_data$IDs, function(z){
  any(grepl("K",z) | grepl("J",z) | grepl("L",z))
}))

raw_data <- raw_data[any_srkw & format(raw_data$Date, "%Y") %in% years,] # subset to the SRKW data in the years we want

# Get all the dates we're interested (every day from 1st April to 31st October in each year)

# all_date <- seq(as.Date(paste(min(years),"-05-01",sep="")),as.Date(paste(max(years),"-9-30",sep="")),1)
all_date <- seq(as.Date(paste(min(years),"-04-17",sep="")),as.Date(paste(max(years),"-9-30",sep="")),1)
# all_date <- all_date[as.numeric(format(all_date,"%m")) %in% 5:9]
all_date <- all_date[as.numeric(format(all_date,"%m")) %in% 5:9 | 
                       as.numeric(format(all_date, "%m")) == 4 & as.numeric(format(all_date, "%d")) >= 17]

unique_days <- sort(unique(format(all_date, "%m-%d")))

day_month <- format(raw_data$Date, "%m-%d")
year <- format(raw_data$Date, "%Y")

# Get all the IDs

all_ids <- sort(unique(unlist(raw_data$IDs)))
all_ids <- all_ids[all_ids %in% attributes$id]

# Set up an array for sightings; each slice represents a year, and ye

sighting_matrix <- array(0, dim = c(length(years),length(unique_days),length(all_ids)))
dimnames(sighting_matrix)[[3]] <- all_ids
dimnames(sighting_matrix)[[2]] <- as.character(unique_days)

for(i in 1:length(years)){
  for(j in 1:length(unique_days)){
    if(any(day_month == unique_days[j] & year == years[i])){
      ids <- unique(unlist(raw_data$IDs[day_month == unique_days[j] & year == years[i]]))
      yob.i <- attributes$yob[match(ids,attributes$id)] # YOB for individuals recorded
      yod.i <- attributes$yod[match(ids,attributes$id)] # YOD for individuals recorded
      ids <- ids[ids %in% attributes$id & yob.i <= years[i] & (is.na(yod.i) | yod.i >= years[i])] # Subset to individuals that are in the attributes data and could have been observed on that day (exclude errors)
      sighting_matrix[i,j,ids] <- 1
    }
  }
}

kin <- kin[colnames(kin) %in% all_ids, colnames(kin) %in% all_ids]
sighting_matrix <- sighting_matrix[,,colnames(kin)]

matriline <- igraph::components(graph.adjacency(ifelse(kin > 0, 1, 0)))$membership
mats <- 1:max(matriline)

yob <- attributes$yob[match(colnames(kin), attributes$id)]
yod <- attributes$yod[match(colnames(kin), attributes$id)]

mat_size <- sapply(years, function(y){
  sapply(mats, function(m){
    sum(yob <= y & (is.na(yod) | yod >= y) & matriline == m)
  })
})

mat_sightings <- array(0, dim = c(length(years),length(unique_days),length(mats)))
mat_extant <- t(ifelse(mat_size > 0, 1, 0))
for(t in 1:length(years)){
  for(i in 1:length(unique_days)){
    for(j in 1:length(mats)){
      mat_sightings[t,i,j] <- max(sighting_matrix[t,i,matriline == j])
    }
  }
}


pre_mat_sightings = mat_sightings[,1:15,] # 14 days pre true start + day one
mat_sightings = mat_sightings[,15:length(unique_days),] # correct back to onkly having from start date
sighting_matrix = sighting_matrix[,15:length(unique_days),] #same
unique_days = unique_days[15:length(unique_days)] #same

# get each matriline's pod identity

pod <- as.numeric(as.factor(sapply(mats, function(z){
  unique(substr(colnames(kin)[matriline == z],1,1))
})))

# get J pod presence

jpod <- matrix(0, nrow = length(years), ncol = length(unique_days))
for(i in 1:length(years)){
  jpod[i,] <- rowSums(mat_sightings[i,,pod == 1])
}
jpod[jpod > 0] <- 1

# Get the salmon data

time_lag <- 10 # define the lag between salmon and whale data (10 days has been used before)

salmon <- read.csv("Data/albion.csv") # read in the Albion test fishery data
salmon$Date <- as.Date(salmon$Date, "%d-%b-%y") # get the dates as a Date object
salmon$lag_date <- salmon$Date - time_lag # get the lagged dates

salmon_catch <- salmon_effort <- matrix(nrow = length(years), ncol = length(unique_days))

salmon$Year <- format(salmon$lag_date, "%Y")
salmon$Day <- format(salmon$lag_date, "%m-%d")

for(i in 1:length(years)){
  for(j in 1:length(unique_days)){
    if(any(salmon$Year == years[i] & salmon$Day == unique_days[j])){
      salmon_catch[i,j] <- salmon$Catch[salmon$Year == years[i] & salmon$Day == unique_days[j]]
      salmon_effort[i,j] <- salmon$Effort[salmon$Year == years[i] & salmon$Day == unique_days[j]]
    }
  }
}

salmon_effort <- salmon_effort/1000

salmon_effort[is.na(salmon_effort)] <- 1

