#!/usr/bin/python
#! -*- encoding: utf-8 -*-

# This file is part of OpenMVG (Open Multiple View Geometry) C++ library.

# Python implementation of the bash script written by Romuald Perrot
# Created by @vins31
# Modified by Pierre Moulon
#
# this script is for easy use of OpenMVG
#
# usage : python openmvg.py image_dir output_dir
#
# image_dir is the input directory where images are located
# output_dir is where the project must be saved
#
# if output_dir is not present script will create it
#

# Indicate the openMVG binary directory
OPENMVG_SFM_BIN = './openMVG_Build/Linux-x86_64-Release'

# Indicate the openMVG camera sensor width directory
CAMERA_SENSOR_WIDTH_DIRECTORY = './openMVG/src/openMVG/exif/sensor_width_database'

import os
import subprocess
import sys
import time


class GlobalReconstructor(object):
    def __init__(self, input_dir, output_dir):
        self.input_dir = input_dir
        self.output_dir = output_dir
        self.matches_dir = os.path.join(self.output_dir, 'matches')
        self.mvs_dir = os.path.join(self.input_dir, '../openMVS')
        self.reconstruction_dir = os.path.join(self.output_dir, 'reconstruction_global')
        self.camera_file_params = os.path.join(CAMERA_SENSOR_WIDTH_DIRECTORY, 'sensor_width_camera_database.txt')
        # Create the ouput/matches folder if not present
        if not os.path.exists(self.output_dir):
          os.mkdir(self.output_dir)
        if not os.path.exists(self.matches_dir):
          os.mkdir(self.matches_dir)
        # Create the reconstruction if not present
        if not os.path.exists(self.reconstruction_dir):
            os.mkdir(self.reconstruction_dir)

    def __del__(self):
        pass

    def list_images(self):
        time_start = time.time()
        print ('[{}] 1. Intrinsics analysis'.format(time_start))
        pIntrisics = subprocess.Popen(
                [os.path.join(OPENMVG_SFM_BIN, 'openMVG_main_SfMInit_ImageListing'),
                    '-i', self.input_dir,
                    '-o', self.matches_dir,
                    '-d', self.camera_file_params
                    ])
        pIntrisics.wait()
        time_used = time.time() - time_start
        print('Finished in {:.0f}s'.format(time_used))

    def compute_features(self):
        time_start = time.time()
        print ('[{}] 2. Compute features'.format(time_start))
        pFeatures = subprocess.Popen(
                [os.path.join(OPENMVG_SFM_BIN, 'openMVG_main_ComputeFeatures'),
                    '-i', self.matches_dir + '/sfm_data.json',
                    '-o', self.matches_dir,
                    '-m', 'SIFT',
                    '-n', '4'
                    ])
        pFeatures.wait()
        time_used = time.time() - time_start
        print('Finished in {:.0f}s'.format(time_used))


    def compute_pairs(self):
        time_start = time.time()
        print ('[{}] 3. Compute matching pairs'.format(time_start))
        pPairs = subprocess.Popen(
                [os.path.join(OPENMVG_SFM_BIN, 'openMVG_main_PairGenerator'),
                    '-i', self.matches_dir + '/sfm_data.json',
                    '-o' , self.matches_dir + '/pairs.bin',
                    ])
        pPairs.wait()
        time_used = time.time() - time_start
        print('Finished in {:.0f}s'.format(time_used))


    def compute_matches(self):
        time_start = time.time()
        print ('[{}] 4. Compute matches'.format(time_start))
        pMatches = subprocess.Popen(
                [os.path.join(OPENMVG_SFM_BIN, 'openMVG_main_ComputeMatches'),
                   '-i', self.matches_dir + '/sfm_data.json',
                   '-p', self.matches_dir + '/pairs.bin',
                   '-o', self.matches_dir + '/matches.putative.bin',
                   ])
        pMatches.wait()
        time_used = time.time() - time_start
        print('Finished in {:.0f}s'.format(time_used))


    def filter_matches(self):
        time_start = time.time()
        print ('[{}] 5. Filter matches'.format(time_start))
        pFiltering = subprocess.Popen(
                [os.path.join(OPENMVG_SFM_BIN, 'openMVG_main_GeometricFilter'),
                    '-i', self.matches_dir + '/sfm_data.json',
                    '-m', self.matches_dir + '/matches.putative.bin' ,
                    '-g',
                    'e',
                    '-o', self.matches_dir + '/matches.e.bin',
                    ])
        pFiltering.wait()
        time_used = time.time() - time_start
        print('Finished in {:.0f}s'.format(time_used))


    def recon(self):
        time_start = time.time()
        print ('[{}] 6. Do Global reconstruction'.format(time_start))
        pRecons = subprocess.Popen(
                [os.path.join(OPENMVG_SFM_BIN, 'openMVG_main_SfM'),
                    '--sfm_engine', 'GLOBAL',
                    '--input_file', self.matches_dir + '/sfm_data.json',
                    '--match_file', self.matches_dir + '/matches.e.bin',
                    '--output_dir', self.reconstruction_dir
                    ])
        pRecons.wait()
        time_used = time.time() - time_start
        print('Finished in {:.0f}s'.format(time_used))


    def colorize(self):
        time_start = time.time()
        print ('[{}] 7. Colorize Structure'.format(time_start))
        pRecons = subprocess.Popen(
                [os.path.join(OPENMVG_SFM_BIN, 'openMVG_main_ComputeSfM_DataColor'),
                    '-i', self.reconstruction_dir + '/sfm_data.bin',
                    '-o', os.path.join(self.reconstruction_dir,'colorized.ply')
                    ])
        pRecons.wait()
        time_used = time.time() - time_start
        print('Finished in {:.0f}s'.format(time_used))


    def export_to_openmvs(self):
        time_start = time.time()
        print ('[{}] 8. Export to openMVS'.format(time_start))
        pRecons = subprocess.Popen(
                [os.path.join(OPENMVG_SFM_BIN, 'openMVG_main_openMVG2openMVS'),
                    '-i', self.reconstruction_dir + '/sfm_data.bin',
                    '-o', os.path.join(self.mvs_dir,'scene.mvs'),
                    '-d', self.mvs_dir
                    ])
        pRecons.wait()
        time_used = time.time() - time_start
        print('Finished in {:.0f}s'.format(time_used))


def main():
    if len(sys.argv) < 3:
        print ('Usage %s image_dir output_dir' % sys.argv[0])
        sys.exit(1)

    input_dir = sys.argv[1]
    output_dir = sys.argv[2]
    print ('Using input dir  : ', input_dir)
    print ('      output_dir : ', output_dir)
    recon = GlobalReconstructor(input_dir, output_dir)
    recon.list_images()
    recon.compute_features()
    recon.compute_pairs()
    recon.compute_matches()
    recon.filter_matches()
    recon.recon()
    recon.colorize()
    recon.export_to_openmvs()


if __name__ == '__main__':
    main()
