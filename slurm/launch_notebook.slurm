#!/bin/bash
#SBATCH -J r-notebook
#SBATCH -t 7:00:00               # time
#SBATCH -o %j-notebook.out
#SBATCH -p normal,UV
#SBATCH -A iidd          # your account code
#SBATCH -n 1
#SBATCH -c 1
#SBATCH --mem=120GB

JPORT=`shuf -i 8400-9400 -n 1`

echo
echo "##################################################################"
echo "Run the following ssh command from a new terminal on your desktop:"
echo "ssh -N -L $JPORT:`hostname`:$JPORT $USER@yeti.cr.usgs.gov"
echo "##################################################################"
echo
echo
echo "##################################################################"
echo "Copy and paste the 127.0.0.1 URL below into a browser on your desktop"
echo "##################################################################"
echo

#start the notebook inside a container 
module load singularity/3.4.1
srun singularity exec -B /cxfs:/cxfs ~/WQP_Analytics/binder_4.0.3.sif jupyter-notebook --ip '*' --no-browser --port $JPORT --notebook-dir $PWD

