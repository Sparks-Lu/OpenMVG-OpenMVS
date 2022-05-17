workdir=`pwd`

#Prepare and empty machine for building:
echo 'Install dependencies of OpenMVG...'
sudo apt-get install libpng-dev libjpeg-dev libtiff-dev libxxf86vm1 libxxf86vm-dev libxi-dev libxrandr-dev graphviz cmake
main_path=`pwd`

#OpenMVS
echo 'Build OpenMVG from source and install...'
git clone --recursive https://github.com/openMVG/openMVG.git
ls openMVG_Build || mkdir openMVG_Build
cd openMVG_Build && cmake . ../openMVG/src -DCMAKE_BUILD_TYPE=Release && make -j4 && sudo make install
