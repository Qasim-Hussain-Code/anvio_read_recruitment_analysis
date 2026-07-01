curl -L https://cloud.uol.de/public.php/dav/files/B849axL35cBZzYD 
     -o metagenomic-read-recruitment-data-pack.tar.gz

tar -zxvf metagenomic-read-recruitment-data-pack.tar.gz
cd metagenomic-read-recruitment-data-pack

ls metagenomes/

# prepare for anvio
conda activate anvio-9
anvi-gen-contigs-database -f genome.fa -o genome.db

# run HMMs on the contigs database
anvi-run-ncbi-cogs -c genome.db --num-threads 10
anvi-run-hmms -c genome.db
anvi-run-scg-taxonomy -c genome.db --num-threads 10


# bowtie2 index
bowtie2-build genome.fa genome

bowtie2 -x genome 
    -1 metagenomes/magdalena-R1.fastq 
    -2 metagenomes/magdalena-R2.fastq 
    -S magdalena.sam 
    -p 10

samtools view -F 4 
    -bS magdalena.sam 
    -o magdalena-RAW.bam 
    --threads 10

samtools sort magdalena-RAW.bam -o magdalena.bam --threads 10
samtools index magdalena.bam --threads 10


anvi-profile -i magdalena.bam 
    -c genome.db 
    -o magdalena-profile 
    --cluster 
    -T 10

anvi-interactive -c genome.db 
    -p magdalena-profile/PROFILE.db



# for loop for all
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

anvi-merge *-profile/PROFILE.db 
    -c genome.db 
    -o merged-profiles


anvi-interactive -p merged-profiles/PROFILE.db 
    -c genome.db


# collection
anvi-script-add-default-collection -p merged-profiles/PROFILE.db
anvi-interactive -p merged-profiles/PROFILE.db 
    -c genome.db 
    -C DEFAULT 
    -b EVERYTHING 
    --gene-mode