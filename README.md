# Opensim_BatchUQ
Matlab App for Processing C3D file data through Opensim.

Requires Matlab (2019 or higher) and Opensim (4.0 or higher).  Please ensure Matlab environment is setup to work with Opensim - https://simtk-confluence.stanford.edu:8443/display/OpenSim/Scripting+with+Matlab. 

Also requires the BTK toolbox to be installed in order to open C3D file - https://code.google.com/archive/p/b-tk/downloads

Designed to work with complete workflow, ranging from loading C3D data (custom processing scripts can be used for specialist tasks), undertaking scaling of model based on static trial, conducting inverse kinematics to fit motion to marker data, combining with force plate data to run inverse dynamics and running secondary analyses (muscle and body analyses currently supported). To run processes, a sample setup (XML) file needs to be provided. See example data. 

All processed data saved to a single MAT file with a data structure that can be explored with post-processing. 

Contributors: 
Patricio Pincheira Miranda
Luke Jessup
Yungsheng (Eric) Su

Special thanks to the Opensim development team.

![image](https://user-images.githubusercontent.com/8924887/162679601-522d7f17-d1ee-40fb-bc70-e481162517d3.png)
