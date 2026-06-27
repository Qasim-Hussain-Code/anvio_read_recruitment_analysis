#!/bin/bash
# final_data_pipeline.sh
# Downloads FASTQs from ENA, creates manifest/metadata, imports to QIIME 2

set -e

WORK_DIR="/media/codanics/bioinformatics/04_cocoa_fermentation_metagenomics"
FASTQ_DIR="$WORK_DIR/fastq"
CACHE_DIR="$WORK_DIR/qiime2-cache"


mkdir -p $FASTQ_DIR

# download SRR IDs for cocoa fermentation dataset
wget -O ids.tsv \
    https://raw.githubusercontent.com/bokulich-lab/moshpit-docs/main/docs/data/cocoa/ids.tsv

SRR_IDS=($(tail -n +2 ids.tsv | cut -f1))

# ============================================
# STEP 1: Download FASTQs (only _1 and _2)
# ============================================
echo "=== Starting downloads at $(date) ==="
START_TIME=$(date +%s)

for srr in "${SRR_IDS[@]}"; do
    echo ""
    echo ">>> Processing $srr ..."
    
    FTP_LINKS=$(curl -s --max-time 10 "https://www.ebi.ac.uk/ena/portal/api/filereport?accession=$srr&result=read_run&fields=fastq_ftp" | tail -1)
    
    if [ -n "$FTP_LINKS" ] && [ "$FTP_LINKS" != "fastq_ftp" ]; then
        for link in $(echo $FTP_LINKS | tr ';' ' '); do
            filename=$(basename $link)
            
            # Skip singleton files (no _1 or _2 suffix)
            if [[ "$filename" =~ ^${srr}\.fastq\.gz$ ]]; then
                echo "  ⊘ Skipping singleton: $filename"
                continue
            fi
            
            filepath="$FASTQ_DIR/$filename"
            
            if [ -f "$filepath" ]; then
                echo "  ✓ $filename already exists, skipping"
                continue
            fi
            
            echo "  ↓ Downloading $filename ..."
            curl -C - -o "$filepath.tmp" "ftp://$link" && mv "$filepath.tmp" "$filepath"
            echo "  ✓ $filename done"
        done
    else
        echo "  ⚠ No ENA link for $srr"
    fi
done

END_TIME=$(date +%s)
echo ""
echo "=== Downloads finished in $((END_TIME - START_TIME))s ==="

# ============================================
# STEP 2: Verify and clean up
# ============================================
echo ""
echo "=== Verifying downloads ==="
# Remove any accidental singleton files
find $FASTQ_DIR -name "SRR*.fastq.gz" ! -name "*_*" -delete
ls -lh $FASTQ_DIR/
echo ""
echo "Total FASTQ size:"
du -sh $FASTQ_DIR/

# ============================================
# STEP 3: Create QIIME 2 manifest
# ============================================
echo ""
echo "=== Creating manifest ==="
cat > $WORK_DIR/manifest.tsv << 'EOF'
sample-id	forward-absolute-filepath	reverse-absolute-filepath
EOF

for srr in "${SRR_IDS[@]}"; do
    fwd=$(find $FASTQ_DIR -name "${srr}_1.fastq.gz" | head -1)
    rev=$(find $FASTQ_DIR -name "${srr}_2.fastq.gz" | head -1)
    
    if [ -n "$fwd" ] && [ -n "$rev" ]; then
        echo -e "$srr\t$(realpath $fwd)\t$(realpath $rev)" >> $WORK_DIR/manifest.tsv
        echo "  ✓ $srr: paired-end"
    else
        echo "  ✗ $srr: missing files"
    fi
done

echo ""
echo "=== Manifest preview ==="
head -5 $WORK_DIR/manifest.tsv
echo "..."
tail -3 $WORK_DIR/manifest.tsv

