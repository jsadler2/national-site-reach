#!/bin/bash
#SBATCH -J rstudio
#SBATCH -t 2:00:00               # time
#SBATCH -o slurm_output/batch_%j.out
#SBATCH -p normal,UV,short
#SBATCH -A iidd          # your account code
#SBATCH -n 1
#SBATCH -c 15
#SBATCH --mem=120GB
#SBATCH --mail-user=wwatkins@usgs.gov
#SBATCH --mail-type=all

module load singularity/3.4.1

srun singularity exec --bind=/cxfs national_site_reach_v0.1.sif \
  Rscript -e 'library(scipiper); scmake("6_network/out/reach_endpoints.rds.ind")'

