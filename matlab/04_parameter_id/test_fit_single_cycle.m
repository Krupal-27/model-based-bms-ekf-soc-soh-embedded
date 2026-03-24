%% TEST FITTING ON A SINGLE CYCLE - FIXED VERSION
clear; clc; close all;

cd('C:\Users\Krupal Babariya\Desktop\battery-bms-ecm-soc-soh\');
addpath(genpath('matlab'));

fprintf('========================================\n');
fprintf('TEST SINGLE CYCLE FITTING\n');
fprintf('========================================\n\n');

%% LOAD DATA
fprintf('Loading data...\n');

load('data/processed/cell01_cycles.mat', 'cycles');
load('data/processed/B0005_OCV_manual.mat', 'ocv_data');

fprintf('Loaded %d total cycles\n', length(cycles));

%% FIND A VALID DISCHARGE CYCLE
fprintf('\nSearching for valid discharge cycle...\n');

valid_cycle_found = false;
test_cycle_idx = 0;

for i = 1:min(100, length(cycles))
    if strcmp(cycles(i).type, 'discharge')
        current_threshold = 0.1;
        start_idx = find(abs(cycles(i).I) > current_threshold, 1, 'first');
        end_idx = find(abs(cycles(i).I) > current_threshold, 1, 'last');
        
        if ~isempty(start_idx) && ~isempty(end_idx) && (end_idx - start_idx > 100)
            valid_cycle_found = true;
            test_cycle_idx = i;
            break;
        end
    end
end

if ~valid_cycle_found
    error('No valid discharge cycle found in first 100 cycles');
end

d = cycles(test_cycle_idx);
fprintf('Using cycle #%d for testing\n', test_cycle_idx);
fprintf('   Type: %s\n', d.type);
fprintf('   Total duration: %.1f s\n', d.time(end));
fprintf('   Capacity: %.3f Ah\n', d.Q);

%% TRIM DISCHARGE DATA
current_threshold = 0.1;
start_idx = find(abs(d.I) > current_threshold, 1, 'first');
end_idx = find(abs(d.I) > current_threshold, 1, 'last');

if isempty(start_idx) || isempty(end_idx)
    error('No discharge portion found in cycle');
end

cycle_data = struct();
cycle_data.time = double(d.time(start_idx:end_idx) - d.time(start_idx));
cycle_data.I = double(d.I(start_idx:end_idx));
cycle_data.V = double(d.V(start_idx:end_idx));
cycle_data.Q = double(d.Q);

fprintf('\nTrimmed discharge data:\n');
fprintf('   Points: %d\n', length(cycle_data.time));
fprintf('   Time range: %.1f - %.1f s\n', cycle_data.time(1), cycle_data.time(end));
fprintf('   Current range: %.3f - %.3f A\n', min(cycle_data.I), max(cycle_data.I));
fprintf('   Voltage range: %.3f - %.3f V\n', min(cycle_data.V), max(cycle_data.V));
fprintf('   |I| mean: %.3f A\n', mean(abs(cycle_data.I)));

%% CHECK DATA QUALITY
if any(isnan(cycle_data.time)) || any(isinf(cycle_data.time))
    error('Time data contains NaN or Inf');
end
if any(isnan(cycle_data.I)) || any(isinf(cycle_data.I))
    error('Current data contains NaN or Inf');
end
if any(isnan(cycle_data.V)) || any(isinf(cycle_data.V))
    error('Voltage data contains NaN or Inf');
end

fprintf('Data quality check passed\n\n');

%% FIT PARAMETERS
[x_opt, fval, V_sim] = fit_ecm_1rc(cycle_data, ocv_data);

%% VERIFY WITH PREVIOUS RESULTS
fprintf('\nComparison with optimized parameters:\n');
if exist('data/processed/B0005_params_optimized.mat', 'file')
    load('data/processed/B0005_params_optimized.mat', 'opt_params');
    fprintf('   %-10s %-15s %-15s %-10s\n', 'Parameter', 'Previous', 'Current', 'Diff');
    fprintf('   %-10s %-15.4f %-15.4f %-10.1f%%\n', 'R0', opt_params.R0, x_opt(1), (x_opt(1)/opt_params.R0-1)*100);
    fprintf('   %-10s %-15.4f %-15.4f %-10.1f%%\n', 'R1', opt_params.R1, x_opt(2), (x_opt(2)/opt_params.R1-1)*100);
    fprintf('   %-10s %-15.0f %-15.0f %-10.1f%%\n', 'C1', opt_params.C1, x_opt(3), (x_opt(3)/opt_params.C1-1)*100);
else
    fprintf('   Previous optimized parameters not found\n');
end
