#!/usr/bin/env bash

set -e

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

DIR_SFM=$DIR/openMVG_Build/software/SfM/

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
project_dir=$input_dir/openMVG
if [ ! -d $project_dir ]; then
    mkdir $project_dir
fi
echo "Images dir: $image_dir"
echo "Project dir: $project_dir"

log_file=$project_dir/recon-`date '+%m%d%H%M%S'`.log
touch $log_file
echo 'Log file: '$log_file

#echo 'Make sure the images are properly cropped before reconstruction'
#echo 'Press any key to continue'
#read -n 1 key

function sfm() {
    seconds_start=`date '+%s'`
    echo | tee -a $log_file
    echo "[`date '+%T'`] Extract exif ..." | tee -a $log_file
    python $DIR_SFM/SfM_SequentialPipeline.py $image_dir $project_dir &>> $log_file
}

function mvs() {
    # OpenMVS
    cur_dir=`pwd`
    openmvs_dir=$project_dir/undistorted/openmvs
    echo | tee -a $log_file
    echo "[`date '+%T'`] Densify point cloud ..." | tee -a $log_file
    # TODO compute number-views-fuse from photo numbers
    # TODO core dump
    #DensifyPointCloud -v 5 --number-views 0 --estimate-normals 1 scene.mvs
    # Set resolution-level to scale down images 5 times to avoid out of memory
    # resolution-level: scale down before densify, default 0
    #   resolution-level=0: about 70min for coin_0804
    # DensifyPointCloud --number-views 0 --estimate-normals 1 --resolution-level 5 $openmvs_dir/scene.mvs &>> $log_file
    DensifyPointCloud -v 5 --number-views 0 --estimate-normals 1 $openmvs_dir/scene.mvs &>> $log_file
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

    seconds_start=`date '+%s'`
    # TODO call Poisson surface restruction here. But result is not as good as the one in MeshLab.
    echo | tee -a $log_file
    echo "[`date '+%T'`] Reconstruct mesh ..." | tee -a $log_file
    # Only clean mesh, skip reconstruction
    # TODO invalid mesh for pumpkin
    # ReconstructMesh --mesh-file scene_dense_cleaned_mesh.ply scene_dense.mvs
    ReconstructMesh -v 5 $openmvs_dir/scene_dense.mvs &>> $log_file

    echo | tee -a $log_file
    echo "[`date '+%T'`] Refine mesh ..." | tee -a $log_file
    RefineMesh --resolution-level 5 $openmvs_dir/scene_dense_mesh.mvs &>> $log_file

    echo | tee -a $log_file
    echo "[`date '+%T'`] Texture mesh ..." | tee -a $log_file
    TextureMesh --resolution-level 5 --cost-smoothness-ratio 1 --patch-packing-heuristic 0 $openmvs_dir/scene_dense_mesh_refine.mvs &>> $log_file
    seconds_end=`date '+%s'`
    seconds_used_4=$((seconds_end-seconds_start))
    echo | tee -a $log_file
    echo "[`date '+%T'`] Textured mesh was generated successfully as scene_dense_mesh_refine_texture.ply!" | tee -a $log_file
    echo "Seconds used in total: " + $((seconds_used_1+seconds_used_2+seconds_used_3+seconds_used_4))s
    paplay /usr/share/sounds/ubuntu/stereo/system-ready.ogg
}

sfm
# mvs
