%% BATCH BUILD OCV-SOC CURVES FOR ALL BATTERIES
clear; clc; close all;

%% ========== SETUP ==========
cd('C:\Users\Krupal Babariya\Desktop\battery-bms-ecm-soc-soh\');
addpath(genpath('matlab'));

fprintf('========================================\n');
fprintf('🔋 BATCH OCV-SOC CURVE CONSTRUCTION\n');
fprintf('========================================\n\n');

%% ========== FIND ALL DISCHARGE CURVE FILES ==========
discharge_files = dir('data/processed/*_discharge_curves.mat');
fprintf('📁 Found %d battery discharge curve files\n\n', length(discharge_files));

%% ========== PROCESS EACH BATTERY ==========
for f = 1:length(discharge_files)
    filename = discharge_files(f).name;
    battery_id = strrep(filename, '_discharge_curves.mat', '');
    
    fprintf('🔄 [%d/%d] Processing %s...\n', f, length(discharge_files), battery_id);
    
    % Load discharge curves
    load(fullfile(discharge_files(f).folder, filename), 'discharge_data');
    
    if isempty(discharge_data)
        fprintf('   ⚠️  No discharge data found\n\n');
        continue;
    end
    
    % Use first discharge cycle for OCV
    discharge = discharge_data(1);
    
    % Build OCV curve
    [SOC_lookup, OCV_lookup] = build_ocv_curve(discharge, 'smooth', false);
    
    % Save
    ocv_data = struct();
    ocv_data.SOC = SOC_lookup;
    ocv_data.OCV = OCV_lookup;
    ocv_data.method = 'smooth';
    ocv_data.source_battery = battery_id;
    ocv_data.source_cycle = 1;
    ocv_data.created = datestr(now);
    
    save_filename = sprintf('%s_OCV_curve.mat', battery_id);
    save_path = fullfile('data/processed', save_filename);
    save(save_path, 'ocv_data');
    
    fprintf('   💾 Saved: %s\n', save_filename);
    fprintf('      OCV range: %.3f - %.3f V\n\n', min(OCV_lookup), max(OCV_lookup));
end

fprintf('========================================\n');
fprintf('🎉 BATCH OCV CONSTRUCTION COMPLETE!\n');
fprintf('========================================\n');