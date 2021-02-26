find_endpoints <- function(in_ind, out_ind) {
  
  network_reaches <- readRDS(as_data_file(in_ind)) 
  print(pryr::object_size(network_reaches))
  message('read done')
  #should take about 9 minutes for national, single-threaded with geofabric
  cl <- makeCluster(detectCores() - 1, setup_strategy = "sequential")
  message('cluster set up')
  network_reaches_indices <- clusterSplit(cl, 1:nrow(network_reaches))
  network_reaches_split <- lapply(X = network_reaches_indices, FUN = function(x) {network_reaches[x,]})
  clusterEvalQ(cl, library(sf))
  clusterEvalQ(cl, library(dplyr))
  add_endpoints <- function(df){
    df %>% rowwise() %>%
      mutate(end_points = sf::st_cast(Shape, "POINT") %>% {list(c(head(.,1),tail(.,1)))})
  }
  message('starting parallel...')
  network_applied <- parLapply(cl, X = network_reaches_split, fun = add_endpoints)
  stopCluster(cl)
  message('binding cluster output...')
  network_reaches_endpoints <- data.table::rbindlist(network_applied)
  saveRDS(network_reaches_endpoints, file = as_data_file(out_ind))
  sc_indicate(out_ind)
}