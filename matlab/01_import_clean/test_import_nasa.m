%% TEST IMPORT_NASA ON ONE CYCLE
clear; clc; close all;

%% FORCE CORRECT PATH - ADD THIS AT THE VERY TOP
cd('C:\Users\Krupal Babariya\Desktop\battery-bms-ecm-soc-soh\');
fprintf('📁 Working directory: %s\n', pwd);

%% ========== LOAD ONE CYCLE ==========
load('data/processed/battery_B0005.mat', 'BatteryData');

% Find first discharge cycle
for i = 1:length(BatteryData.cycles)
    if strcmp(BatteryData.cycles(i).type, 'discharge')
        raw_data = BatteryData.cycles(i).data;
        cycle_num = i;
        break;
    end
end

fprintf('🔋 Testing on B0005 cycle %d (%s)\n', cycle_num, 'discharge');
fprintf('📊 Raw data: %d rows\n', height(raw_data));

%% ========== CLEAN THE DATA ==========
clean = import_nasa(raw_data, 'discharge');

%% ========== COMPARE BEFORE/AFTER ==========
figure('Name', 'Import NASA Test', 'Position', [100, 100, 1200, 600]);

% Original data
subplot(2,3,1);
plot(raw_data.Time, raw_data.Voltage_measured, 'b.-', 'MarkerSize', 3);
xlabel('Time (s)'); ylabel('Voltage (V)');
title('Original - Raw');
grid on;

subplot(2,3,2);
plot(raw_data.Time, raw_data.Current_measured, 'r.-', 'MarkerSize', 3);
xlabel('Time (s)'); ylabel('Current (A)');
title('Original - Raw');
grid on;

subplot(2,3,3);
plot(raw_data.Time, raw_data.Temperature_measured, 'g.-', 'MarkerSize', 3);
xlabel('Time (s)'); ylabel('Temp (°C)');
title('Original - Raw');
grid on;

% Cleaned data
subplot(2,3,4);
plot(clean.time, clean.V, 'b-', 'LineWidth', 1.5);
xlabel('Time (s)'); ylabel('Voltage (V)');
title('Cleaned - 1s resampled');
grid on;

subplot(2,3,5);
plot(clean.time, clean.I, 'r-', 'LineWidth', 1.5);
xlabel('Time (s)'); ylabel('Current (A)');
title('Cleaned - 1s resampled');
grid on;

subplot(2,3,6);
plot(clean.time, clean.T, 'g-', 'LineWidth', 1.5);
xlabel('Time (s)'); ylabel('Temp (°C)');
title('Cleaned - 1s resampled');
grid on;

sgtitle(sprintf('Import NASA Test - B0005 Cycle %d', cycle_num), ...
    'FontSize', 14, 'FontWeight', 'bold');

%% ========== PRINT STATISTICS ==========
fprintf('\n📊 Cleaning Statistics:\n');
fprintf('   Original points: %d\n', clean.info.original_rows);
fprintf('   Valid points: %d\n', clean.info.valid_rows);
fprintf('   Resampled points: %d\n', clean.info.resampled_rows);
fprintf('   Sampling rate: %.1f Hz\n', 1/clean.info.dt);
fprintf('   Time range: %.1f - %.1f s\n', clean.time(1), clean.time(end));
fprintf('   Voltage range: %.3f - %.3f V\n', min(clean.V), max(clean.V));
fprintf('   Current range: %.3f - %.3f A\n', min(clean.I), max(clean.I));
fprintf('   Temp range: %.1f - %.1f °C\n', min(clean.T), max(clean.T));