#!/bin/bash
#SBATCH -J site_reach_batch
#SBATCH -t 3:00:00               # time
#SBATCH -o slurm_output/batch_%j.out
#SBATCH -p normal,UV
#SBATCH -A iidd          # your account code
#SBATCH -n 1
#SBATCH -c 13
#SBATCH --mem=120GB
#SBATCH --mail-user=wwatkins@usgs.gov
#SBATCH --mail-type=all

module load singularity/3.4.1

srun singularity exec --bind=/cxfs national_site_reach_v0.1.sif \
  Rscript -e 'library(scipiper); scmake("out/reach_direction.rds.ind")'

