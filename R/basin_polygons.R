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
