%% TEST CAPACITY COMPUTATION ON B0005
clear; clc; close all;

%% SETUP
cd('C:\Users\Krupal Babariya\Desktop\battery-bms-ecm-soc-soh\');
addpath(genpath('matlab'));

%% LOAD SEGMENTED CYCLES
load('data/processed/cell01_cycles.mat', 'cycles');
fprintf('Loaded cell01_cycles.mat (%d cycles)\n\n', length(cycles));

%% COMPUTE CAPACITY
capacity_data = compute_capacity(cycles, 'cell01');

%% SAVE CAPACITY DATA
save('data/processed/cell01_capacity.mat', 'capacity_data');
fprintf('\nSaved: data/processed/cell01_capacity.mat\n');

%% PLOT CAPACITY FADE CURVE
figure('Name', 'Capacity Fade Curve', 'Position', [100, 100, 1200, 500]);

subplot(1,3,1);
plot(capacity_data.cycle_idx, capacity_data.capacity_Ah, 'b-o', ...
    'LineWidth', 1.5, 'MarkerSize', 6, 'MarkerFaceColor', 'b');
xlabel('Cycle Number');
ylabel('Capacity (Ah)');
title('Capacity Fade vs Cycle');
grid on;
ylim([0, max(capacity_data.capacity_Ah)*1.1]);

subplot(1,3,2);
plot(capacity_data.timestamp_s/3600, capacity_data.capacity_Ah, 'r-s', ...
    'LineWidth', 1.5, 'MarkerSize', 6, 'MarkerFaceColor', 'r');
xlabel('Time (hours)');
ylabel('Capacity (Ah)');
title('Capacity Fade vs Time');
grid on;

subplot(1,3,3);
hold on;
plot(capacity_data.cycle_idx, capacity_data.V_max, 'g-^', ...
    'LineWidth', 1.5, 'MarkerSize', 6);
plot(capacity_data.cycle_idx, capacity_data.V_min, 'm-v', ...
    'LineWidth', 1.5, 'MarkerSize', 6);
xlabel('Cycle Number');
ylabel('Voltage (V)');
title('Voltage Range vs Cycle');
legend('V_{max}', 'V_{min}', 'Location', 'best');
grid on;

sgtitle(sprintf('Battery %s - Capacity Fade Analysis', 'cell01'), ...
    'FontSize', 14, 'FontWeight', 'bold');

%% PRINT STATISTICS
fprintf('\nCapacity Fade Statistics:\n');
fprintf('   ----------------------------------------------------\n');
fprintf('   Cycle    Capacity(Ah)    I_avg(A)    Duration(s)    V_min(V)    V_max(V)\n');
fprintf('   ----------------------------------------------------\n');

for i = 1:min(10, height(capacity_data))
    fprintf('   %3d       %8.3f       %8.3f      %8.0f       %8.3f     %8.3f\n', ...
        capacity_data.cycle_idx(i), ...
        capacity_data.capacity_Ah(i), ...
        capacity_data.I_avg(i), ...
        capacity_data.duration_s(i), ...
        capacity_data.V_min(i), ...
        capacity_data.V_max(i));
end

if height(capacity_data) > 10
    fprintf('   ... (%d more cycles)\n', height(capacity_data)-10);
end
fprintf('   ----------------------------------------------------\n');
