#!/bin/bash

eval "$(conda shell.bash hook)"

conda activate 01_short_read_qc

THREADS=$(( $(nproc) - 2 ))

# ============================
# 1. FASTQC (raw reads)
# ============================
mkdir -p 01_fastqc_report

find fastq -maxdepth 1 -name "*_1.fastq.gz" -print0 | \
    parallel -0 -j "$THREADS" '
        fastq={}
        fastqc -o 01_fastqc_report "${fastq}" "${fastq/_1.fastq.gz/_2.fastq.gz}"
    '

# ============================
# 2. FASTP (trimming & filtering)
# ============================
mkdir -p 02_fastp_trimmed 03_fastp_reports

find fastq -maxdepth 1 -name "*_1.fastq.gz" -print0 | \
    parallel -0 -j "$THREADS" '
        r1={}
        r2=${r1/_1.fastq.gz/_2.fastq.gz}
        basename=$(basename "$r1" _1.fastq.gz)
        fastp \
            -i "$r1" -I "$r2" \
            -o "02_fastp_trimmed/${basename}_1_trimmed.fastq.gz" \
            -O "02_fastp_trimmed/${basename}_2_trimmed.fastq.gz" \
            --html "03_fastp_reports/${basename}_fastp.html" \
            --json "03_fastp_reports/${basename}_fastp.json" \
            --report_title "$basename" \
            --cut_front --cut_tail --cut_window_size 1 --cut_mean_quality 20 \
            --length_required 50 \
            --detect_adapter_for_pe \
            2> "03_fastp_reports/${basename}_fastp.log"
    '

# ============================
# 3. FASTQC (trimmed reads)
# ============================
mkdir -p 05_fastqc_trimmed_report

find 02_fastp_trimmed -maxdepth 1 -name "*_1_trimmed.fastq.gz" -print0 | \
    parallel -0 -j "$THREADS" '
        fastq={}
        fastqc -o 05_fastqc_trimmed_report "${fastq}" "${fastq/_1_trimmed.fastq.gz/_2_trimmed.fastq.gz}"
    '

# ============================
# 4. MULTIQC (aggregate all)
# ============================
conda activate 02_multiqc
mkdir -p 04_multiqc_report

multiqc \
    01_fastqc_report \
    03_fastp_reports \
    05_fastqc_trimmed_report \
    -o 04_multiqc_report \
    --title "Short Read QC Report" \
    --filename multiqc_report.html

# ============================
# 5. MEGAHIT CO-ASSEMBLY
# ============================
conda activate anvio-9 # or whichever env has megahit installed
# remove if there is any existing output directory
rm -rf 06_coassembly_megahit

THREADS=$(( $(nproc) - 6 ))
# Build comma-separated lists of all R1 and R2 trimmed files
R1_FILES=$(find 02_fastp_trimmed -maxdepth 1 -name "*_1_trimmed.fastq.gz" | sort | paste -sd "," -)
R2_FILES=$(find 02_fastp_trimmed -maxdepth 1 -name "*_2_trimmed.fastq.gz" | sort | paste -sd "," -)

echo "R1 files: $R1_FILES"
echo "R2 files: $R2_FILES"

megahit \
    -1 "$R1_FILES" \
    -2 "$R2_FILES" \
    --min-contig-len 1000 \
    --presets meta-large \
    -m 0.50 \
    -o 06_coassembly_megahit \
    -t 4



ASSEMBLY="06_coassembly/final.contigs.fa"

# ==========================================
# 5. ASSEMBLY QUALITY & GFA FILES
# ==========================================
mkdir -p 07_assembly_qc 08_gfa_files

echo "=== Assembly Statistics ==="
echo "Total contigs: $(grep -c ">" "$ASSEMBLY")"
echo "Total bases: $(grep -v ">" "$ASSEMBLY" | wc -m)"

# Convert to FASTG (k=99; adjust if your assembly used different k-mer)
conda activate 03_megahit
megahit_toolkit contig2fastg 99 "$ASSEMBLY" > 08_gfa_files/final.contigs.fastg
echo "FASTG saved to 08_gfa_files/final.contigs.fastg"

# QUAST quality assessment
conda activate 04b_quast
metaquast -t "$THREADS" -o 07_assembly_qc/metaquast -m 1000 "$ASSEMBLY"

# ==========================================
# 6. ANVI'O WORKFLOW (parallelized)
# ==========================================
conda activate anvio-9  # <-- adjust to your anvi'o environment

mkdir -p 09_anvio/{mapping,profiles,SUMMARY_METABAT2,SUMMARY_MAXBIN2}

