#script to assemble UCRB from HUC4 polys

#download from Box here: https://nrcs.app.box.com/v/huc/folder/39640323180

zip_path <- '~/Downloads/wbdhu4_a_us_september2020.zip'

unzip(zip_path, exdir = 'in')

library(sf)
library(tidyverse)
gdb_path <- 'in/wbdhu4_a_us_september2020.gdb'
st_layers(gdb_path)
huc4_polys <- st_read(gdb_path, layer = 'WBDHU4')

ucrb_huc4_ids <- c('1401', '1402')

ucrb_polys <- huc4_polys %>% filter(huc4 %in% ucrb_huc4_ids)

library(maps)
map('state', regions = c('Colorado'))
plot(ucrb_polys$Shape, add = TRUE)

unioned_ucrb <- st_union(ucrb_polys)
map('state', regions = c('Colorado'))
plot(unioned_ucrb, col = 'tan', add = TRUE)
dir.create('in/ucrb_footprint')
st_write(unioned_ucrb, dsn = 'in/ucrb_footprint/upper_colorado_unioned.shp')


##### Subset sites to basin
library(sf)
sites <- readRDS('in/unique_sites.rds')
basin_polygon <- st_read('in/ucrb_footprint/')

ucrb_sites <- st_intersection(sites, basin_polygon)
maps::map('state', regions = c('Colorado'))
plot(ucrb_sites$geometry, add = TRUE)


#all sites map
maps::map('state')
plot(sites$geometry, cex = 0.1, col = 'blue', add = TRUE)

#now intersect the network, unless there is a field to filter on..
#intersecting with bounding box would also probably do the job, might be more efficient?
ucrb_huc4_ids <- c('1401', '1402')
network <- readRDS('out/NHDPlus_filtered_renamed.rds')
library(tidyverse)  
network_huc4 <- network %>% 
  mutate(huc4 = stringr::str_sub(REACHCODE, 1, 4)) %>% 
  filter(huc4 %in% ucrb_huc4_ids)

maps::map('state', regions = c('Colorado'))
plot(network_huc4$Shape, add = TRUE, cex = 0.1, col = 'dodgerblue')
plot(basin_polygon$geometry, add = TRUE)
