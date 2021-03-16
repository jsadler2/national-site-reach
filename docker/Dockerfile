#4.03 Rstudio has permission issues in Singularity
FROM rocker/geospatial:4.0.2 

#add additional R packages to install here:
RUN install2.r --error \
  nhdplusTools \
  ggmap \
  ggsn \
  aws.signature \
  aws.s3 \
  pryr \
  dataRetrieval

RUN Rscript -e 'remotes::install_github("richfitz/remake"); remotes::install_github("USGS-R/scipiper")'

#set timezone
ENV TZ America/New_York


