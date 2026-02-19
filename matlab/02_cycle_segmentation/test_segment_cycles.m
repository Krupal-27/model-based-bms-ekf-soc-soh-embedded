%% TEST CYCLE SEGMENTATION ON ONE BATTERY
clear; clc; close all;

%% ========== FORCE CORRECT PATH ==========
cd('C:\Users\Krupal Babariya\Desktop\battery-bms-ecm-soc-soh\');
fprintf('📁 Working directory: %s\n', pwd);

%% ========== LOAD CLEAN DATA ==========
% Use the clean file we just created
load('data/clean/B0005/B0005_cycle002_discharge.mat', 'clean_data');

fprintf('📂 Loaded clean B0005 discharge cycle\n');
fprintf('📊 Data points: %d\n', length(clean_data.time));
fprintf('   Time: %.1f - %.1f s\n', clean_data.time(1), clean_data.time(end));
fprintf('   Current: %.3f - %.3f A\n', min(clean_data.I), max(clean_data.I));
fprintf('\n');

%% ========== SEGMENT CYCLES ==========
% Test with different thresholds
thresholds = [0.05, 0.1, 0.2];

for t = 1:length(thresholds)
    I_thr = thresholds(t);
    fprintf('🔍 Testing I_thr = %.2f A\n', I_thr);
    
    cycles = segment_cycles(clean_data, I_thr);
    
    fprintf('   Found %d cycles\n', length(cycles));
    for i = 1:length(cycles)
        fprintf('      Cycle %d: %s, %.1f s, I_avg = %.3f A\n', ...
            i, cycles(i).type, cycles(i).duration, cycles(i).I_avg);
    end
    fprintf('\n');
end

%% ========== USE DEFAULT THRESHOLD ==========
fprintf('🔍 Using default threshold (0.1A)...\n');
cycles = segment_cycles(clean_data);

%% ========== VISUALIZE SEGMENTATION ==========
figure('Name', 'Cycle Segmentation Test', 'Position', [100, 100, 1200, 800]);

% Plot 1: Current with threshold bands
subplot(2,1,1);
plot(clean_data.time, clean_data.I, 'b-', 'LineWidth', 1);
hold on;
yline(0.1, 'r--', 'Charge Thr', 'LineWidth', 1);
yline(-0.1, 'r--', 'Discharge Thr', 'LineWidth', 1);
xlabel('Time (s)');
ylabel('Current (A)');
title('Current Profile with Detection Thresholds');
legend('Current', '±0.1A Threshold', 'Location', 'best');
grid on;
ylim([-2.5, 0.5]);

% Plot 2: Voltage with cycle overlays
subplot(2,1,2);
plot(clean_data.time, clean_data.V, 'k-', 'LineWidth', 1);
hold on;

% Color-code different cycles
colors = {'r', 'g', 'b', 'c', 'm', 'y'};
for i = 1:length(cycles)
    idx_start = cycles(i).start_idx;
    idx_end = cycles(i).end_idx;
    time_seg = clean_data.time(idx_start:idx_end);
    V_seg = clean_data.V(idx_start:idx_end);
    
    color_idx = mod(i-1, length(colors)) + 1;
    plot(time_seg, V_seg, '-', 'Color', colors{color_idx}, ...
        'LineWidth', 2, 'DisplayName', sprintf('%s Cycle %d', cycles(i).type, i));
end

xlabel('Time (s)');
ylabel('Voltage (V)');
title('Voltage Profile - Segmented Cycles');
legend('Location', 'best');
grid on;

sgtitle('Cycle Segmentation Test - B0005', 'FontSize', 14, 'FontWeight', 'bold');

%% ========== CYCLE STATISTICS ==========
fprintf('\n📊 Cycle Statistics:\n');
fprintf('   ────────────────────────────────\n');
fprintf('   Cycle  Type        Duration(s)  I_avg(A)   V_min(V)   V_max(V)   Capacity(Ah)\n');
fprintf('   ────────────────────────────────\n');

for i = 1:length(cycles)
    if isfield(cycles(i), 'Q')
        cap = cycles(i).Q;
    else
        cap = NaN;
    end
    
    fprintf('   %3d    %-9s %8.1f   %8.3f   %8.3f   %8.3f   %8.3f\n', ...
        i, cycles(i).type, cycles(i).duration, ...
        cycles(i).I_avg, cycles(i).V_min, cycles(i).V_max, cap);
end
fprintf('   ────────────────────────────────\n');

%% ========== SAVE SEGMENTED CYCLES ==========
save_path = 'data/processed/B0005_segmented_cycles.mat';
save(save_path, 'cycles');
fprintf('\n💾 Saved segmented cycles to: %s\n', save_path);

fprintf('\n✅ Test complete!\n');