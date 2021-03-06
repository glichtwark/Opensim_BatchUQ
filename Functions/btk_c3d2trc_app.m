function [data] = btk_c3d2trc_app(varargin)
% function btk_c3d2trc(file) OR
% function btk_c3d2trc(data)
%
% Function to convert data from a C3D file into the TRC and MOT file
% formats for OpenSim
%
% INPUT -   file - the C3D file path that you wish to load (leave blank to
%               choose from a dialog box) OR
%           data - structure containing fields from from previously loaded
%               C3D file using btk_loadc3d_app.m
%
% OUTPUT -  data - structure containing the relevant data from the c3dfile
%                  Creates the TRC file and _grf.MOT file for OpenSim
%
% example - data = btk_c3dtrc('filein.c3d','off');
%           data = btk_c3dtrc(data,'on');
%
% Written by Glen Lichtwark (University of Queensland)
% Updated September 2012

order = [2 3 1];
%% load data
if nargin > 0
    if ~isstruct(varargin{1})
    % load C3d file
        file = varargin{1};
        if isempty(fileparts(file))
            pname = cd;
            if ispc
                pname = [pname '\'];
            else pname = [pname '/'];
            end
            fname = file;
        else [pname, name, ext] = fileparts(file);
            fname = [name ext];
        end
        % load the c3dfile
        [data] = btk_loadc3d_app([pname, fname], 10);
        
    else
        data = varargin{1};
        if ~isfield(data,'marker_data') 
            error('Please ensure that the following field is included in structure - marker_data. Please use btk_loadc3d_app for correct outputs');
        end
        if isfield(data,'marker_data')
            [pname, name, ext] = fileparts(data.marker_data.Filename);
            if ispc
                pname = [pname '\'];
            else pname = [pname '/'];
            end
            fname = [name ext];
        else fname = data.marker_data.Filename;
        end
        
    end

else
    [fname, pname] = uigetfile('*.c3d', 'Select C3D file');
    % load the c3dfile
    [data] = btk_loadc3d_app([pname, fname], 10);
end

%%
% if the mass, height and name aren't present then presribe - it is
% preferrable to have these defined in the data structure before running 
% this function - btk_loadc3d should try and do this for vicon data
if ~isfield(data,'Mass')
    data.Mass = 75;
end

if ~isfield(data,'Height')
    data.Height = 1750;
end

if ~isfield(data,'Name')
    data.Name = 'NoName';
end

%% define the start and end frame for analysis as first and last frame unless 
% this has already been done to change the analysed frames
if ~isfield(data,'Start_Frame')
    data.Start_Frame = 1;
    data.End_Frame = data.marker_data.Info.NumFrames;
end

%%
% define some parameters 
nrows = data.End_Frame-data.Start_Frame+1;
nmarkers = length(fieldnames(data.marker_data.Markers));

nframe = 1:nrows;


%%
% we need to reorder the lab coordinate system to match that of the OpenSim
% system --> SKIP THIS STEP IF LAB COORDINATE SYSTEM IS SAME AS MODEL
% SYSTEM
markers = fieldnames(data.marker_data.Markers); % get markers names

if strcmp(data.marker_data.Info.units.ALLMARKERS,'mm')
    p_sc = 1000;
    data.marker_data.Info.units.ALLMARKERS = 'm';
else p_sc = 1;
end

% go through each marker field and re-order from X Y Z to Y Z X 
% then reflect axis by making Y and X negative
for i = 1:nmarkers
   data.marker_data.Markers.(markers{i}) = data.marker_data.Markers.(markers{i})/p_sc;
   data.marker_data.Markers.(markers{i}) = data.marker_data.Markers.(markers{i})(:,order);
   data.marker_data.Markers.(markers{i})(:,1) = data.marker_data.Markers.(markers{i})(:,1)*-1;
   data.marker_data.Markers.(markers{i})(:,3) = data.marker_data.Markers.(markers{i})(:,3)*-1;
end

%%
% now we need to make the headers for the column headings for the TRC file
% which are made up of the marker names and the XYZ for each marker

% first initialise the header with a column for the Frame # and the Time
% also initialise the format for the columns of data to be written to file
dataheader1 = 'Frame#\tTime\t';
dataheader2 = '\t\t';
format_text = '%i\t%2.4f\t';
% initialise the matrix that contains the data as a frame number and time row
data_out = [nframe; data.marker_data.Time'];

% now loop through each maker name and make marker name with 3 tabs for the
% first line and the X Y Z columns with the marker numnber on the second
% line all separated by tab delimeters
% each of the data columns (3 per marker) will be in floating format with a
% tab delimiter - also add to the data matrix
for i = 1:nmarkers
    dataheader1 = [dataheader1 markers{i} '\t\t\t'];    
    dataheader2 = [dataheader2 'X' num2str(i) '\t' 'Y' num2str(i) '\t'...
        'Z' num2str(i) '\t'];
    format_text = [format_text '%f\t%f\t%f\t'];
    % add 3 rows of data for the X Y Z coordinates of the current marker
    % first check for NaN's and fill with a linear interpolant - warn the
    % user of the gaps
    clear m
    m = find(isnan(data.marker_data.Markers.(markers{i})((data.Start_Frame:data.End_Frame),1))>0);
    if ~isempty(m);
        clear t d
        disp(['Warning -' markers{i} ' data missing in parts. Frames ' num2str(m(1)) '-'  num2str(m(end))])
        t = time;
        t(m) = [];
        d = data.marker_data.Markers.(markers{i})((data.Start_Frame:data.End_Frame),:);
        d(m,:) = [];
        data.marker_data.Markers.(markers{i})((data.Start_Frame:data.End_Frame),:) = interp1(t,d,time,'linear','extrap');
    end
    data_out = [data_out; data.marker_data.Markers.(markers{i})((data.Start_Frame:data.End_Frame),:)'];
end
dataheader1 = [dataheader1 '\n'];
dataheader2 = [dataheader2 '\n'];
format_text = [format_text '\n'];

disp('Writing trc file...') 

%Output marker data to an OpenSim TRC file

newfilename = strrep(fname,'c3d','trc');

if isempty(dir([pname 'Data']))
    mkdir(pname,'Data');
end
    
data.TRC_Filename = [pname 'Data\' newfilename];

%open the file
fid_1 = fopen(data.TRC_Filename,'w');

% first write the header data
fprintf(fid_1,'PathFileType\t4\t(X/Y/Z)\t %s\n',newfilename);
fprintf(fid_1,'DataRate\tCameraRate\tNumFrames\tNumMarkers\tUnits\tOrigDataRate\tOrigDataStartFrame\tOrigNumFrames\n');
fprintf(fid_1,'%d\t%d\t%d\t%d\t%s\t%d\t%d\t%d\n', data.marker_data.Info.frequency, data.marker_data.Info.frequency, nrows, nmarkers, data.marker_data.Info.units.ALLMARKERS, data.marker_data.Info.frequency,data.Start_Frame,data.End_Frame); 
fprintf(fid_1, dataheader1);
fprintf(fid_1, dataheader2);

% then write the output marker data
fprintf(fid_1, format_text,data_out);

% close the file
fclose(fid_1);

disp('Done.')

%%
% Write motion file containing GRFs

disp('Writing grf.mot file...')

if isfield(data,'fp_data')
    
    F = data.fp_data.Info(1).frequency/data.marker_data.Info.frequency; % assume that all force plates are collected at the same frequency!!!
    
    fp_time = 1/data.marker_data.Info.frequency:1/data.fp_data.Info(1).frequency:(F*(data.End_Frame-data.Start_Frame+1))/data.fp_data.Info(1).frequency;
    
    % initialise force data matrix with the time array and column header
    force_data_out = fp_time';
    force_header = 'time\t';
    force_format = '%20.6f\t';
    
    % if the assign_forces function has not been run then just make a force
    % file that contains the data from each force plate
    if ~isfield(data,'GRF')
        
        % go through each marker field and re-order from X Y Z to Y Z X and place
        % into data array and add data to the force data matrix --> also need to
        % divide by 1000 to convert to mm from m if necessary and Nmm to Nm
        % these are the conversions usually used in most motion analysis systems
        % and if they are different, just change the scale factor below to p_sc
        % value for the M data to 1. It should however get this from the file.
        
        for i = 1:length(data.fp_data.FP_data)
            
            if p_sc > 1
                fn = fieldnames(data.fp_data.Info(1).units);
                if strcmp(data.fp_data.Info(1).units.(fn{4}),'Nm')
                    p_sc = 1;
                end
            end
            % reorder and reflect axis (Fv)
            data.fp_data.GRF_data(i).F =  data.fp_data.GRF_data(i).F(:,order);
            data.fp_data.GRF_data(i).F(:,1) = data.fp_data.GRF_data(i).F(:,1)*-1;
            data.fp_data.GRF_data(i).F(:,3) = data.fp_data.GRF_data(i).F(:,3)*-1;
            % rescale the GRF COP to meters if necessary (Fp)
            data.fp_data.GRF_data(i).P =  data.fp_data.GRF_data(i).P/p_sc;
            % reorder and reflect axis 
            data.fp_data.GRF_data(i).P =  data.fp_data.GRF_data(i).P(:,order);
            data.fp_data.GRF_data(i).P(:,1) = data.fp_data.GRF_data(i).P(:,1)*-1;
            data.fp_data.GRF_data(i).P(:,3) = data.fp_data.GRF_data(i).P(:,3)*-1;
            % rescale the moments to meters as well, if necessary (T)
            data.fp_data.GRF_data(i).M =  data.fp_data.GRF_data(i).M/p_sc;
            % reorder and reflect axis
            data.fp_data.GRF_data(i).M =  data.fp_data.GRF_data(i).M(:,order);
            data.fp_data.GRF_data(i).M(:,1) = data.fp_data.GRF_data(i).M(:,1)*-1;
            data.fp_data.GRF_data(i).M(:,3) = data.fp_data.GRF_data(i).M(:,3)*-1;
            
            % do some cleaning of the COP before and after contact
            b = find(abs(diff(data.fp_data.GRF_data(i).P(:,3)))>0);
            if ~isempty(b)
                for j = 1:3
                    data.fp_data.GRF_data(i).P(1:b(1),j) = data.fp_data.GRF_data(i).P(b(1)+1,j);
                    data.fp_data.GRF_data(i).P(b(end):end,j) = data.fp_data.GRF_data(i).P(b(end)-1,j);
                end
            end
            
            % define the period which we are analysing
            K = (F*data.Start_Frame):1:(F*data.End_Frame);
            
            % add the force, COP and moment data for current plate to the force matrix
            force_data_out = [force_data_out data.fp_data.GRF_data(i).F(K,:) data.fp_data.GRF_data(i).P(K,:) data.fp_data.GRF_data(i).M(K,:)];
            % define the header and formats
            force_header = [force_header num2str(i) '_ground_force_vx\t' num2str(i) '_ground_force_vy\t' num2str(i) '_ground_force_vz\t'...
                num2str(i) '_ground_force_px\t' num2str(i) '_ground_force_py\t' num2str(i) '_ground_force_pz\t' ...
                num2str(i) '_ground_torque_x\t' num2str(i) '_ground_torque_y\t' num2str(i) '_ground_torque_z\t'];
            force_format = [force_format '%20.6f\t%20.6f\t%20.6f\t%20.6f\t%20.6f\t%20.6f\t%20.6f\t%20.6f\t%20.6f\t'];
            
        end
        
        force_header = [force_header(1:end-2) '\n'];
        force_format = [force_format(1:end-2) '\n'];
        
        % assign a value of zero to any NaNs
        force_data_out(logical(isnan(force_data_out))) = 0;
        
    else
        
        % go through each marker field and re-order from X Y Z to Y Z X and place
        % into data array and add data to the force data matrix --> also need to
        % divide by 1000 to convert to mm from m if necessary and Nmm to Nm
        % these are the conversions usually used in most motion analysis systems
        % and if they are different, just change the scale factor below to p_sc
        % value for the M data to 1. It should however get this from the file.
        data.AssignForce.ExForce = [];
        data.AssignForce.ApBodies = [];
        
        for i = 1:length(data.GRF.FP)
            
            fnames = fieldnames(data.GRF.FP(i));
            
            for j = 1:length(fnames)
                
                if isfield(data.GRF.FP(i).(fnames{j}),'F')
                    
                    
                    % rescale the GRF COP and moments to meters if
                    % necessary
                    data.GRF.FP(i).(fnames{j}).P =  data.GRF.FP(i).(fnames{j}).P/p_sc;
                    data.GRF.FP(i).(fnames{j}).M =  data.GRF.FP(i).(fnames{j}).M/p_sc;
                    
%                     % do some cleaning of the COP before and after contact
%                     b = find(abs(diff(data.GRF.FP(i).(fnames{j}).P(:,3)))>0);
%                     if ~isempty(b)
%                         for k = 1:3
%                             data.GRF.FP(i).(fnames{j}).P(1:b(1),k) = data.GRF.FP(i).(fnames{j}).P(b(1)+1,k);
%                             data.GRF.FP(i).(fnames{j}).P(b(end):end,k) = data.GRF.FP(i).(fnames{j}).P(b(end)-1,k);
%                         end
%                     end
                    
                    % define the period which we are analysing
                    K = (F*data.Start_Frame):1:(F*data.End_Frame);
                    
                    % add the force, COP and moment data for current plate to the force matrix
                    force_data_out = [force_data_out data.GRF.FP(i).(fnames{j}).F(K,:) data.GRF.FP(i).(fnames{j}).P(K,:) data.GRF.FP(i).(fnames{j}).M(K,:)];
                    % define the header and formats
                    force_header = [force_header fnames{j} num2str(i) '_ground_force_vx\t' fnames{j} num2str(i) '_ground_force_vy\t' fnames{j} num2str(i) '_ground_force_vz\t'...
                        fnames{j} num2str(i) '_ground_force_px\t' fnames{j} num2str(i) '_ground_force_py\t' fnames{j} num2str(i) '_ground_force_pz\t' ...
                        fnames{j} num2str(i) '_ground_torque_x\t' fnames{j} num2str(i) '_ground_torque_y\t' fnames{j} num2str(i) '_ground_torque_z\t'];
                    force_format = [force_format '%20.6f\t%20.6f\t%20.6f\t%20.6f\t%20.6f\t%20.6f\t%20.6f\t%20.6f\t%20.6f\t'];
                    
                    data.AssignForce.ExForce = [data.AssignForce.ExForce;{[fnames{j} num2str(i)]}];
                    data.AssignForce.ApBodies = [data.AssignForce.ApBodies;{[fnames{j}]}];
                end
            end
        end
        
        force_header = [force_header(1:end-2) '\n'];
        force_format = [force_format(1:end-2) '\n'];
        
        % assign a value of zero to any NaNs
        force_data_out(logical(isnan(force_data_out))) = 0;
        
    end

newfilename = [fname(1:end-4) '_grf.mot'];

data.GRF_Filename = [pname 'Data\' newfilename];

fid_2 = fopen(data.GRF_Filename,'w');

% write the header information
fprintf(fid_2,'%s\n',newfilename);
fprintf(fid_2,'version=1\n');
fprintf(fid_2,'nRows=%d\n', length(fp_time));  % total # of datacolumns
fprintf(fid_2,'nColumns %d\n',size(force_data_out,2)); % number of datarows
fprintf(fid_2,'inDegrees=yes\n'); % range of time data
fprintf(fid_2,'endheader\n');
fprintf(fid_2,force_header);

% write the data
fprintf(fid_2,force_format,force_data_out');

fclose(fid_2);

disp('Done.')
noGrf=0;
else
    disp('No force plate information available.');
    noGrf=1;
end
