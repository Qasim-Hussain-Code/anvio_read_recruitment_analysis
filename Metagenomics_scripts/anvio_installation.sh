# check conda version
# conda installation will take around 32 GB space with databases, so make sure you have enough space on your computer
conda --version

# if you already have anvio installed
conda deactivate
conda remove -n anvio-9 --all -y

# installation starts here
conda create -y --name anvio-9 python=3.10
conda activate anvio-9
conda install -y -c conda-forge -c bioconda python=3.10 \
        sqlite=3.46 prodigal idba mcl muscle=3.8.1551 famsa hmmer diamond \
        blast megahit spades bowtie2 bwa graphviz "samtools>=1.9" \
        trimal iqtree trnascan-se fasttree vmatch r-base r-tidyverse \
        r-optparse r-stringi r-magrittr bioconductor-qvalue meme ghostscript \
        nodejs=20.12.2 llvmlite numba

# try this, if it doesn't install, don't worry (it is sad, but OK):
conda install -y -c bioconda fastani

# download anvio-9
curl -L https://github.com/merenlab/anvio/releases/download/v9/anvio-9.tar.gz \
        --output anvio-9.tar.gz
pip install anvio-9.tar.gz


# great if everything installed correctly
# test it out by running
#anvi-self-test --suite mini


# run commands for databases
anvi-setup-scg-taxonomy
anvi-setup-ncbi-cogs
anvi-setup-kegg-data


# this will be a proof to check if everything works for pangenomics
#anvi-self-test --suite pangenomics

# create new conda env for concoct for automated binning
conda create -y --name concoct python=3.10
conda activate concoct
conda install -y -c bioconda concoct=1.1.0
