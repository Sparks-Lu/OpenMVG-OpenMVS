#!/usr/bin/env bash

function extract_exif()
{
    # image listing
    echo "[`date '+%T'`] Image listing ..." | tee -a $log_file
    local seconds_start=`date '+%s'`
    $DIR_SFM_BIN/openMVG_main_SfMInit_ImageListing \
        -i $image_dir \
        -d $DIR_MVG_SRC/exif/sensor_width_database/sensor_width_camera_database.txt \
        -o $mvg_dir/matches \
        >> $log_file
    local seconds_end=`date '+%s'`
    local seconds_used=$((seconds_end-seconds_start))
    echo "Finished in $((seconds_used))s." | tee -a $log_file
}

function compute_features()
{
    # compute features
    echo "[`date '+%T'`] Compute features..." | tee -a $log_file
    local seconds_start=`date '+%s'`
    # -p: describer preset
    # -m: describer method, default SIFT, optional AKAZE_FLOAT, AKAZE_MLDB
    # -n: number of parallel computations
    $DIR_SFM_BIN/openMVG_main_ComputeFeatures \
        -p HIGH \
        -m SIFT \
        -i $mvg_dir/matches/sfm_data.json \
        -o $mvg_dir/matches \
        -n 4
        >> $log_file
    local seconds_end=`date '+%s'`
    local seconds_used=$((seconds_end-seconds_start))
    echo "Finished in $((seconds_used))s." | tee -a $log_file
}

function compute_matches()
{
    # compute matches
    echo "[`date '+%T'`] Compute matches..." | tee -a $log_file
    local seconds_start=`date '+%s'`
    # -r: nearest neighbor distance ratio, default 0.8, 0.6 for less false positive
    # -v: video mode matching with of an overlap with next X images
    # TODO command options to configure whether or not video mode
    # -v 6 \
    $DIR_SFM_BIN/openMVG_main_ComputeMatches \
        -r .8 \
        -i $mvg_dir/matches/sfm_data.json \
        -o $mvg_dir/matches \
        >> $log_file
    local seconds_end=`date '+%s'`
    local seconds_used=$((seconds_end-seconds_start))
    echo "Finished in $((seconds_used))s." | tee -a $log_file
}

function sfm_incremental()
{
    # incremental sfm
    echo "[`date '+%T'`] Incremental SFM..." | tee -a $log_file
    local seconds_start=`date '+%s'`
    $DIR_SFM_BIN/openMVG_main_IncrementalSfM \
        -i $mvg_dir/matches/sfm_data.json \
        -m $mvg_dir/matches \
        -o $mvg_dir/reconstruction \
        >> $log_file
    local seconds_end=`date '+%s'`
    local seconds_used=$((seconds_end-seconds_start))
    echo "Finished in $((seconds_used))s." | tee -a $log_file
}

function sfm_global()
{
    echo "[`date '+%T'`] Global SFM..." | tee -a $log_file
    local seconds_start=`date '+%s'`
    $DIR_SFM_BIN/openMVG_main_GlobalSfM \
        -i $mvg_dir/matches/sfm_data.json \
        -m $mvg_dir/matches \
        -o $mvg_dir/reconstruction \
        >> $log_file
    local seconds_end=`date '+%s'`
    local seconds_used=$((seconds_end-seconds_start))
    echo "Finished in $((seconds_used))s." | tee -a $log_file
}

function compute_datacolor()
{
    echo "[`date '+%T'`] Compute SFM data color..." | tee -a $log_file
    local seconds_start=`date '+%s'`
    $DIR_SFM_BIN/openMVG_main_ComputeSfM_DataColor \
        -i $mvg_dir/reconstruction/robust.bin \
        -o $mvg_dir/reconstruction/robust_colorized.ply \
        >> $log_file
    local seconds_end=`date '+%s'`
    local seconds_used=$((seconds_end-seconds_start))
    echo "Finished in $((seconds_used))s." | tee -a $log_file
}

function export_to_mvs()
{
    echo "[`date '+%T'`] To openMVS..." | tee -a $log_file
    local seconds_start=`date '+%s'`
    $DIR_SFM_BIN/openMVG_main_openMVG2openMVS \
        -i $mvg_dir/reconstruction/sfm_data.bin \
        -o $mvs_dir/scene.mvs \
        -d $mvs_dir \
        >> $log_file
    local seconds_end=`date '+%s'`
    local seconds_used=$((seconds_end-seconds_start))
    echo "Finished in $((seconds_used))s." | tee -a $log_file
}

function sfm_known_poses()
{
    echo "[`date '+%T'`] SFM from known poses..." | tee -a $log_file
    local seconds_start=`date '+%s'`
    $DIR_SFM_BIN/openMVG_main_ComputeStructureFromKnownPoses \
        -i $mvg_dir/reconstruction/sfm_data.bin \
        -m $mvg_dir/matches \
        -f $mvg_dir/matches/matches.f.bin \
        -o $mvg_dir/reconstruction/robust.bin \
        >> $log_file
    local seconds_end=`date '+%s'`
    local seconds_used=$((seconds_end-seconds_start))
    echo "Finished in $((seconds_used))s." | tee -a $log_file
}

function sfm() {
    local seconds_start=`date '+%s'`
    echo | tee -a $log_file
    # python $DIR_SFM/SfM_SequentialPipeline.py $image_dir $mvg_dir &>> $log_file
    extract_exif
    # time-consuming
    compute_features
    compute_matches
    sfm_incremental
    # sfm_global
    sfm_known_poses
    compute_datacolor
    export_to_mvs
    local seconds_end=`date '+%s'`
    local seconds_used=$((seconds_end-seconds_start))
    echo "Seconds used in sfm total: $((seconds_used))s"
}

