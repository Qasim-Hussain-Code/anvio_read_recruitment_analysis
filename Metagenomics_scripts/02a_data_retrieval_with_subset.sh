#!/bin/bash

set -e

WORK_DIR="/home/qasim/anvio_cocoa_fermentation_analysis"
FASTQ_DIR="$WORK_DIR/fastq"
mkdir -p $FASTQ_DIR

# download SRR IDs for cocoa fermentation dataset
wget -O ids.tsv \
    https://raw.githubusercontent.com/bokulich-lab/moshpit-docs/main/docs/data/cocoa/ids.tsv

SRR_IDS=($(tail -n +2 ids.tsv | cut -f1))


# ============================================
# STEP 2: Download metadata
# ============================================
echo ""
echo "=== Downloading metadata ==="
wget -q -O metadata.tsv \
    https://raw.githubusercontent.com/bokulich-lab/moshpit-docs/main/docs/data/cocoa/metadata.tsv
echo "  ✓ Metadata downloaded"

# change first column name of metadata to match manifest in place of id
sed -i '1s/^id/sample-id/' metadata.tsv

# ============================================
# STEP 5.1: Create subset metadata
# ============================================
echo "=== Creating subset metadata ==="
awk -F'\t' 'NR==1 || ($2 == "24" || $2 == "72" || $2 == "144")' \
    "$WORK_DIR/metadata.tsv" > "$WORK_DIR/metadata_subset.tsv"

echo "Subset samples:"
tail -n +2 "$WORK_DIR/metadata_subset.tsv" | wc -l
cat "$WORK_DIR/metadata_subset.tsv"

# create subset of SRR IDs based on the subset metadata
SUBSET_SRR_IDS=($(tail -n +2 "$WORK_DIR/metadata_subset.tsv" | cut -f1))

# view the subset of SRR IDs
echo ""
echo "Subset SRR IDs:"
for srr in "${SUBSET_SRR_IDS[@]}"; do
    echo "  - $srr"
done

# ============================================
# STEP 3: Download FASTQs (only _1 and _2)
# ============================================
echo "=== Starting downloads at $(date) ==="
START_TIME=$(date +%s)

for srr in "${SUBSET_SRR_IDS[@]}"; do
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

