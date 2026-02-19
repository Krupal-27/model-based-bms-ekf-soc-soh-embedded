%% TEST ONLINE SOH ESTIMATION
clear; clc; close all;

cd('C:\Users\Krupal Babariya\Desktop\battery-bms-ecm-soc-soh\');
addpath(genpath('matlab'));

fprintf('========================================\n');
fprintf('🔧 TEST ONLINE SOH ESTIMATION\n');
fprintf('========================================\n\n');

%% ========== LOAD DATA ==========
fprintf('📂 Loading cycle data...\n');

load('data/processed/cell01_cycles.mat', 'cycles');
load('data/processed/B0005_OCV_manual.mat', 'ocv_data');

fprintf('✅ Loaded %d total cycles\n', length(cycles));

%% ========== SET INITIAL PARAMETERS (FRESH BATTERY) ==========
params0.R0 = 0.1767;   % Fresh battery R0
params0.R1 = 0.0990;
params0.C1 = 50000;
params0.Q_nom = 1.862;  % Fresh battery capacity

fprintf('\n📊 Fresh battery parameters:\n');
fprintf('   R0 = %.4f Ω\n', params0.R0);
fprintf('   Q_nom = %.3f Ah\n\n', params0.Q_nom);

%% ========== RUN ONLINE SOH ESTIMATION ==========
options.R_fit_interval = 10;   % Re-fit R0 every 10 cycles
options.smooth_window = 3;      % 3-point moving average
options.plot_results = true;
options.min_points = 100;       % Min points for valid discharge

[SOH_history, stats] = soh_online(cycles, ocv_data, params0, options);

%% ========== VALIDATION ==========
fprintf('\n🔍 Validation against known degradation:\n');

% Load previous degradation results if available
if exist('data/processed/B0005_degradation_results.mat', 'file')
    load('data/processed/B0005_degradation_results.mat', 'degradation_results');
    
    % Compare final SOH
    fprintf('   Reference final SOH: %.1f%%\n', degradation_results.SOH_fused(end));
    fprintf('   Online estimated final SOH: %.1f%%\n', SOH_history.SOH_smoothed(end));
    fprintf('   Difference: %.1f%%\n', ...
        abs(SOH_history.SOH_smoothed(end) - degradation_results.SOH_fused(end)));
end

%% ========== SAVE RESULTS ==========
save('data/processed/online_soh_results.mat', 'SOH_history', 'stats');
fprintf('\n💾 Saved: data/processed/online_soh_results.mat\n');

%% ========== SUMMARY ==========
fprintf('\n========================================\n');
fprintf('📊 ONLINE SOH ESTIMATION SUMMARY\n');
fprintf('========================================\n');
fprintf('   Cycles processed: %d\n', stats.n_cycles);
fprintf('   Initial capacity: %.3f Ah\n', stats.Q_initial);
fprintf('   Final capacity: %.3f Ah\n', stats.Q_final);
fprintf('   Capacity fade: %.1f%% (%.1f mAh/cycle)\n', ...
    stats.Q_fade_percent, stats.Q_fade_rate);
fprintf('   Initial R0: %.1f mΩ\n', stats.R0_initial*1000);
fprintf('   Final R0: %.1f mΩ\n', stats.R0_final*1000);
fprintf('   R0 increase: %.1f%%\n', stats.R0_increase_percent);
fprintf('   Initial SOH: %.1f%%\n', stats.SOH_initial);
fprintf('   Final SOH: %.1f%%\n', stats.SOH_final);
fprintf('   SOH fade rate: %.3f%%/cycle\n', stats.SOH_fade_rate);
fprintf('========================================\n');

if stats.SOH_final < 80
    fprintf('⚠️  Battery has reached End of Life (SOH < 80%%)\n');
else
    fprintf('✅ Battery still healthy\n');
end
fprintf('========================================\n');