function densify() {
    echo | tee -a $log_file
    echo "[`date '+%T'`] Densify point cloud ..." | tee -a $log_file
    local seconds_start=`date '+%s'`
    # TODO compute number-views-fuse from photo numbers
    # TODO core dump
    #DensifyPointCloud -v 5 --number-views 0 --estimate-normals 1 scene.mvs
    # Set resolution-level to scale down images 5 times to avoid out of memory
    # resolution-level: scale down before densify, default 0
    # 8G RAM supports max resolution level 3
    #   resolution-level=0: about 70min for coin_0804
    # --resolution-level 5 \
    DensifyPointCloud \
        -w $mvs_dir \
        --resolution-level 3 \
        --number-views 0 \
        --estimate-normals 1 \
        $mvs_dir/scene.mvs \
        >> $log_file
    # DensifyPointCloud -v 5 --number-views 0 --estimate-normals 1 $mvs_dir/scene.mvs &>> $log_file
    local seconds_end=`date '+%s'`
    local seconds_used=$((seconds_end-seconds_start))
    echo "Finished in $((seconds_used))s." | tee -a $log_file
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
    # Memory-heavy
    local seconds_start=`date '+%s'`
    # TODO call Poisson surface restruction here. But result is not as good as the one in MeshLab.
    echo | tee -a $log_file
    echo "[`date '+%T'`] Reconstruct mesh ..." | tee -a $log_file
    # Only clean mesh, skip reconstruction
    # TODO invalid mesh for pumpkin
    # ReconstructMesh --mesh-file scene_dense_cleaned_mesh.ply scene_dense.mvs
    ReconstructMesh \
        -w $mvs_dir \
        -v 5 \
        --remove-spurious 50 \
        --max-threads 2 \
        $mvs_dir/scene_dense.mvs \
        >> $log_file
    local seconds_end=`date '+%s'`
    local seconds_used=$((seconds_end-seconds_start))
    echo "Finished in $((seconds_used))s." | tee -a $log_file
}

function refine_mesh() {
    # CPU-heavy
    local seconds_start=`date '+%s'`
    echo | tee -a $log_file
    echo "[`date '+%T'`] Refine mesh ..." | tee -a $log_file
    # 8G RAM supports max resolution level 3
    # --resolution-level 5 \
    RefineMesh \
        -w $mvs_dir \
        --resolution-level 3 \
        --decimate 0.7 \
        $mvs_dir/scene_dense_mesh.mvs \
        >> $log_file
    local seconds_end=`date '+%s'`
    local seconds_used=$((seconds_end-seconds_start))
    echo "Finished in $((seconds_used))s." | tee -a $log_file
}

function reconstruct_mesh_again() {
    echo 'Please manually fix scene_dense_mesh_refine.ply, and saved as scene_dense_mesh_refine_fixed.ply'
    echo 'Press any key to continue...'
    read -n 1 key
    # reconstruct again
    echo | tee -a $log_file
    echo "[`date '+%T'`] Reconstruct mesh again ..." | tee -a $log_file
    local seconds_start=`date '+%s'`
    ReconstructMesh \
        -w $mvs_dir \
        -v 5 \
        --decimate 0.5 \
        --remove-spurious 0 \
        --remove-spikes 0 \
        --smooth 0 \
        --mesh-file $mvs_dir/scene_dense_mesh_refine_fixed.ply \
        $mvs_dir/scene_dense_mesh_refine.mvs \
        >> $log_file
    local seconds_end=`date '+%s'`
    local seconds_used=$((seconds_end-seconds_start))
    echo "Finished in $((seconds_used))s." | tee -a $log_file
}

function texture_mesh() {
    # CPU-heavy
    echo | tee -a $log_file
    echo "[`date '+%T'`] Texture mesh ..." | tee -a $log_file
    local seconds_start=`date '+%s'`
    # deciding where to place a new patch, 0-best fit, 3-good speed, 100-best speed
    # --patch-packing-heuristic 0 \
    # --resolution-level 5 \
    # 8G RAM supports max resolution level 3
    model_file="$mvs_dir/scene.glb"
    TextureMesh \
        -w $mvs_dir \
        --resolution-level 3 \
        --cost-smoothness-ratio 1 \
        --patch-packing-heuristic 3 \
        --empty-color 985864 \
        --export-type glb \
        -o $model_file \
        $mvs_dir/scene_dense_mesh_refine_mesh.mvs \
        >> $log_file
    local seconds_end=`date '+%s'`
    local seconds_used=$((seconds_end-seconds_start))
    echo | tee -a $log_file
    echo "[`date '+%T'`] Generated as $model_file in $((seconds_used))s" | tee -a $log_file
}

function mvs() {
    # OpenMVS
    local seconds_start=`date '+%s'`

    # time-consuming
    densify
    reconstruct_mesh
    refine_mesh
    reconstruct_mesh_again
    texture_mesh

    local seconds_end=`date '+%s'`
    local seconds_used=$((seconds_end-seconds_start))
    echo "[`date '+%T'`] Finished mvs in $((seconds_used))s." | tee -a $log_file
    paplay /usr/share/sounds/ubuntu/stereo/system-ready.ogg
}


function recon() {
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
    sfm
    mvs
}

recon $@
