workdir=`pwd`
#Prepare and empty machine for building:
echo 'Install dependencies of OpenMVS...'
sudo apt-get update -qq && sudo apt-get install -qq
sudo apt-get -y install git cmake libpng-dev libjpeg-dev libtiff-dev libglu1-mesa-dev

#Eigen (Required)
echo '\tiBuild eigen from source and install...'
git clone https://gitlab.com/libeigen/eigen.git --branch 3.2
mkdir eigen_build
cd eigen_build && cmake . ../eigen && make && sudo make install

#Boost (Required)
echo '\tInstall boost...'
sudo apt-get -y install libboost-iostreams-dev libboost-program-options-dev libboost-system-dev libboost-serialization-dev

#OpenCV (Required)
echo '\tInstall libopencv-dev...'
sudo apt-get -y install libopencv-dev

#CGAL (Required)
echo '\tInstall libcgal-dev...'
sudo apt-get -y install libcgal-dev libcgal-qt5-dev

#VCGLib (Required)
cd $workdir
git clone https://github.com/cdcseacave/VCG.git vcglib

#Ceres (Optional)
echo '\tBuild ceres from source and install...'
sudo apt-get -y install libatlas-base-dev libsuitesparse-dev
cd $workdir
git clone https://ceres-solver.googlesource.com/ceres-solver ceres-solver
mkdir ceres_build
cd ceres_build && cmake . ../ceres-solver/ -DMINIGLOG=ON -DBUILD_TESTING=OFF -DBUILD_EXAMPLES=OFF && make -j2 && sudo make install

#GLFW3 (Optional)
echo '\tInstlal opengl related...'
sudo apt-get -y install freeglut3-dev libglew-dev libglfw3-dev

#OpenMVS
echo 'Build OpenMVS from source and install...'
git clone https://github.com/cdcseacave/openMVS.git openMVS
cd $workdir
mkdir openMVS_build
cd openMVS_build && cmake . ../openMVS -DCMAKE_BUILD_TYPE=Release -DVCG_ROOT="$workdir/vcglib" && make -j && sudo make install

#If you want to use OpenMVS as shared library, add to the CMake command:
# -DBUILD_SHARED_LIBS=ON
