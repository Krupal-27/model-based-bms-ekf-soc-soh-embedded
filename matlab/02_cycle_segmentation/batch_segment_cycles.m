%% BATCH SEGMENT CYCLES FOR ALL BATTERIES
% Processes all clean battery files and segments into cycles
% Saves with standard cell naming convention: cell01_cycles.mat, etc.
%
% File: matlab/02_cycle_segmentation/batch_segment_cycles.m

clear; clc; close all;

%% ========== SETUP PATHS ==========
cd('C:\Users\Krupal Babariya\Desktop\battery-bms-ecm-soc-soh\');
fprintf('========================================\n');
fprintf('🔄 BATCH CYCLE SEGMENTATION\n');
fprintf('========================================\n\n');

% Add paths
addpath(genpath('matlab'));

clean_path = 'data/clean/';
processed_path = 'data/processed/';  % Save directly to processed folder

%% ========== NASA BATTERY TO CELL NUMBER MAPPING ==========
fprintf('📋 Loading battery mapping...\n');

% Create mapping container
battery_map = containers.Map();
battery_map('B0005') = '01';
battery_map('B0006') = '02';
battery_map('B0007') = '03';
battery_map('B0018') = '04';
battery_map('B0025') = '05';
battery_map('B0026') = '06';
battery_map('B0027') = '07';
battery_map('B0028') = '08';
battery_map('B0029') = '09';
battery_map('B0030') = '10';
battery_map('B0031') = '11';
battery_map('B0032') = '12';
battery_map('B0033') = '13';
battery_map('B0034') = '14';
battery_map('B0036') = '15';
battery_map('B0038') = '16';
battery_map('B0039') = '17';
battery_map('B0040') = '18';
battery_map('B0041') = '19';
battery_map('B0042') = '20';
battery_map('B0043') = '21';
battery_map('B0044') = '22';
battery_map('B0045') = '23';
battery_map('B0046') = '24';
battery_map('B0047') = '25';
battery_map('B0048') = '26';
battery_map('B0049') = '27';
battery_map('B0050') = '28';
battery_map('B0051') = '29';
battery_map('B0052') = '30';
battery_map('B0053') = '31';
battery_map('B0054') = '32';
battery_map('B0055') = '33';
battery_map('B0056') = '34';

fprintf('✅ Loaded mapping for %d batteries\n\n', battery_map.Count);

%% ========== FIND ALL BATTERIES ==========
battery_folders = dir(fullfile(clean_path, 'B*'));
fprintf('📁 Found %d battery folders with clean data\n\n', length(battery_folders));

%% ========== PROCESS EACH BATTERY ==========
I_thr = 0.1;  % Default threshold
total_batteries = 0;
total_cycles_all = 0;

for b = 1:length(battery_folders)
    battery_id = battery_folders(b).name;
    
    % Get cell number from mapping
    if isKey(battery_map, battery_id)
        cell_num = battery_map(battery_id);
        cell_name = sprintf('cell%s', cell_num);
    else
        cell_name = lower(battery_id);  % Fallback
        fprintf('⚠️  No mapping for %s, using %s\n', battery_id, cell_name);
    end
    
    fprintf('🔄 [%d/%d] Processing %s → %s...\n', ...
        b, length(battery_folders), battery_id, cell_name);
    
    % Find all clean cycle files for this battery
    cycle_files = dir(fullfile(clean_path, battery_id, '*.mat'));
    
    if isempty(cycle_files)
        fprintf('   ⚠️  No clean cycle files found\n\n');
        continue;
    end
    
    % ========== FIX: USE CELL ARRAY FOR CYCLES ==========
    all_cycles = {};
    cycle_count = 0;
    
    % Process each clean file
    for f = 1:length(cycle_files)
        filepath = fullfile(cycle_files(f).folder, cycle_files(f).name);
        load(filepath, 'clean_data');
        
        % Segment this continuous chunk
        cycles = segment_cycles(clean_data, I_thr);
        
        % Add metadata to each cycle
        for i = 1:length(cycles)
            cycles(i).battery_id = battery_id;
            cycles(i).cell_name = cell_name;
            cycles(i).source_file = cycle_files(f).name;
            cycles(i).segment_idx = i;
        end
        
        % Store cycles in cell array
        for i = 1:length(cycles)
            cycle_count = cycle_count + 1;
            all_cycles{cycle_count} = cycles(i);
        end
        
        fprintf('   📄 %s: %d cycles\n', cycle_files(f).name, length(cycles));
    end
    
    if cycle_count == 0
        fprintf('   ⚠️  No cycles extracted\n\n');
        continue;
    end
    
    % ========== FIX: SAFELY CONVERT CELL ARRAY TO STRUCT ARRAY ==========
    % Get ALL possible field names from all cycles
    all_field_names = {};
    for i = 1:cycle_count
        fields = fieldnames(all_cycles{i});
        all_field_names = [all_field_names; fields];
    end
    all_field_names = unique(all_field_names);  % Remove duplicates
    
    % Initialize struct array with all possible fields
    cycles = struct();
    for i = 1:length(all_field_names)
        % Initialize with empty arrays of appropriate type
        [cycles(1:cycle_count).(all_field_names{i})] = deal([]);
    end
    
    % Safely fill with data from cell array (only if field exists)
    for i = 1:cycle_count
        for j = 1:length(all_field_names)
            field = all_field_names{j};
            % Check if this cycle has this field
            if isfield(all_cycles{i}, field)
                cycles(i).(field) = all_cycles{i}.(field);
            end
            % If field doesn't exist, it stays as empty []
        end
    end
    
    %% ========== SAVE WITH CELL NAMING CONVENTION ==========
    % Primary save: cellXX_cycles.mat
    cell_filename = sprintf('%s_cycles.mat', cell_name);
    cell_save_path = fullfile(processed_path, cell_filename);
    
    save(cell_save_path, 'cycles');
    fprintf('   💾 PRIMARY: %s\n', cell_filename);
    
    %% ========== ALSO SAVE WITH BATTERY ID FOR BACKUP ==========
    % Secondary save: BXXXX_segmented_cycles.mat
    backup_filename = sprintf('%s_segmented_cycles.mat', battery_id);
    backup_save_path = fullfile(processed_path, backup_filename);
    save(backup_save_path, 'cycles');
    fprintf('   💾 BACKUP: %s\n', backup_filename);
    
    % Count cycle types (with safe field access)
    n_discharge = 0; n_charge = 0; n_rest = 0;
    for i = 1:length(cycles)
        if isfield(cycles(i), 'type')
            if strcmp(cycles(i).type, 'discharge')
                n_discharge = n_discharge + 1;
            elseif strcmp(cycles(i).type, 'charge')
                n_charge = n_charge + 1;
            elseif strcmp(cycles(i).type, 'rest')
                n_rest = n_rest + 1;
            end
        end
    end
    
    fprintf('   📊 Total: %d cycles (D:%d, C:%d, R:%d)\n', ...
        cycle_count, n_discharge, n_charge, n_rest);
    fprintf('   📁 Location: %s\n\n', cell_save_path);
    
    total_batteries = total_batteries + 1;
    total_cycles_all = total_cycles_all + cycle_count;
end

%% ========== SUMMARY ==========
fprintf('========================================\n');
fprintf('🎉 BATCH SEGMENTATION COMPLETE!\n');
fprintf('========================================\n');
fprintf('   📊 Processed: %d batteries\n', total_batteries);
fprintf('   🔄 Total cycles: %d\n', total_cycles_all);
fprintf('   📁 Output folder: %s\n', processed_path);
fprintf('   🔧 Threshold: ±%.2f A\n', I_thr);
fprintf('   📋 Naming: cellXX_cycles.mat\n');
fprintf('========================================\n');

%% ========== VERIFY FIRST BATTERY ==========
fprintf('\n🔍 Verification:\n');
test_file = fullfile(processed_path, 'cell01_cycles.mat');
if exist(test_file, 'file')
    load(test_file, 'cycles');
    fprintf('✅ Successfully created: cell01_cycles.mat\n');
    fprintf('   📊 Contains %d cycles\n', length(cycles));
    if length(cycles) > 0
        if isfield(cycles(1), 'battery_id')
            fprintf('   🔋 Battery: %s\n', cycles(1).battery_id);
        end
        if isfield(cycles(1), 'type')
            fprintf('   🔄 First cycle type: %s\n', cycles(1).type);
        end
        % Check if capacity field exists
        if isfield(cycles(1), 'Q')
            fprintf('   🔋 Has capacity field (Q)\n');
        end
    end
else
    fprintf('❌ cell01_cycles.mat not found\n');
end

fprintf('\n========================================\n');