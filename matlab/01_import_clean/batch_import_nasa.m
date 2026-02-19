%% BATCH IMPORT AND CLEAN ALL NASA BATTERIES
% Processes all cycles for all batteries
% Saves individual clean cycle files
%
% File: matlab/01_import_clean/batch_import_nasa.m

clear; clc; close all;
fprintf('========================================\n');
fprintf('🧹 BATCH IMPORT & CLEAN - NASA DATASET\n');
fprintf('========================================\n\n');

%% ========== SETUP PATHS ==========
% FIX: Get project root correctly when running from matlab/01_import_clean
current_dir = pwd;
if contains(current_dir, 'matlab\01_import_clean') || contains(current_dir, 'matlab/01_import_clean')
    project_root = fileparts(fileparts(current_dir));  % Go up two levels
else
    project_root = current_dir;
end

processed_path = fullfile(project_root, 'data', 'processed');
clean_path = fullfile(project_root, 'data', 'clean');

fprintf('📁 Project root: %s\n', project_root);
fprintf('📁 Looking for data in: %s\n', processed_path);

% Create clean folder if it doesn't exist
if ~exist(clean_path, 'dir')
    mkdir(clean_path);
    fprintf('📁 Created: %s\n', clean_path);
end

%% ========== FIND ALL BATTERY FILES ==========
battery_files = dir(fullfile(processed_path, 'battery_*.mat'));
fprintf('📁 Found %d battery files\n\n', length(battery_files));

% FIX: Check if files exist
if isempty(battery_files)
    error('❌ No battery files found in %s\nPlease run organize_nasa_by_battery.m first', processed_path);
end

%% ========== PROCESS EACH BATTERY ==========
total_cycles = 0;
total_clean_cycles = 0;

for b = 1:length(battery_files)
    % Load battery
    battery_file = fullfile(battery_files(b).folder, battery_files(b).name);
    load(battery_file, 'BatteryData');
    
    battery_id = BatteryData.battery_id;
    fprintf('🔄 [%d/%d] Processing %s...\n', b, length(battery_files), battery_id);
    
    % Create battery folder in clean directory
    battery_clean_path = fullfile(clean_path, battery_id);
    if ~exist(battery_clean_path, 'dir')
        mkdir(battery_clean_path);
    end
    
    % Process each cycle
    n_cycles = length(BatteryData.cycles);
    cycle_count = 0;
    
    for i = 1:n_cycles
        cycle = BatteryData.cycles(i);
        cycle_type = cycle.type;
        
        % Skip impedance tests for now (special handling needed)
        if strcmpi(cycle_type, 'impedance')
            continue;
        end
        
        try
            % Clean the data
            clean_data = import_nasa(cycle.data, cycle_type);
            
            % Create filename
            filename = sprintf('%s_cycle%03d_%s.mat', ...
                battery_id, i, cycle_type);
            filepath = fullfile(battery_clean_path, filename);
            
            % Save
            save(filepath, 'clean_data');
            cycle_count = cycle_count + 1;
            
        catch ME
            fprintf('   ❌ Cycle %d (%s): %s\n', i, cycle_type, ME.message);
        end
    end
    
    fprintf('   ✅ Saved %d clean cycles\n', cycle_count);
    total_cycles = total_cycles + n_cycles;
    total_clean_cycles = total_clean_cycles + cycle_count;
end

%% ========== SUMMARY ==========
fprintf('\n========================================\n');
fprintf('🎉 BATCH PROCESSING COMPLETE!\n');
fprintf('========================================\n');
fprintf('   📁 Processed: %d batteries\n', length(battery_files));
fprintf('   🔄 Total raw cycles: %d\n', total_cycles);
fprintf('   ✨ Clean cycles saved: %d\n', total_clean_cycles);
fprintf('   💾 Output: %s\n', clean_path);
fprintf('========================================\n');