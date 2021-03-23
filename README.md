# Basin-agnostic site to reach matching

Pipeline for matching data collection sites to network reaches.  


## Notes as of March 2021, first working version

This pipeline accepts a basin footprint and corresponding HUCs (at any scale).  The network and sites are subset to the basin footprint, and the same site-reach algorithm from the `2wp-temp-observations` repo are executed.  

I wrote this pipeline to work with either the NHDPlusV2 or the USGS geospatial fabric.  Geospatial fabric column names are used throughout (except with nhdplusTools).  However, I have only tested the pipeline with the NHDPlus.  To use with the geospatial fabric, new network download/prep step(s) should be added.  Some minor column name logic may need be required elsewhere.  

### To run on a Slurm system
Two slurm scripts are included in this repo:  

 - `launch_rstudio.slurm` launches an RStudio server session on the allocated compute node.  Open the Slurm output file and follow the printed instructions to open an SSH tunnel and connect to the session via a web browser.  Note that if you want to run a parallelized step, you need to manually set the `SLURM_CPUS_ON_NODE` environment variable to whatever number was specified in the slurm script, since this variable is not passed into the RStudio session (`Rscript` doesn't have this problem).  This may be fixable.  The Singularity command has an array of extra directory bindings that are required to give Rstudio writable directories for internal processes.
 
- `launch_batch.slurm` Runs scipiper targets non-interactively.  

### Scalability
Any steps using the full NHDPlus will be very unwieldy or not run at all on a laptop.  Steps after it is subset to a basin the size of the UCRB could likely be run on a laptop if needed.  The initial step of reading in the entire NHDPlus takes ~20 minutes on Yeti normal, but the rest of the pipeline funs in a fraction of that time.

### Running on Denali vs Yeti
I ran this pipeline on Yeti normal partition nodes for all my work.  With the container, it should be fully transferable to Denali.  Steps to do this:

1. Pull the image to Denali using Shifter
2. rsync my entire directory `/cxfs/projects/usgs/water/iidd/data-sci/wwatkins/national-site-reach` (or just `in` and `out` if using a different fork) to caldera with `rsync -razvP user@yeti.cr.usgs.gov:<path> <destination>`.
3. Adjust the slurm script (non-interactive or Rstudio) as needed.

It should be runnable on Tallgrass cpu nodes by using Singularity instead of Shifter.  


### No cache sharing implemented
This pipeline is written to be run on HPC platforms, so no cache sharing was implemented.  Indicator files were used to prevent repeated hashing of large files.


## Interchangeable parts
[image](pipeline_diagram.png)
### To run on a new basin
Swap out the basin HUC codes (can be any HUC level, although a single large HUC2 will take a while), and switch the basin footprint shapefile.  The basin footprint could likely be automated by pulling in a database of HUC2/HUC4s into the pipeline. 

### To run with the geospatial fabric instead of NHDPlus
`out/NHDPlus_filtered_renamed.rds.ind` is the last step that is NHDPlus-specific.  The geospatial fabric equivalents could be added from the `2wp-temp-observations` pipeline.  Geospatial fabric naming conventions are used throughout, except where required by `nhdplusTools`.  I have not tested the pipeline with the geospatial fabric, so it is possible some minor column renaming logic may need to be added.

### Site updates
Currently using manually-imported outputs of the national temp and flow observation pipelines: 

- [https://github.com/USGS-R/2wp-temp-observations/blob/master/5_data_munge.yml#L101](https://github.com/USGS-R/2wp-temp-observations/blob/master/5_data_munge.yml#L101)
- [https://github.com/USGS-R/national-flow-observations/blob/master/20_data_munge.yml#L22](https://github.com/USGS-R/national-flow-observations/blob/master/20_data_munge.yml#L22)


### Docker image registry
The current image I used (v0.2) is pushed to a registry in this project: [https://code.chs.usgs.gov/wma/iidd/national-site-reach](https://code.chs.usgs.gov/wma/iidd/national-site-reach).  The actual registry URL is [code.chs.usgs.gov:5001/wma/iidd/national-site-reach/national_site_reach:v0.2](code.chs.usgs.gov:5001/wma/iidd/national-site-reach/national_site_reach:v0.2).  You can push/pull to it (might need to have permissions added) using standard docker commands with a `--docker-login` flag.  

#### Future implementation of national-scale matching
The current pipeline is not fully scalable to the size of the NHDPlus (~50x the reaches of the geospatial fabric).  The `reach_endpoints` step runs on the full NHDPlus, and the up/downstream detection assumes direction based on point order (a documented NHDPlus QC check) so avoids any real work.  The `out/site_flowlines.ind` target will need to be re-written to handle the full NHDPlus.  This could be done by using the `REACHCODE` field to generate a HUC4 field and splitting the network into individual objects based on that, then doing the same with sites by intersecting with HUC4 polygons (not currently in pipeline).  Each HUC4 network piece and sites could be run individually on as many cores as are available with sufficient RAM using a `parallel::clusterApply` variant.  The later step of moving sites upstream if they are within a certain distance of the upstream may or may not need to be parallelized, since it only requires handling the subset of reaches with matched sites, not the entire network.  
