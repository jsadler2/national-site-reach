#' Download and unzip the NHDPlus geodatabase
#' If on Yeti, need to run on login node for network access
download_nhd <- function(out_ind) {
  out_dir <- scipiper::as_data_file(out_ind)
  if(dir.exists(out_dir) && file.exists(out_ind)) {
    current_files <- tools::md5sum(dir(out_dir, full.names=TRUE))
    expected_files <- unlist(yaml::yaml.load_file(out_ind))
    if(all.equal(current_files, expected_files)) {
      message('NHDPlus is already downloaded and matches the .ind file; doing nothing')
      return()
    } else {
      stop("NHDPlus is downloaded but doesn't match the .ind file. Stopping to let you manually update/delete one or both to save time (it's a big download!)")
    }
  }
  # if the data don't yet exist, download and unzip. if they do already exist,
  # then either (1) the ind file also exists and we will have returned or
  # stopped above, or (2) the ind file doesn't exist and will get created below.
  # we'll post a message if it's case 2.
  if(!dir.exists(out_dir)) {
    #TODO: need to change directory before unzipping, and point indicator to actual .gdb folder
    message("Downloading NHDPlus...")
    seven_zip_file <- 'in/NationalData/NHDPlusV21_NationalData_Seamless_Geodatabase_Lower48_07.7z'
    download.file('https://s3.amazonaws.com/edap-nhdplus/NHDPlusV21/Data/NationalData/NHDPlusV21_NationalData_Seamless_Geodatabase_Lower48_07.7z', 
                  destfile=seven_zip_file)
    system(command = sprintf('7za x %s', seven_zip_file))
    file.rename(from = 'in/NHDPlusNationalData', to = out_dir)
    unlink(seven_zip_file)
  } else {
    message('GF is already downloaded; creating an .ind file to match')
  }
  
  # write an ind file with hash for each file in the directory
  sc_indicate(out_ind, data_file=dir(out_dir, full.names=TRUE))
}

#' Extract needed parts of NHDPlus gdb, prep for site-reach matching by
#' dropping Z/M dimensions, reprojecting, and standardizing column names
get_nhdplus_flowpaths <- function(out_ind, in_ind) {
  gdb_directory <- as_data_file(in_ind)
  #could extract this to a yml file
  nhd_columns_keep <- c('COMID', 'GNIS_ID', 'GNIS_NAME',
                        'LENGTHKM', 'REACHCODE', 'FTYPE',
                        'FCODE', 'StreamOrde', 'ArbolateSu',
                        'Shape', 'Divergence', 'ToMeas', 'FromMeas')
  flowline_network <- st_read(dsn = gdb_directory,
                              layer = 'NHDFlowline_Network') %>% 
    select(all_of(nhd_columns_keep)) %>% 
    st_zm(drop = TRUE, what = 'ZM')
  
  #flow relationships are in a separate layer   
  flow_connections <- st_read(dsn = gdb_directory,
                              layer = 'PlusFlow') %>% 
    select('FROMCOMID', 'TOCOMID', 'DIRECTION')
  
  flowline_network_connections <- left_join(flowline_network, 
                                            flow_connections,
                                            by = c(COMID = 'FROMCOMID'))
  out_data_file <- as_data_file(out_ind)
  saveRDS(flowline_network_connections, file = out_data_file)
  sc_indicate(out_ind)
}

#' Filter NHDPlus to specified feature types, rename columns
#' to match what is used in processing steps (currently using geofabric names)
#' @param huc_stem_patterns char Character vector of patterns to be passed into 
#' stringr::str_starts, which is then run on the NHDPlus REACHCODE field.
#' Use to filter the network to specific hucs
filter_rename_nhdplus <- function(in_ind, out_ind, huc_stem_patterns = NULL) {
  out_network <- readRDS(as_data_file(in_ind)) %>% 
    rename(seg_id = COMID, to_seg = TOCOMID) %>% 
    mutate(shape_length = LENGTHKM * 1000) %>% 
    st_transform(crs = 'ESRI:102039') #Reproject to USGS proj, same as geofabric
  if(!is.null(huc_stem_patterns)) {
    out_network <- out_network %>% 
      filter(stringr::str_starts(string = REACHCODE, pattern = huc_stem_patterns))
  }
  saveRDS(out_network, as_data_file(out_ind))
  sc_indicate(out_ind)
}
