%% ORGANIZE NASA BATTERY DATASET BY BATTERY ID
% This script reads metadata.csv and organizes all CSV files by battery
% Saves each battery as a separate .mat file in data/processed/

clear; clc;
close all;

%% SHOW CURRENT LOCATION FOR DEBUGGING
fprintf('📂 Script is running from: %s\n', pwd);

%% SETUP PATHS - USING ABSOLUTE PATH FROM PROJECT ROOT
% Get the project root path (go up two levels from matlab/01_import_clean)
project_root = fullfile(fileparts(fileparts(pwd)));  % Goes up two levels
raw_path = fullfile(project_root, 'data', 'raw', 'nasa');
proc_path = fullfile(project_root, 'data', 'processed');

fprintf('📁 Project root: %s\n', project_root);
fprintf('📁 Raw data path: %s\n', raw_path);
fprintf('📁 Processed path: %s\n', proc_path);

% Verify the raw path exists
if ~exist(raw_path, 'dir')
    error('❌ Folder not found: %s\nPlease check your folder structure.', raw_path);
end

% Check for metadata file
metadata_file = fullfile(raw_path, 'metadata.csv');
if ~exist(metadata_file, 'file')
    error('❌ metadata.csv not found in: %s', raw_path);
end

% Create processed folder if it doesn't exist
if ~exist(proc_path, 'dir')
    mkdir(proc_path);
    fprintf('✅ Created processed folder\n');
end

%% LOAD METADATA
fprintf('📂 Loading metadata from: %s\n', metadata_file);
metadata = readtable(metadata_file);

% Display summary
fprintf('✅ Metadata loaded: %d rows\n', height(metadata));
fprintf('📊 Columns: %s\n', strjoin(metadata.Properties.VariableNames, ', '));

%% GET UNIQUE BATTERIES
batteries = unique(metadata.battery_id);
fprintf('🔋 Found %d batteries: %s\n', length(batteries), strjoin(batteries, ', '));

%% PROCESS EACH BATTERY
for b = 1:length(batteries)
    battery_id = batteries{b};
    fprintf('\n🔄 Processing battery %s (%d of %d)...\n', ...
        battery_id, b, length(batteries));
    
    % Get all rows for this battery
    battery_mask = strcmp(metadata.battery_id, battery_id);
    battery_metadata = metadata(battery_mask, :);
    
    % Initialize structure to store all cycles
    BatteryData = struct();
    BatteryData.battery_id = battery_id;
    BatteryData.metadata = battery_metadata;
    BatteryData.cycles = struct();
    
    % Get unique test cycles for this battery
    test_ids = unique(battery_metadata.test_id);
    
    cycle_count = 0;
    for t = 1:length(test_ids)
        test_mask = battery_metadata.test_id == test_ids(t);
        test_row = battery_metadata(test_mask, :);
        
        % Get filename and type
        filename = test_row.filename{1};
        filepath = fullfile(raw_path, filename);
        test_type = test_row.type{1};
        
        % Check if file exists
        if ~exist(filepath, 'file')
            fprintf('  ⚠️  File not found: %s\n', filename);
            continue;
        end
        
        % Load the CSV file
        try
            data = readtable(filepath);
            cycle_count = cycle_count + 1;
            
            % Store in structure
            BatteryData.cycles(cycle_count).type = test_type;
            BatteryData.cycles(cycle_count).test_id = test_ids(t);
            BatteryData.cycles(cycle_count).filename = filename;
            BatteryData.cycles(cycle_count).start_time = test_row.start_time;
            BatteryData.cycles(cycle_count).ambient_temp = test_row.ambient_temperature;
            BatteryData.cycles(cycle_count).data = data;
            
            % Store capacity if available (discharge cycles)
            if strcmp(test_type, 'discharge') && ...
               ismember('Capacity', test_row.Properties.VariableNames)
                BatteryData.cycles(cycle_count).capacity = test_row.Capacity;
            end
            
            % Store impedance if available
            if strcmp(test_type, 'impedance') && ...
               ismember('Re', test_row.Properties.VariableNames)
                BatteryData.cycles(cycle_count).Re = test_row.Re;
                BatteryData.cycles(cycle_count).Rct = test_row.Rct;
            end
            
            fprintf('  ✅ Loaded cycle %d: %s - %s (%d rows)\n', ...
                cycle_count, filename, test_type, height(data));
            
        catch ME
            fprintf('  ❌ Error loading %s: %s\n', filename, ME.message);
        end
    end
    
    % Save battery data
    save_filename = sprintf('battery_%s.mat', battery_id);
    save_path = fullfile(proc_path, save_filename);
    save(save_path, 'BatteryData');
    fprintf('💾 Saved %d cycles to %s\n', cycle_count, save_filename);
end

fprintf('\n🎉 ALL DONE! Processed %d batteries\n', length(batteries));
fprintf('📁 Processed files saved to: %s\n', proc_path);