# ============================================
# STEP 4: Download metadata
# ============================================
echo ""
echo "=== Downloading metadata ==="
wget -q -O $WORK_DIR/metadata.tsv \
    https://raw.githubusercontent.com/bokulich-lab/moshpit-docs/main/docs/data/cocoa/metadata.tsv
echo "  ✓ Metadata downloaded"

# change first column name of metadata to match manifest in place of id
sed -i '1s/^id/sample-id/' $WORK_DIR/metadata.tsv

# ============================================
# STEP 5: Import to QIIME 2
# ============================================
echo ""
echo "=== Importing to QIIME 2 ==="

eval "$(conda shell.bash hook)"
conda activate rachis-moshpit-2026.4


# Before running import, set temp directory
TMPDIR=/media/codanics/bioinformatics/04_cocoa_fermentation_metagenomics/tmp
mkdir -p $TMPDIR 
export TMPDIR=$TMPDIR

echo "Using temp directory: $TMPDIR"
df -h $TMPDIR

# ============================================
# STEP 5.1: Create subset metadata
# ============================================
echo "=== Creating subset metadata ==="
awk -F'\t' 'NR==1 || ($2 == "0" || $2 == "96" || $2 == "120")' \
    "$WORK_DIR/metadata.tsv" > "$WORK_DIR/metadata_subset.tsv"

echo "Subset samples:"
tail -n +2 "$WORK_DIR/metadata_subset.tsv" | wc -l
cat "$WORK_DIR/metadata_subset.tsv"

# ============================================
# STEP 5.2: Create subset manifest
# ============================================
echo ""
echo "=== Creating subset manifest ==="

# Extract sample IDs from metadata subset
cut -f1 "$WORK_DIR/metadata_subset.tsv" | tail -n +2 > /tmp/subset_ids.txt

# Create manifest with correct header and matching rows
head -1 "$WORK_DIR/manifest.tsv" > "$WORK_DIR/manifest_selected.tsv"
grep -Ff /tmp/subset_ids.txt "$WORK_DIR/manifest.tsv" >> "$WORK_DIR/manifest_selected.tsv"

echo "Manifest selected:"
cat "$WORK_DIR/manifest_selected.tsv"

# Import paired-end sequences with quality scores
qiime tools import \
    --type 'SampleData[PairedEndSequencesWithQuality]' \
    --input-path $WORK_DIR/manifest_selected.tsv \
    --output-path $WORK_DIR/reads_paired.qza \
    --input-format PairedEndFastqManifestPhred33V2 
# Clean up temp
rm -rf $TMPDIR/*


# ============================================
# STEP 6: Create cache and import artifact
# ============================================
echo ""
echo "=== Creating cache and importing artifact ==="

# Remove old cache if exists to avoid errors
rm -rf $CACHE_DIR

# Create fresh cache
mosh tools cache-create --cache $CACHE_DIR
echo "  ✓ Cache created: $CACHE_DIR"

# Import artifact into cache
mosh tools cache-import \
    --type 'SampleData[PairedEndSequencesWithQuality]' \
    --input-path $WORK_DIR/reads_paired.qza \
    --cache $CACHE_DIR \
    --key reads_paired
echo "  ✓ Artifact imported to cache as: reads_paired"

# Import metadata into cache
mosh tools cache-import \
    --type 'SRAMetadata' \
    --input-path $WORK_DIR/metadata.tsv \
    --cache $CACHE_DIR \
    --key metadata
echo "  ✓ Metadata imported to cache as: metadata"

echo ""
echo "=== Pipeline complete at $(date) ==="
echo "FASTQ files:  $FASTQ_DIR/"
echo "Manifest:     $WORK_DIR/manifest.tsv"
echo "Metadata:     $WORK_DIR/metadata.tsv"
echo "Artifact:     $WORK_DIR/reads_paired.qza"
echo "Cache:        $CACHE_DIR/"
echo ""
echo "Cache contents:"
mosh tools cache-status --cache $CACHE_DIR

