find_endpoints <- function(in_ind, out_ind) {
  
  network_reaches <- readRDS(as_data_file(in_ind)) #%>% slice_sample(prop=0.5) 
  print(pryr::object_size(network_reaches))
  message('read done')
  #should take about 9 minutes for national, single-threaded with geofabric
  #cores_to_use <- detectCores() - 1
  cores_to_use <- 10
  cl <- makeCluster(cores_to_use, setup_strategy = "sequential",
                    outfile = 'cluster_out.txt')
  message('cluster set up on ', cores_to_use, ' cores')
  network_reaches_indices <- clusterSplit(cl, 1:nrow(network_reaches))
  network_reaches_split <- lapply(X = network_reaches_indices, FUN = function(x) {network_reaches[x,]})
  #TODO: could drop network_reaches object here, check size of list, garbage collect in add_endpoints?
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
  #TODO: assert that no NAs in endpoints
  network_reaches_endpoints <- data.table::rbindlist(network_applied)
  saveRDS(network_reaches_endpoints, file = as_data_file(out_ind))
  sc_indicate(out_ind)
}

get_reach_direction <- function(seg_ids, reaches_bounded, assume_upstream_first) {
  seg_ids_df <- dplyr::filter(reaches_bounded, seg_id %in% seg_ids) %>% 
    slice_sample(n = 10000)
  if(!assume_upstream_first)
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

#' Add missing reaches to a chunk of the network so that up/down reaches are included
#' Enables parallelization beyond chunking by HUC.
#' @param seg_df_chunk chunk of network, with only seg_id and to/from
#' @param full_reach_df data frame of entire network with geoms
add_missing_reference_reaches <- function(seg_df_chunk, full_reach_df) {
  missing_to_segs <- seg_df_chunk %>% 
    filter(!to_seg %in% seg_df_chunk$seg_id,
           to_seg > 0, !is.na(to_seg)) %>% #to_seg = 0 is NHD; geofabric might use NA?
          pull(to_seg)
  missing_from_segs <- seg_df_chunk %>% 
    filter(!from_seg %in% seg_df_chunk$seg_id,
           !is.na(from_seg)) %>% 
    pull(from_seg)
  reference_segs_to_add <- full_reach_df %>% 
    select(seg_id, Shape, end_points) %>% 
    filter((seg_id %in% missing_to_segs) | (seg_id %in% missing_from_segs)) %>% 
    mutate(check_reach = FALSE)
  full_df_chunk <- full_reach_df %>% 
    filter(seg_id %in% seg_df_chunk$seg_id) %>% 
    mutate(check_reach = TRUE) %>% 
    bind_rows(reference_segs_to_add)
  browser()
  assert_that(all(na.omit(full_df_chunk$to_seg) %in% full_df_chunk$seg_id))
  assert_that(all(na.omit(full_df_chunk$from_set) %in% full_df_chunk$seg_id))
  return(full_df_chunk)
}


compute_up_down_stream_endpoints <- function(reaches_bounded_ind, out_ind) {
  
  reaches_bounded <- readRDS(as_data_file(reaches_bounded_ind)) %>%
    ungroup() 
  
  #TODO: set up chunks using from_seg
  just_seg_ids_to <- select(reaches_bounded, seg_id, to_seg, Divergence) #%>% 
    #filter(Divergence < 2) 
    
  #confluences will result in duplicates; reduce from_segs to only one reach
  #per downstream segment with group by and slice
  #TODO: do the same to account for divergences; use 
  #No, just use the first result when getting up/downstream
  #and there are multiple matches; don't filter by feature type at all
  just_seg_ids_from <- select(reaches_bounded, seg_id, to_seg) %>% 
    # filter(!is.na(to_seg)) %>% 
    # group_by(to_seg) %>% 
    # slice(1) %>% 
    rename(from_seg = seg_id, seg_id = to_seg)
  
  with_from_seg <- just_seg_ids_to %>% 
    left_join(just_seg_ids_from, 
                  by = 'seg_id') 
  #break into chunks, label as check_reach;
  n_cluster_nodes <- length(cl)
  n_reaches <- nrow(reaches_bounded)
  #seg_ids_chunked <- split(with_from_seg, 1:(n_cluster_nodes))
  seg_ids_chunked <- clusterSplit(cl, with_from_seg$seg_id)
  #subset with_from_segs, append reaches, join with geoms
  t <- with_from_seg %>% filter(seg_id %in% seg_ids_chunked[[1]]) %>% 
    add_missing_reference_reaches(seg_df_chunk = ., full_reach_df = reaches_bounded)
  
  #find what seg_ids are missing from to_seg and from_seg (excluding 0 and NA)
  #bind these seg_ids onto chunk from main df; check_reach will be false, since 
  #these reaches are just here to compare to
  #apply this in serial, or over a small cluster before full parallel section
  t <- add_missing_reference_reaches(seg_ids_chunked[[1]])
  
  # %>% 
  #   left_join(reaches_bounded, by = c("seg_id", "to_seg"))
  
  #use check_reach in parallelized function
  
  
  #geofabric: ~26 minutes for national single-threaded, ~5 minutes on 7 cores
  n_cores_to_use <- detectCores() - 1
  cl <- makeCluster(n_cores_to_use - 1)
  clusterEvalQ(cl, lapply(c('sf', 'dplyr', 'purrr'), library, character.only = TRUE))
  seg_ids_split <- clusterSplit(cl, reaches_bounded$seg_id)
  message('cluster setup complete, starting parallel execution on ', n_cores_to_use, ' cores...')
  cluster_results <- parLapply(cl = cl, X = seg_ids_split,
                               fun = get_reach_direction, reaches_bounded)
  stopCluster(cl)
  message('parallel done')
  results_bound <- data.table::rbindlist(cluster_results)
  
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
