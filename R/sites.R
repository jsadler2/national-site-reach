#transform flow dataframe to sites
flow_observations_to_sites <- function(inind, outfile) {
  flow_obs <- readRDS(as_data_file(infile))
  unique_ids <- unique(flow_obs$site_id)
  #chunk up web service calls
  message('warning expected here about data length:')
  split_unique_ids <- split(unique_ids, 1:(ceiling(length(unique_ids)/10000)))
  site_df <- lapply(split_unique_ids, dataRetrieval::readNWISsite) %>% 
    bind_rows() %>% 
    select(site_no, station_nm, site_tp_cd, dec_lat_va, dec_long_va)
  saveRDS(site_df, file = outfile)
}

#' Get unique sites between WQP temperature and flow sites
get_unique_sites <- function(outfile, temp_sites_file, flow_sites_file) {
  temp_sites <- readRDS(temp_sites_file)
  flow_sites <- readRDS(flow_sites_file) %>% 
    rename(site_id = site_no, longitude = dec_long_va, 
           latitude = dec_lat_va) 
    #This line didn't change the final number of distinct sites;
    #maybe there were already duplicates in WQP sites?
    #mutate(site_id = paste0('USGS-', site_id))
  #standardize column names, bind, distinct (or else full join?)
  distinct_sites <- bind_rows(temp_sites, flow_sites) %>% 
    distinct(site_id, .keep_all = TRUE)
  saveRDS(distinct_sites, file = outfile)
}

#intersect sites with basin polygon
filter_sites_to_basin <- function(infile, basin_footprint) {
  st_intersection(readRDS(infile), basin_footprint)
}