# Reformat contigs for anvi'o
anvi-script-reformat-fasta "$ASSEMBLY" \
    -o 09_anvio/contigs.anvio.fa \
    --min-len 1000 \
    --simplify-names \
    --report-file 09_anvio/name_conversion.txt

# Build bowtie2 index (once)
bowtie2-build 09_anvio/contigs.anvio.fa 09_anvio/contigs.anvio.fa.index

# Parallel mapping: bowtie2 -> SAM -> BAM, then remove SAM to save space
echo "=== Mapping all samples in parallel ==="
find 02_fastp_trimmed -maxdepth 1 -name "*_1_trimmed.fastq.gz" -print0 | \
    parallel -0 -j "$THREADS" '
        r1={}
        r2=${r1/_1_trimmed.fastq.gz/_2_trimmed.fastq.gz}
        sample=$(basename "$r1" _1_trimmed.fastq.gz)
        echo "  Mapping: $sample"
        bowtie2 --very-fast -x 09_anvio/contigs.anvio.fa.index -1 "$r1" -2 "$r2" \
            -S 09_anvio/mapping/"${sample}".sam
        samtools view -bS 09_anvio/mapping/"${sample}".sam > 09_anvio/mapping/"${sample}".bam
        rm 09_anvio/mapping/"${sample}".sam
    '

# Parallel sort and index BAMs with anvi-init-bam
echo "=== Sorting & indexing BAMs in parallel ==="
find 09_anvio/mapping -maxdepth 1 -name "*.bam" ! -name "*.sorted.bam" -print0 | \
    parallel -0 -j "$THREADS" '
        bam={}
        sample=$(basename "$bam" .bam)
        anvi-init-bam "$bam" -o 09_anvio/mapping/"${sample}".sorted.bam
    '

# Create contigs database
anvi-gen-contigs-database \
    -f 09_anvio/contigs.anvio.fa \
    -o 09_anvio/contigs.db \
    -n meta_codanics

# Run HMMs
anvi-run-hmms -c 09_anvio/contigs.db

# Display contigs stats
echo "=== Contigs Stats ==="
anvi-display-contigs-stats 09_anvio/contigs.db

# Parallel profiling of each sample
echo "=== Profiling all samples in parallel ==="
find 09_anvio/mapping -maxdepth 1 -name "*.sorted.bam" -print0 | \
    parallel -0 -j "$THREADS" '
        bam={}
        sample=$(basename "$bam" .sorted.bam)
        mkdir -p 09_anvio/profiles/"$sample"
        anvi-profile -i "$bam" -c 09_anvio/contigs.db --output-dir 09_anvio/profiles/"$sample"
    '

# Merge all profiles
echo "=== Merging profiles ==="
PROFILE_DBS=$(find 09_anvio/profiles -name "PROFILE.db" | sort | paste -sd " " -)

anvi-merge $PROFILE_DBS \
    -o 09_anvio/merged_profiles \
    -c 09_anvio/contigs.db \
    --enforce-hierarchical-clustering

# ==========================================
# 7. BINNING
# ==========================================

# Metabat2
echo "=== Binning with Metabat2 ==="
anvi-cluster-contigs \
    -p 09_anvio/merged_profiles/PROFILE.db \
    -c 09_anvio/contigs.db \
    -C METABAT2 \
    --driver metabat2 \
    --just-do-it \
    --log-file 09_anvio/log-metabat2

anvi-summarize \
    -p 09_anvio/merged_profiles/PROFILE.db \
    -c 09_anvio/contigs.db \
    -o 09_anvio/SUMMARY_METABAT2 \
    -C METABAT2

# MaxBin2
echo "=== Binning with MaxBin2 ==="
anvi-cluster-contigs \
    -p 09_anvio/merged_profiles/PROFILE.db \
    -c 09_anvio/contigs.db \
    -C MAXBIN2 \
    --driver maxbin2 \
    --just-do-it \
    --log-file 09_anvio/log-maxbin2

anvi-summarize \
    -p 09_anvio/merged_profiles/PROFILE.db \
    -c 09_anvio/contigs.db \
    -o 09_anvio/SUMMARY_MAXBIN2 \
    -C MAXBIN2

# ==========================================
# 8. MAG QUALITY ESTIMATION
# ==========================================
echo "=== MAG Quality Estimation ==="
anvi-estimate-genome-completeness \
    -p 09_anvio/merged_profiles/PROFILE.db \
    -c 09_anvio/contigs.db \
    --list-collections

echo ""
echo "========================================"
echo "Workflow complete!"
echo ""
echo "To launch interactive display:"
echo "  anvi-interactive -p 09_anvio/merged_profiles/PROFILE.db -c 09_anvio/contigs.db -C METABAT2"
echo "========================================"