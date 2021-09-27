#!/usr/bin/env bash

set -e

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

DIR_SFM=$DIR/openMVG_Build/software/SfM/
DIR_SFM_BIN=$DIR/openMVG_Build/Linux-x86_64-Release/
DIR_MVG_SRC=$DIR/openMVG/src/openMVG/

if [ $# -lt 1 ]; then
    echo 'Usage: ./recon.sh {project_folder}'
    exit
fi

interactive=0
input_dir=""

if [ $# -gt 1 ] && [ $1 == "-i" ]; then
    interactive=1
    input_dir=$2
else
    input_dir=$1
fi
image_dir=$input_dir/images
mvg_dir=$input_dir/openMVG
mvs_dir=$input_dir/openMVS
if [ ! -d $mvg_dir ]; then
    mkdir $mvg_dir
fi
echo "Images dir: $image_dir"
echo "MVG project dir: $mvg_dir"
echo "MVS project dir: $mvs_dir"

log_file=$input_dir/recon-`date '+%m%d%H%M%S'`.log
touch $log_file
echo 'Log file: '$log_file

#echo 'Make sure the images are properly cropped before reconstruction'
#echo 'Press any key to continue'
#read -n 1 key

function sfm() {
    seconds_start=`date '+%s'`
    echo | tee -a $log_file
    # python $DIR_SFM/SfM_SequentialPipeline.py $image_dir $mvg_dir &>> $log_file
    # image listing
    echo "[`date '+%T'`] Image listing ..." | tee -a $log_file
    $DIR_SFM_BIN/openMVG_main_SfMInit_ImageListing \
        -i $image_dir \
        -d $DIR_MVG_SRC/exif/sensor_width_database/sensor_width_camera_database.txt \
        -o $mvg_dir/matches \
        >> $log_file
    # compute features
    echo "[`date '+%T'`] Compute features..." | tee -a $log_file
    $DIR_SFM_BIN/openMVG_main_ComputeFeatures \
        -p HIGH \
        -i $mvg_dir/matches/sfm_data.json \
        -o $mvg_dir/matches \
        >> $log_file
    # compute matches
    echo "[`date '+%T'`] Compute matches..." | tee -a $log_file
    $DIR_SFM_BIN/openMVG_main_ComputeMatches \
        -r .8 \
        -i $mvg_dir/matches/sfm_data.json \
        -o $mvg_dir/matches \
        >> $log_file
    # incremental sfm
    echo "[`date '+%T'`] Incremental SFM..." | tee -a $log_file
    $DIR_SFM_BIN/openMVG_main_IncrementalSfM \
        -i $mvg_dir/matches/sfm_data.json \
        -m $mvg_dir/matches \
        -o $mvg_dir/out_incremental_reconstruction \
        >> $log_file
    echo "[`date '+%T'`] SFM from known poses..." | tee -a $log_file
    $DIR_SFM_BIN/openMVG_main_ComputeStructureFromKnownPoses \
        -i $mvg_dir/out_incremental_reconstruction/sfm_data.bin \
        -m $mvg_dir/matches \
        -f $mvg_dir/matches/matches.f.bin \
        -o $mvg_dir/out_incremental_reconstruction/robust.bin \
        >> $log_file
    echo "[`date '+%T'`] Compute SFM data color..." | tee -a $log_file
    $DIR_SFM_BIN/openMVG_main_ComputeSfM_DataColor \
        -i $mvg_dir/out_incremental_reconstruction/robust.bin \
        -o $mvg_dir/out_incremental_reconstruction/robust_colorized.ply \
        >> $log_file
    echo "[`date '+%T'`] To openMVS..." | tee -a $log_file
    $DIR_SFM_BIN/openMVG_main_openMVG2openMVS \
        -i $mvg_dir/out_incremental_reconstruction/sfm_data.bin \
        -o $mvs_dir/scene.mvs \
        -d $mvs_dir \
        >> $log_file
}

function densify() {
    echo | tee -a $log_file
    echo "[`date '+%T'`] Densify point cloud ..." | tee -a $log_file
    # TODO compute number-views-fuse from photo numbers
    # TODO core dump
    #DensifyPointCloud -v 5 --number-views 0 --estimate-normals 1 scene.mvs
    # Set resolution-level to scale down images 5 times to avoid out of memory
    # resolution-level: scale down before densify, default 0
    #   resolution-level=0: about 70min for coin_0804
    DensifyPointCloud \
        --number-views 0 \
        --estimate-normals 1 \
        --resolution-level 5 \
        $mvs_dir/scene.mvs \
        >> $log_file
    # DensifyPointCloud -v 5 --number-views 0 --estimate-normals 1 $mvs_dir/scene.mvs &>> $log_file
    seconds_end=`date '+%s'`
    seconds_used_3=$((seconds_end-seconds_start))
    if [ $interactive -gt 0 ]; then
        #echo 'Please manually clean the point cloud and restruct surface using MeshLab.'
        #echo 'Mesh file MUST be stored as scene_dense_cleaned_mesh.ply'
        # Always pause here
        echo 'Please manually check scene_dense.ply'
        echo 'Press any key to continue...'
        read -n 1 key
    fi
}

reconstruct_mesh() {
    seconds_start=`date '+%s'`
    # TODO call Poisson surface restruction here. But result is not as good as the one in MeshLab.
    echo | tee -a $log_file
    echo "[`date '+%T'`] Reconstruct mesh ..." | tee -a $log_file
    # Only clean mesh, skip reconstruction
    # TODO invalid mesh for pumpkin
    # ReconstructMesh --mesh-file scene_dense_cleaned_mesh.ply scene_dense.mvs
    ReconstructMesh \
        -v 5 \
        --remove-spurious 50 \
        $mvs_dir/scene_dense.mvs \
        >> $log_file
}

function refine_mesh() {
    echo | tee -a $log_file
    echo "[`date '+%T'`] Refine mesh ..." | tee -a $log_file
    RefineMesh \
        --resolution-level 5 \
        --decimate 0.7 \
        $mvs_dir/scene_dense_mesh.mvs \
        >> $log_file
}

function reconstruct_mesh_again() {
    echo 'Please manually fix scene_dense_mesh_refine.ply, and saved as scene_dense_mesh_refine_fixed.ply'
    echo 'Press any key to continue...'
    read -n 1 key
    # reconstruct again
    echo | tee -a $log_file
    echo "[`date '+%T'`] Reconstruct mesh again ..." | tee -a $log_file
    ReconstructMesh \
        -v 5 \
        --decimate 0.5 \
        --remove-spurious 0 \
        --remove-spikes 0 \
        --smooth 0 \
        --mesh-file $mvs_dir/scene_dense_mesh_refine_fixed.ply \
        $mvs_dir/scene_dense_mesh_refine.mvs \
        >> $log_file
}

function texture_mesh() {
    echo | tee -a $log_file
    echo "[`date '+%T'`] Texture mesh ..." | tee -a $log_file
    TextureMesh \
        --resolution-level 5 \
        --cost-smoothness-ratio 1 \
        --patch-packing-heuristic 0 \
        --empty-color 985864 \
        --export-type obj \
        -o $mvs_dir/scene.obj \
        $mvs_dir/scene_dense_mesh_refine_mesh.mvs \
        >> $log_file
    seconds_end=`date '+%s'`
    seconds_used_4=$((seconds_end-seconds_start))
    echo | tee -a $log_file
    echo "[`date '+%T'`] Textured mesh was generated successfully as $mvs_dir/scene.obj" | tee -a $log_file
}

function mvs() {
    # OpenMVS
    densify
    reconstruct_mesh
    reconstruct_mesh_again
    texture_mesh

    # echo "Seconds used in total: " + $((seconds_used_1+seconds_used_2+seconds_used_3+seconds_used_4))s
    paplay /usr/share/sounds/ubuntu/stereo/system-ready.ogg
}

sfm
mvs
