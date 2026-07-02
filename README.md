# Metagenomic Read Recruitment Analysis

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A reproducible read recruitment workflow, implemented end-to-end using anvi'o (v9), Bowtie2, and SAMtools, following the Meren Lab's tutorial on short-read mapping against a reference genome across multiple metagenomic samples.

---

## Background and Rationale

Read recruitment, also referred to as competitive fragment recruitment or metagenomic read mapping, is a foundational technique in microbial ecology for quantifying the relative abundance and nucleotide-level coverage of a reference genome across shotgun metagenomic datasets. Unlike amplicon-based surveys that target taxonomic marker genes, read recruitment leverages the full breadth of metagenomic sequencing data to resolve strain-level variation, estimate per-nucleotide coverage depth, and identify genomic regions under differential ecological selection across environments or hosts.

This repository implements the read recruitment exercise described by the [Meren Lab](https://merenlab.org/tutorials/read-recruitment/), which uses a mock dataset designed to illustrate the core tools and file formats involved in a typical read recruitment analysis. The exercise maps paired-end short reads from five simulated human gut metagenomes, each associated with a different individual (Alejandra, Batuhan, Jessika, Jonas, and Magdalena), against a single reference genome. The downstream profiling, merging, and interactive visualisation steps are handled entirely within the anvi'o ecosystem.

The reference genome (`genome.fa`) is a single-contig assembly of approximately 5.1 Mb in length, representing a microbial population of interest. The metagenomic datasets comprise paired-end Illumina-style reads (R1/R2) for each of the five mock samples. Although the data are synthetic, the analytical steps mirror real-world workflows used to study the distribution of microbial populations across human-associated and environmental metagenomes.

---

## Analytical Questions

Following the tutorial, this pipeline addresses two key questions through interactive visualisation in anvi'o:

1. **Does every individual carry a microbial population that matches this genome?** This is answered by examining mean coverage and detection statistics across all five metagenomes at the contig level.

2. **Does every gene in this genome occur in every individual?** This is answered by switching to gene-mode visualisation, which reveals that certain genes, despite belonging to the same genome, are absent or undetected in specific individuals. This observation reflects the biological reality that accessory genes within a single genome may not be uniformly present across populations in different hosts.

---

## Repository Structure

```
anvio_read_recruitment_analysis/
|
|-- anvio_read_recruitment.sh        # Main pipeline script (end-to-end)
|-- anvio_install.sh                 # Anvi'o v9 installation recipe
|-- license                          # Copyright notice
|-- README.md                        # This document
|
|-- metagenomic-read-recruitment-data-pack/
|   |-- README.md                    # Data directory manifest (placeholder)
|   |-- genome.fa                    # Reference genome (single contig, ~5.1 Mb)
|   |-- genome.db                    # Anvi'o contigs database
|   |-- genome.*.bt2                 # Bowtie2 index files
|   |-- <sample>.bam / .bam.bai      # Sorted, indexed BAM files per sample
|   |-- <sample>-profile/            # Anvi'o single-sample profile databases
|   |-- merged-profiles/             # Merged multi-sample anvi'o profile
|   |
|   |-- metagenomes/
|       |-- README.md                # FASTQ directory manifest (placeholder)
|       |-- <sample>-R1.fastq        # Forward reads per sample
|       |-- <sample>-R2.fastq        # Reverse reads per sample
```

---

## Pipeline Overview

The analysis proceeds through the following stages, each executed within `anvio_read_recruitment.sh`:

### 1. Data Retrieval

The metagenomic data pack is downloaded from the Meren Lab's public repository and extracted locally. This archive contains the reference genome and all paired-end FASTQ files for the five mock metagenomes.

### 2. Contigs Database Generation

An anvi'o contigs database is generated from the reference genome using `anvi-gen-contigs-database`. This step performs open reading frame (ORF) prediction via Prodigal and stores contig-level metadata for all downstream profiling.

### 3. Functional and Taxonomic Annotation

Three annotation layers are applied to the contigs database:

- **NCBI COGs**: Clusters of Orthologous Groups for broad functional categorisation (`anvi-run-ncbi-cogs`)
- **HMM profiles**: Hidden Markov Model searches for bacterial and archaeal single-copy core genes, ribosomal RNAs, and other conserved marker gene sets (`anvi-run-hmms`)
- **SCG taxonomy**: Single-copy core gene taxonomy for estimating the taxonomic identity of the genome (`anvi-run-scg-taxonomy`)

### 4. Read Recruitment via Bowtie2

A Bowtie2 index is built from the reference genome. Paired-end reads from each metagenome are competitively mapped against the reference, producing SAM alignments that are subsequently converted to sorted, indexed BAM files using SAMtools. Intermediate SAM and unsorted BAM files are removed after processing to conserve disk space.

### 5. Anvi'o Profiling and Merging

Each sorted BAM file is profiled independently using `anvi-profile`, which computes per-nucleotide coverage, variability, and detection statistics. Individual profiles are then merged across all five samples with `anvi-merge` to produce a unified multi-sample profile database suitable for comparative analysis.

### 6. Interactive Visualisation

The merged profile can be explored interactively using `anvi-interactive`, enabling inspection of coverage patterns at the contig level, and, via `--gene-mode`, at the resolution of individual genes across all five metagenomes simultaneously.

---

## Prerequisites

| Dependency  | Version | Purpose                               |
|-------------|---------|---------------------------------------|
| Conda       | >= 4.x  | Environment and dependency management |
| Anvi'o      | 9       | Contigs database, profiling, merging  |
| Bowtie2     | >= 2.4  | Short-read alignment                  |
| SAMtools    | >= 1.9  | SAM/BAM conversion, sorting, indexing |
| Python      | 3.10    | Runtime for anvi'o                    |

Refer to `anvio_install.sh` for a complete installation recipe, including Conda environment creation, bioinformatics dependency resolution, and anvi'o database setup (NCBI COGs, SCG taxonomy, KEGG).

---

## Usage

```bash
# Clone the repository
git clone https://github.com/<your-username>/anvio_read_recruitment_analysis.git
cd anvio_read_recruitment_analysis

# Run the full pipeline
bash anvio_read_recruitment.sh
```

The script will download the data pack (~397 MB), build the contigs database, perform all read recruitment and profiling steps, and produce a merged profile ready for interactive visualisation.

To launch the interactive interface after the pipeline completes:

```bash
# Contig-level view
anvi-interactive -p metagenomic-read-recruitment-data-pack/merged-profiles/PROFILE.db \
    -c metagenomic-read-recruitment-data-pack/genome.db

# Gene-level view
anvi-interactive -p metagenomic-read-recruitment-data-pack/merged-profiles/PROFILE.db \
    -c metagenomic-read-recruitment-data-pack/genome.db \
    -C DEFAULT \
    -b EVERYTHING \
    --gene-mode
```

---

## Data Availability

All sequencing data and the reference genome are distributed as a single compressed archive from the Meren Lab:

```
https://cloud.uol.de/public.php/dav/files/B849axL35cBZzYD
```

This archive is automatically downloaded and extracted by the pipeline script. Individual files exceeding 100 MB, including raw FASTQ reads, SAM alignments, and BAM files, are excluded from this Git repository via `.gitignore`. The pipeline regenerates all intermediate and output files from the source data.

---

## Samples

| Sample     | Description                                    | Forward Reads       | Reverse Reads       |
|------------|------------------------------------------------|---------------------|---------------------|
| Alejandra  | Mock human gut metagenome from Alejandra        | alejandra-R1.fastq  | alejandra-R2.fastq  |
| Batuhan    | Mock human gut metagenome from Batuhan          | batuhan-R1.fastq    | batuhan-R2.fastq    |
| Jessika    | Mock human gut metagenome from Jessika          | jessika-R1.fastq    | jessika-R2.fastq    |
| Jonas      | Mock human gut metagenome from Jonas            | jonas-R1.fastq      | jonas-R2.fastq      |
| Magdalena  | Mock human gut metagenome from Magdalena        | magdalena-R1.fastq  | magdalena-R2.fastq  |

---

## References

- Eren, A.M. _et al._ (2021). Community-led, integrated, reproducible multi-omics with anvi'o. _Nature Microbiology_, 6, 3–6. https://doi.org/10.1038/s41564-020-00834-3
- Meren Lab. _A simple read recruitment exercise_. https://merenlab.org/tutorials/read-recruitment/

---

## License

This project is licensed under the terms of the MIT License. For details, please refer to the [LICENSE](LICENSE) file.

Copyright (c) 2026 Qasim Hussain. All rights reserved.
