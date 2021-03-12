#' Match each site with a reach (seg_id/COMID)
get_site_flowlines <- function(outind, reaches_direction_ind, sites_file, search_radius) {
  
  reaches_direction <- readRDS(as_data_file(reaches_direction_ind))
  
  sites <- readRDS(sites_file) %>% 
    slice(1:10)
  
  #set up NHDPlus fields used by get_flowline_index
  #TODO: logic to add fields if using geofabric in initial load step
  #could have function early on to check expected fields
  #nhdplusTools expects NHDPlus field names
  reaches_nhd_fields <- reaches_direction %>%
    select(COMID = seg_id, Shape, REACHCODE, ToMeas, FromMeas) %>%
    # mutate(REACHCODE = COMID, ToMeas = 100, FromMeas = 100) %>%
    st_as_sf()
  print(pryr::object_size(reaches_nhd_fields))
  sites_sf <- sites %>% rowwise() %>%
    filter(across(c(longitude, latitude), ~ !is.na(.x))) %>%
    mutate(Shape = list(st_point(c(longitude, latitude), dim = "XY"))) %>%
    st_as_sf() %>% st_set_crs(4326) %>%
    st_transform(st_crs(reaches_nhd_fields)) %>%
    st_geometry()
  message('matching flowlines with reaches...')
  flowline_indices <- nhdplusTools::get_flowline_index(flines = reaches_nhd_fields,
                                                       points = sites_sf,
                                                       max_matches = 1,
                                                       search_radius = search_radius)
  sites_sf_index <- tibble(Shape_site = sites_sf,
                           index = 1:length(sites_sf))
  
  message("rejoining with other geometries, adjusting matches for upstream proximity...")
  #rejoin to original reaches df, get up/downstream distance
  flowline_indices_joined <- flowline_indices %>%
    #select(seg_id = COMID, -REACHCODE, -REACH_meas, everything()) %>%
    left_join(reaches_direction, by = c("seg_id")) %>%
    left_join(sites_sf_index, by = c(id = "index")) %>%
    mutate(site_upstream_distance = st_distance(x = Shape_site, y = up_point,
                                                by_element = TRUE),
           site_downstream_distance = st_distance(x = Shape_site, y = down_point,
                                                  by_element = TRUE),
           down_up_ratio = as.numeric(site_downstream_distance / site_upstream_distance))
  
  sites_move_upstream <- flowline_indices_joined %>%
    rowwise() %>%
    mutate(seg_id_reassign = if_else(down_up_ratio > 1,
                                     true = check_upstream_reach(matched_seg_id = seg_id,
                                                                 down_up_ratio = down_up_ratio,
                                                                 reaches_direction = reaches_direction),
                                     false = list(seg_id),
                                     missing = list(seg_id))) %>%
    rename(seg_id_orig_match = seg_id) %>%
    unnest_longer(seg_id_reassign) %>% #handle when site matched to two reaches at intersection
    select(-to_seg, -seg_id_nhm, -Version, -shape_length, -Shape, -end_points,
           -which_end_up, -up_point, -down_point) %>%
    #drop columns and rejoin to get correct geometries for sites that were
    #moved upstream
    left_join(reaches_direction, by = c(seg_id_reassign = 'seg_id'))
  
  #make sure each site is matched to only one reach
  assert_that(class(sites_move_upstream$seg_id_reassign) == 'integer')
  assert_that(length(unique(sites_move_upstream$id)) == nrow(sites_move_upstream),
              msg = 'There are repeated site IDs in the site-reach matches')
  assert_that(sum(is.na(sites_move_upstream$seg_id_reassign)) == 0,
              msg = 'There are NAs in the matched reach column')
  saveRDS(sites_move_upstream, file = as_data_file(outind))
  message("uploading...")
  sc_indicate(outind)
}


#' get upstream reach: if multiple, return original match;
#' if only one upstream reach, return it
#'
#' Expects only reaches where up_down_ratio > 1
check_upstream_reach <- function(matched_seg_id, down_up_ratio, reaches_direction) {
  #if_else will replace this value
  if(down_up_ratio <= 1 || is.na(down_up_ratio)) {
    return(list(NA))
  }
  
  upstream_reaches <- filter(reaches_direction, to_seg == matched_seg_id)
  
  if(nrow(upstream_reaches) > 1 | nrow(upstream_reaches) == 0) { #upstream point is a confluence or source
    return(list(matched_seg_id))
  } else if(nrow(upstream_reaches) == 1){
    return(list(upstream_reaches$seg_id))
  }
}
