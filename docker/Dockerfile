FROM rocker/geospatial:4.0.4 

#add additional R packages to install here:
RUN install2.r --error \
  nhdplusTools \
  ggmap \
  ggsn \
  aws.signature \
  aws.s3 \
  pryr \
  dataRetrieval \
  DiagrammeR \
  hexbin

RUN Rscript -e 'remotes::install_github("richfitz/remake"); remotes::install_github("USGS-R/scipiper")'

#set timezone
ENV TZ America/New_York


