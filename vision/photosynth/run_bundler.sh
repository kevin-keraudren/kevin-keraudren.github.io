#!/bin/bash
#
# RunBundler.sh
#   copyright 2008 Noah Snavely
#
# A script for preparing a set of image for use with the Bundler 
# structure-from-motion system.
#
# Usage: RunBundler.sh [image_dir]
#
# The image_dir argument is the directory containing the input images.
# If image_dir is omitted, the current directory is used.
#

# NOTE: I merged the Bundler scritp with the PMVS/CMVS ones to put the whole
# pipeline in one single script. Kevin Keraudren, 07/11/2010.

# Let's time the whole thing:
time {

IMAGE_DIR="."

if [ $# -eq 1 ]; then
    echo "Using directory '$1'"
    IMAGE_DIR=$1
fi

# Set this variable to your base install path (e.g., /home/foo/bundler)
BASE_PATH="/home/kevin/.liens/AGV_project/bundler-v0.4-source"

# Kevin
export LD_LIBRARY_PATH=/usr/local/lib:"/home/kevin/.liens/AGV_project/bundler-v0.4-source/lib":"/home/kevin/.liens/AGV_project/cvms_Win_Linux-fix1/program/main"

EXTRACT_FOCAL=$BASE_PATH/bin/extract_focal.pl
MATCHKEYS=$BASE_PATH/bin/KeyMatchFull
BUNDLER=$BASE_PATH/bin/bundler
TO_SIFT=$BASE_PATH/bin/ToSift.sh

# Rename ".JPG" to ".jpg"
for d in `ls -1 $IMAGE_DIR | egrep ".JPG$"`; do 
    mv $IMAGE_DIR/$d $IMAGE_DIR/`echo $d | sed 's/\.JPG/\.jpg/'`
done

# Create the list of images
find $IMAGE_DIR -maxdepth 1 | egrep ".jpg$" | sort > list_tmp.txt
$EXTRACT_FOCAL list_tmp.txt
cp prepare/list.txt .

# Run the ToSift script to generate a list of SIFT commands
echo "[- Extracting keypoints -]"
rm -f sift.txt
$TO_SIFT $IMAGE_DIR > sift.txt 

# Execute the SIFT commands
sh sift.txt

# Match images (can take a while)
echo "[- Matching keypoints (this can take a while) -]"
sed 's/\.jpg$/\.key/' list_tmp.txt > list_keys.txt
sleep 1
echo $MATCHKEYS list_keys.txt matches.init.txt
$MATCHKEYS list_keys.txt matches.init.txt

# Generate the options file for running bundler 
mkdir bundle
rm -f options.txt

echo "--match_table matches.init.txt" >> options.txt
echo "--output bundle.out" >> options.txt
echo "--output_all bundle_" >> options.txt
echo "--output_dir bundle" >> options.txt
echo "--variable_focal_length" >> options.txt
echo "--use_focal_estimate" >> options.txt
echo "--constrain_focal" >> options.txt
echo "--constrain_focal_weight 0.0001" >> options.txt
echo "--estimate_distortion" >> options.txt
echo "--run_bundle" >> options.txt

# Run Bundler!
echo "[- Running Bundler -]"
rm -f constraints.txt
rm -f pairwise_scores.txt
$BUNDLER list.txt --options_file options.txt > bundle/out

echo "Running Bundle2PMVS"
$BASE_PATH/bin/Bundle2PMVS list.txt bundle/bundle.out pmvs

##### Here comes the content of "pmvs/prep_pmvs.sh" #####

# Script for preparing images and calibration data 
#   for Yasutaka Furukawa's PMVS system

# Apply radial undistortion to the images
$BASE_PATH/bin/RadialUndistort list.txt bundle/bundle.out pmvs

# Create directory structure
mkdir -p pmvs/txt/
mkdir -p pmvs/visualize/
mkdir -p pmvs/models/

count=0
# Copy and rename files
for d in `ls pmvs/*.rd.jpg`; do 
    formated_count=`printf "%08d" $count`
    mv $d pmvs/visualize/$formated_count.jpg
    mv pmvs/$formated_count.txt pmvs/txt/
    ((count++))
done

echo "Running Bundle2Vis to generate vis.dat"
$BASE_PATH/bin/Bundle2Vis pmvs/bundle.rd.out pmvs/vis.dat

MVS_PATH="/home/kevin/.liens/AGV_project/cvms_Win_Linux-fix1/program/main"

echo "Running cmvs to generate ske.dat, vis.dat, centers-0000.ply and centers-all.ply"
$MVS_PATH/cmvs pmvs/

echo "Running genOption to generate option-0000 (and pmvs.sh)"
$MVS_PATH/genOption pmvs/ 

echo "Running pmvs2 to generate models/option-0000.ply, models/option-0000.patch and models/option-0000.pset"
$MVS_PATH/pmvs2 pmvs/ option-0000

echo "[- Done -]"

} # end of time
