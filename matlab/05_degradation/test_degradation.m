%% TEST DEGRADATION TRENDS ANALYSIS
clear; clc; close all;

cd('C:\Users\Krupal Babariya\Desktop\battery-bms-ecm-soc-soh\');
addpath(genpath('matlab'));

fprintf('========================================\n');
fprintf('🧪 TEST DEGRADATION ANALYSIS\n');
fprintf('========================================\n\n');

%% ========== CREATE SYNTHETIC DATA IF NEEDED ==========
if ~exist('data/processed/B0005_degradation_trends.mat', 'file')
    fprintf('📂 Creating synthetic degradation data...\n');
    
    cycles = [1, 20, 50, 80, 100, 120, 140, 160, 168]';
    Q = 1.862 * (1 - 0.0015 * (cycles-1));  % Linear fade
    R0 = 0.1767 * (1 + 0.002 * (cycles-1)); % Linear growth
    R1 = 0.2 * ones(size(cycles));
    C1 = 40000 * ones(size(cycles));
    rmse = 180 * ones(size(cycles));
    
    degradation_data.cycles = cycles;
    degradation_data.Q = Q;
    degradation_data.R0 = R0;
    degradation_data.R1 = R1;
    degradation_data.C1 = C1;
    degradation_data.rmse = rmse;
    
    save('data/processed/B0005_degradation_trends.mat', 'degradation_data');
    fprintf('✅ Synthetic data created\n\n');
end

%% ========== RUN DEGRADATION ANALYSIS ==========
run('matlab/05_degradation/degradation_trends.m');

%% ========== QUICK VERIFICATION ==========
fprintf('\n🔍 Quick verification:\n');
fprintf('   SOH_Q(1) = %.1f%%\n', SOH_Q(1));
fprintf('   SOH_Q(end) = %.1f%%\n', SOH_Q(end));
fprintf('   SOH_R(1) = %.1f%%\n', SOH_R(1));
fprintf('   SOH_R(end) = %.1f%%\n', SOH_R(end));
fprintf('   SOH_fused(1) = %.1f%%\n', SOH_fused(1));
fprintf('   SOH_fused(end) = %.1f%%\n', SOH_fused(end));

if SOH_fused(1) == 100 && SOH_fused(end) < 100
    fprintf('✅ SOH calculation correct!\n');
else
    fprintf('⚠️  SOH calculation may need review\n');
end