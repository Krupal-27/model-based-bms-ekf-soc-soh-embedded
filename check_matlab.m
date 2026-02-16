%% BATTERY BMS PROJECT - SANITY CHECK
% FINAL FIXED VERSION - Works with YOUR data structure
% File: matlab/00_setup/check_matlab.m

clear; clc; close all;

%% ========== SET PATHS ==========
username = 'Krupal Babariya';
project_root = ['C:\Users\' username '\Desktop\battery-bms-ecm-soc-soh\'];
cd(project_root);

fprintf('========================================\n');
fprintf('🔋 BATTERY BMS PROJECT - SANITY CHECK\n');
fprintf('========================================\n\n');

%% STEP 1: MATLAB VERSION
fprintf('📊 STEP 1: MATLAB Environment\n');
fprintf('----------------------------------------\n');
v = ver('MATLAB');
fprintf('✅ Version: %s (%s)\n', v.Version, v.Release);
fprintf('📁 Project root: %s\n', project_root);
fprintf('📁 Current folder: %s\n', pwd);
fprintf('\n');

%% STEP 2: LOAD BATTERY DATA
fprintf('📂 STEP 2: Loading Battery Data\n');
fprintf('----------------------------------------\n');

battery_file = fullfile(project_root, 'data/processed/battery_B0005.mat');
load(battery_file, 'BatteryData');

fprintf('✅ Loaded: battery_B0005.mat\n');
fprintf('🔋 Battery ID: %s\n', BatteryData.battery_id);
fprintf('📊 Total cycles: %d\n', length(BatteryData.cycles));
fprintf('📅 Processed: %s\n', BatteryData.info.processed_date);
fprintf('\n');

%% STEP 3: FIND DISCHARGE CYCLE
fprintf('📊 STEP 3: Finding Discharge Cycle\n');
fprintf('----------------------------------------\n');

% Find first discharge cycle
discharge_idx = [];
for i = 1:length(BatteryData.cycles)
    if strcmp(BatteryData.cycles(i).type, 'discharge')
        discharge_idx = i;
        break;
    end
end

if isempty(discharge_idx)
    error('❌ No discharge cycle found!');
end

% Get the discharge data
discharge_data = BatteryData.cycles(discharge_idx).data;
fprintf('✅ Found discharge cycle #%d\n', discharge_idx);
fprintf('📋 Data table: %d rows, %d columns\n', size(discharge_data,1), size(discharge_data,2));
fprintf('📋 Columns: %s\n', strjoin(discharge_data.Properties.VariableNames, ', '));
fprintf('\n');

%% STEP 4: CREATE PLOT
fprintf('📈 STEP 4: Creating Plot\n');
fprintf('----------------------------------------\n');

figure('Name', 'Battery BMS Sanity Check', 'Position', [100, 100, 1200, 800]);

time = discharge_data.Time;
voltage = discharge_data.Voltage_measured;
current = discharge_data.Current_measured;
temp = discharge_data.Temperature_measured;

% Plot 1: Voltage vs Time
subplot(2,2,1);
plot(time, voltage, 'b-', 'LineWidth', 1.5);
xlabel('Time (s)');
ylabel('Voltage (V)');
title('Discharge Voltage');
grid on;
xlim([0, max(time)]);

% Plot 2: Current vs Time
subplot(2,2,2);
plot(time, current, 'r-', 'LineWidth', 1.5);
xlabel('Time (s)');
ylabel('Current (A)');
title('Discharge Current');
grid on;
xlim([0, max(time)]);

% Plot 3: Temperature vs Time
subplot(2,2,3);
plot(time, temp, 'g-', 'LineWidth', 1.5);
xlabel('Time (s)');
ylabel('Temperature (°C)');
title('Battery Temperature');
grid on;
xlim([0, max(time)]);

% Plot 4: Voltage vs Current (V-I characteristic)
subplot(2,2,4);
plot(voltage, current, 'k-', 'LineWidth', 1.5);
xlabel('Voltage (V)');
ylabel('Current (A)');
title('V-I Characteristic');
grid on;

sgtitle(sprintf('Battery %s - Discharge Cycle %d', ...
    BatteryData.battery_id, discharge_idx), 'FontSize', 14, 'FontWeight', 'bold');

fprintf('✅ Plot created successfully!\n');
fprintf('   📊 Voltage, Current, Temperature, V-I\n\n');

%% STEP 5: CYCLE SUMMARY
fprintf('📊 STEP 5: Cycle Summary\n');
fprintf('----------------------------------------\n');

% Count cycle types
n_cycles = length(BatteryData.cycles);
n_discharge = 0;
n_charge = 0;
n_impedance = 0;

for i = 1:n_cycles
    switch BatteryData.cycles(i).type
        case 'discharge'
            n_discharge = n_discharge + 1;
        case 'charge'
            n_charge = n_charge + 1;
        case 'impedance'
            n_impedance = n_impedance + 1;
    end
end

fprintf('🔋 Battery %s cycle breakdown:\n', BatteryData.battery_id);
fprintf('   ⚡ Discharge: %d cycles\n', n_discharge);
fprintf('   🔌 Charge: %d cycles\n', n_charge);
fprintf('   📊 Impedance: %d tests\n', n_impedance);
fprintf('\n');

%% STEP 6: SUMMARY
fprintf('========================================\n');
fprintf('🎉 SANITY CHECK PASSED!\n');
fprintf('========================================\n');
fprintf('✅ MATLAB is ready\n');
fprintf('✅ Battery data is accessible\n');
fprintf('✅ Plotting works\n');
fprintf('✅ You have %d batteries processed\n', length(dir('data/processed/battery_*.mat')));
fprintf('========================================\n');