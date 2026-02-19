%% BATCH COMPUTE CAPACITY FOR ALL BATTERY CELLS
% Processes all cellXX_cycles.mat files and computes capacity fade curves
%
% File: matlab/02_cycle_segmentation/batch_compute_capacity.m

clear; clc; close all;

%% ========== SETUP ==========
cd('C:\Users\Krupal Babariya\Desktop\battery-bms-ecm-soc-soh\');
addpath(genpath('matlab'));

fprintf('========================================\n');
fprintf('🔋 BATCH CAPACITY COMPUTATION\n');
fprintf('========================================\n\n');

%% ========== FIND ALL CELL CYCLE FILES ==========
cycle_files = dir('data/processed/cell*_cycles.mat');
fprintf('📁 Found %d cell cycle files\n\n', length(cycle_files));

%% ========== PROCESS EACH CELL ==========
all_capacity_data = struct();
capacity_tables = {};

for f = 1:length(cycle_files)
    filename = cycle_files(f).name;
    cell_name = strrep(filename, '_cycles.mat', '');
    
    fprintf('🔄 [%d/%d] Processing %s...\n', f, length(cycle_files), cell_name);
    
    % Load cycles
    load(fullfile(cycle_files(f).folder, filename), 'cycles');
    
    % Compute capacity
    try
        capacity_data = compute_capacity(cycles, cell_name);
        
        % Save individual cell capacity
        save_filename = sprintf('%s_capacity.mat', cell_name);
        save_path = fullfile('data/processed', save_filename);
        save(save_path, 'capacity_data');
        fprintf('   💾 Saved: %s\n', save_filename);
        
        % Store for combined analysis
        capacity_tables{f} = capacity_data;
        all_capacity_data.(cell_name) = capacity_data;
        
    catch ME
        fprintf('   ❌ Error: %s\n', ME.message);
    end
    
    fprintf('\n');
end

%% ========== SAVE COMBINED CAPACITY DATA ==========
save('data/processed/all_cells_capacity.mat', 'all_capacity_data', 'capacity_tables');
fprintf('💾 Saved: all_cells_capacity.mat\n\n');

%% ========== PLOT ALL CAPACITY FADE CURVES ==========
figure('Name', 'All Cells Capacity Fade', 'Position', [100, 100, 1400, 800]);

colors = lines(length(capacity_tables));
hold on;

for i = 1:length(capacity_tables)
    data = capacity_tables{i};
    plot(data.cycle_idx, data.capacity_Ah, '-o', ...
        'Color', colors(i,:), ...
        'LineWidth', 1.2, ...
        'MarkerSize', 4, ...
        'DisplayName', strrep(cycle_files(i).name, '_cycles.mat', ''));
end

xlabel('Cycle Number');
ylabel('Capacity (Ah)');
title('All Battery Cells - Capacity Fade Comparison');
legend('Location', 'eastoutside', 'FontSize', 8);
grid on;
xlim([0, max(cellfun(@(x) max(x.cycle_idx), capacity_tables))]);

%% ========== SUMMARY ==========
fprintf('========================================\n');
fprintf('🎉 BATCH CAPACITY COMPUTATION COMPLETE!\n');
fprintf('========================================\n');
fprintf('   📊 Processed: %d cells\n', length(capacity_tables));
fprintf('   💾 Output: data/processed/*_capacity.mat\n');
fprintf('   📁 Combined: all_cells_capacity.mat\n');
fprintf('========================================\n');