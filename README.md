# Basin-agnostic site to reach matching

Pipeline for matching data collection sites to network reaches.  


## Notes as of March 2021, first working version

This pipeline accepts a basin footprint and corresponding HUCs (at any scale).  The network and sites are subset to the basin footprint, and the same site-reach algorithm from the `2wp-temp-observations` repo are executed.  

I wrote this pipeline to work with either the NHDPlusV2 or the USGS geospatial fabric.  Geospatial fabric column names are used throughout (except with nhdplusTools).  However, I have only tested the pipeline with the NHDPlus.  To use with the geospatial fabric, new network download/prep step(s) should be added.  Some minor column name logic may need be required elsewhere.  

### Scalability

### Running on Denali vs Yeti

### To run on a new basin


#### Future implementation of national-scale matching

