# Metagenomes — Paired-End Sequencing Reads

This directory contains paired-end FASTQ files from five mock human gut metagenomes. These files are excluded from version control due to their size (each exceeding 100 MB).

---

## Samples

| Sample     | Forward Reads          | Reverse Reads          | Approx. Size |
|------------|------------------------|------------------------|--------------|
| Alejandra  | `alejandra-R1.fastq`   | `alejandra-R2.fastq`   | ~343 MB each |
| Batuhan    | `batuhan-R1.fastq`     | `batuhan-R2.fastq`     | ~166 MB each |
| Jessika    | `jessika-R1.fastq`     | `jessika-R2.fastq`     | ~172 MB each |
| Jonas      | `jonas-R1.fastq`       | `jonas-R2.fastq`       | ~207 MB each |
| Magdalena  | `magdalena-R1.fastq`   | `magdalena-R2.fastq`   | ~298 MB each |

---

## Data Source

These reads are distributed as part of the Meren Lab's metagenomic read recruitment data pack and are automatically downloaded by `anvio_read_recruitment.sh`. The mock metagenomes simulate human gut samples — each representing a different individual — and are designed to illustrate the fundamentals of competitive read recruitment and downstream coverage analysis. See the root `README.md` for the download URL and full pipeline documentation.
