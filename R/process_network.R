#' @param separate logical should the endpoints column be broken into separate first/last point columns?  
#' For NHDPlusV2 these are up/downstream points based on QAQC steps in manual, Page 102 Check 13
find_endpoints <- function(in_ind, out_ind, separate = FALSE) {
  n_cores_to_use <- as.numeric(Sys.getenv('SLURM_CPUS_ON_NODE')) - 1
  network_reaches <- readRDS(as_data_file(in_ind))  
  print(pryr::object_size(network_reaches))
  message('read done')
  #should take about 9 minutes for national, single-threaded with geofabric
  #TODO: dynamically set number of cores based on RAM per cpu
  #Seems to need at least 8-10 GB/core; 6 doesn't work, 12 does
  file.remove('cluster_out.txt')
  cl <- makeCluster(n_cores_to_use, setup_strategy = "sequential",
                    outfile = 'cluster_out.txt')
  message('cluster set up on ', n_cores_to_use, ' cores')
  network_reaches_indices <- clusterSplit(cl, 1:nrow(network_reaches))
  network_reaches_split <- lapply(X = network_reaches_indices, FUN = function(x) {network_reaches[x,]})
  #TODO: could drop network_reaches object here, check size of list, garbage collect in add_endpoints?
  clusterEvalQ(cl, library(sf))
  clusterEvalQ(cl, library(dplyr))
  add_endpoints <- function(df, separate){
    if(separate) {
      df %>% rowwise() %>%
        mutate(shape_points = list(sf::st_cast(Shape, "POINT")),
               first_point = head(shape_points, 1),
               last_point = tail(shape_points, 1)) %>% 
        select(-shape_points)
    } else {
      df %>% rowwise() %>% 
        mutate(end_points = sf::st_cast(Shape, "POINT")) %>% 
        {list(c(head(., 1), tail(.,1)))}
    }
  }
  message('starting parallel...')
  network_applied <- parLapply(cl, X = network_reaches_split, fun = add_endpoints, separate = separate)
  stopCluster(cl)
  message('binding cluster output...')
  #TODO: assert that no NAs in endpoints
  network_reaches_endpoints <- data.table::rbindlist(network_applied)
  saveRDS(network_reaches_endpoints, file = as_data_file(out_ind))
  sc_indicate(out_ind)
}

get_reach_direction <- function(seg_ids, reaches_bounded) {
  seg_ids_df <- dplyr::filter(reaches_bounded, seg_id %in% seg_ids) 
  
  reaches_bounded_direction_subset <- seg_ids_df %>%
    dplyr::mutate(
      which_end_up = sapply(seg_id, function(segid) {
        reach <- dplyr::filter(reaches_bounded, seg_id == segid)
        if(!is.na(reach$to_seg)) { # non-river-mouths
          # upstream endpoint is the one furthest from the next reach downstream
          to_reach <- dplyr::filter(reaches_bounded, seg_id == reach$to_seg) %>% 
            slice(1)
          which.max(sf::st_distance(reach$end_points[[1]], to_reach$Shape))
        } else { # river mouths
          # upstream endpoint is the one closest to a previous reach upstream
          from_reach <- dplyr::filter(reaches_bounded, to_seg == reach$seg_id) %>% 
            slice(1)
          if(nrow(from_reach) > 0) {
            which.min(sf::st_distance(reach$end_points[[1]], from_reach$Shape))
          } else { #A river mouth with no upstream segment (small coastal streams)
            NA_integer_
          }
        } # turns out that the first point is always the upstream point for the DRB at least. that's nice, but we won't rely on it.
      }),
      up_point = purrr::map2(end_points, which_end_up, function(endpoints, whichendup) { endpoints[[whichendup]] }),
      down_point = purrr::map2(end_points, which_end_up, function(endpoints, whichendup) { endpoints[[c(1,2)[-whichendup]]] }))
  return(reaches_bounded_direction_subset)
}

compute_up_down_stream_endpoints <- function(reaches_bounded_ind, out_ind,
                                             assume_upstream_first = FALSE) {
  
  reaches_bounded <- readRDS(as_data_file(reaches_bounded_ind)) %>%
    ungroup() 
  
  if(!assume_upstream_first) {
    warning("The reach direction code has not been adapted for the scale of NHDPlus")
    #~26 minutes for national single-threaded, ~5 minutes on 7 cores
    n_cores_to_use <- as.numeric(Sys.getenv('SLURM_CPUS_ON_NODE')) - 1
    cl <- makeCluster(n_cores_to_use)
    clusterEvalQ(cl, lapply(c('sf', 'dplyr', 'purrr'), library, character.only = TRUE))
    seg_ids_split <- clusterSplit(cl, reaches_bounded$seg_id)
    cluster_results <- parLapply(cl = cl, X = seg_ids_split,
                                 fun = get_reach_direction, reaches_bounded)
    stopCluster(cl)
    results_bound <- bind_rows(cluster_results)
    results_bound <- data.table::rbindlist(cluster_results)
  } else { 
    #don't need to parallelize
    #put endpoints separately from the start (with separate = TRUE in find_endpoints), 
    #then can just rename
    results_bound <- reaches_bounded %>% rename(up_point = first_point, down_point = last_point)
  }
  
  shape_crs <- st_crs(results_bound$Shape)
  reaches_direction <- results_bound %>%
    st_sf(crs = shape_crs, sf_column_name = 'Shape') %>%
    mutate(up_point = st_sfc(up_point, crs = shape_crs),
           #would make sense to do the same here for end_points
           down_point = st_sfc(down_point, crs = shape_crs))
  message('writing output...')
  saveRDS(reaches_direction, file = as_data_file(out_ind))
  sc_indicate(out_ind)
}

