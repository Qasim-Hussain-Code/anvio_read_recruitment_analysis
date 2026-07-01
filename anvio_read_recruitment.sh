#!/bin/bash
set -euo pipefail

# Download data pack
curl -L https://cloud.uol.de/public.php/dav/files/B849axL35cBZzYD \
     -o metagenomic-read-recruitment-data-pack.tar.gz

tar -zxvf metagenomic-read-recruitment-data-pack.tar.gz
cd metagenomic-read-recruitment-data-pack

ls metagenomes/

# Activate anvio-9 conda environment
# (conda activate doesn't work in scripts without sourcing conda init first)
source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate anvio-9

# Prepare for anvio
anvi-gen-contigs-database -f genome.fa -o genome.db

# Run HMMs on the contigs database
anvi-run-ncbi-cogs -c genome.db --num-threads 10
anvi-run-hmms -c genome.db
anvi-run-scg-taxonomy -c genome.db --num-threads 10


# Bowtie2 index
bowtie2-build genome.fa genome

# (1) Perform read recruitment for magdalena
bowtie2 -x genome \
    -1 metagenomes/magdalena-R1.fastq \
    -2 metagenomes/magdalena-R2.fastq \
    -S magdalena.sam \
    -p 10

# (2) Convert SAM to BAM
samtools view -F 4 \
    -bS magdalena.sam \
    -o magdalena-RAW.bam \
    --threads 10

# (3) Sort and index BAM
samtools sort magdalena-RAW.bam -o magdalena.bam --threads 10
samtools index magdalena.bam --threads 10

# Profile the BAM file
anvi-profile -i magdalena.bam \
    -c genome.db \
    -o magdalena-profile \
    --cluster \
    -T 10

# Visualize (comment out if running non-interactively)
# anvi-interactive -c genome.db \
#     -p magdalena-profile/PROFILE.db


# For loop for remaining samples
for person in batuhan alejandra jonas jessika
do
    echo "Working on ${person} ..."
    bowtie2 -x genome -1 metagenomes/${person}-R1.fastq -2 metagenomes/${person}-R2.fastq -S ${person}.sam -p 10
    samtools view -F 4 -bS ${person}.sam -o ${person}-RAW.bam --threads 10
    samtools sort ${person}-RAW.bam -o ${person}.bam --threads 10
    samtools index ${person}.bam --threads 10
    anvi-profile -i ${person}.bam -c genome.db -o ${person}-profile -T 10
    rm -rf ${person}.sam ${person}-RAW.bam
done

# Merge all profiles
anvi-merge *-profile/PROFILE.db \
    -c genome.db \
    -o merged-profiles

# Visualize merged profiles (comment out if running non-interactively)
# anvi-interactive -p merged-profiles/PROFILE.db \
#     -c genome.db

# Collection and gene-mode view
anvi-script-add-default-collection -p merged-profiles/PROFILE.db
# anvi-interactive -p merged-profiles/PROFILE.db \
#     -c genome.db \
#     -C DEFAULT \
#     -b EVERYTHING \
#     --gene-mode