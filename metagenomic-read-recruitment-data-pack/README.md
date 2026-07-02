# Data Pack: Metagenomic Read Recruitment

This directory contains all input data, intermediate alignments, and anvi'o databases produced by the read recruitment pipeline. The contents are excluded from version control due to file size constraints (exceeding 100 MB per file).

---

## Contents

This directory is populated automatically when `anvio_read_recruitment.sh` downloads and extracts the Meren Lab's data pack. After a successful pipeline run, the following files and subdirectories will be present:

### Input Data

| File / Directory       | Description                                                          |
|------------------------|----------------------------------------------------------------------|
| `genome.fa`            | Reference genome, consisting of a single contig of approximately 5.1 Mb |
| `metagenomes/`         | Paired-end FASTQ files for five mock human gut metagenomes           |

### Bowtie2 Index

| File                   | Description                                                          |
|------------------------|----------------------------------------------------------------------|
| `genome.*.bt2`         | Bowtie2 index files built from `genome.fa`                           |

### Anvi'o Databases

| File                   | Description                                                          |
|------------------------|----------------------------------------------------------------------|
| `genome.db`            | Anvi'o contigs database containing ORFs, HMMs, COGs, and SCG taxonomy |

### Alignment Files

| File                   | Description                                                          |
|------------------------|----------------------------------------------------------------------|
| `<sample>.bam`         | Sorted BAM format mapping reads per sample                           |
| `<sample>.bam.bai`     | BAM index per sample                                                 |

### Anvi'o Profile Databases

| Directory              | Description                                                          |
|------------------------|----------------------------------------------------------------------|
| `<sample>-profile/`    | Single-sample anvi'o profile tracking coverage, variability, and detection |
| `merged-profiles/`     | Merged multi-sample profile database for interactive visualisation   |

---

## Data Retrieval

To regenerate this directory from scratch, run:

```bash
bash anvio_read_recruitment.sh
```

Alternatively, download the archive manually:

```bash
curl -L https://cloud.uol.de/public.php/dav/files/B849axL35cBZzYD \
     -o metagenomic-read-recruitment-data-pack.tar.gz
tar -zxvf metagenomic-read-recruitment-data-pack.tar.gz
```
