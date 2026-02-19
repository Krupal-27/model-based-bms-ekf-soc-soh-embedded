%% BATTERY BMS PROJECT - MATLAB SANITY CHECK
% This script verifies your MATLAB setup and teaches the 5 essential skills
% Run this FIRST whenever you start a new session
% File: matlab/00_setup/check_matlab.m

clear; clc; close all;
fprintf('========================================\n');
fprintf('🔋 BATTERY BMS PROJECT - SANITY CHECK\n');
fprintf('========================================\n\n');

%% ========== 1. MATLAB VERSION & PATHS ==========
fprintf('📊 STEP 1: MATLAB Environment Check\n');
fprintf('----------------------------------------\n');

% Print MATLAB version
v = ver('MATLAB');
fprintf('✅ MATLAB Version: %s (%s)\n', v.Version, v.Release);
fprintf('✅ MATLAB Installed: Yes\n');

% Get current folder
current_dir = pwd;
fprintf('📁 Current folder: %s\n', current_dir);

% FIXED: Set project root manually based on your actual path
project_root = 'C:\Users\Krupal Babariya\Desktop\battery-bms-ecm-soc-soh';
fprintf('📁 Project root set to: %s\n', project_root);

% Verify project root exists
if ~exist(project_root, 'dir')
    error('❌ Project root not found at: %s', project_root);
end

% Add project paths (only if not already added)
matlab_path = fullfile(project_root, 'matlab');
if ~contains(path, matlab_path)
    addpath(genpath(matlab_path));
    fprintf('✅ Added MATLAB folders to path\n');
else
    fprintf('⏩ MATLAB folders already in path\n');
end
fprintf('\n');

%% ========== 2. VERIFY DATA FILES ==========
fprintf('📂 STEP 2: Data Files Check\n');
fprintf('----------------------------------------\n');

% FIXED: Use correct processed folder path
processed_path = fullfile(project_root, 'data', 'processed');
fprintf('🔍 Looking for processed data in: %s\n', processed_path);

if ~exist(processed_path, 'dir')
    error('❌ Processed folder not found at:\n   %s\n\nPlease run organize_nasa_by_battery.m first', processed_path);
end

% List all battery files
battery_files = dir(fullfile(processed_path, 'battery_*.mat'));
fprintf('📁 Found %d battery files in data/processed/\n', length(battery_files));

if length(battery_files) == 0
    error('❌ No battery files found! Please run organize_nasa_by_battery.m first');
end

% Pick one battery to test
test_battery = 'B0005';
test_file = fullfile(processed_path, sprintf('battery_%s.mat', test_battery));

if ~exist(test_file, 'file')
    % Pick first available battery
    test_file = fullfile(battery_files(1).folder, battery_files(1).name);
    [~, name] = fileparts(battery_files(1).name);
    test_battery = strrep(name, 'battery_', '');
end

fprintf('✅ Test battery: %s\n', test_battery);
fprintf('📂 Loading: %s\n', test_file);

% Load the battery data
load(test_file, 'BatteryData');

% Check structure fields
fprintf('✅ Loaded successfully\n');
if isfield(BatteryData, 'cycles')
    fprintf('📊 Total cycles: %d\n', length(BatteryData.cycles));
else
    error('❌ BatteryData has no cycles field! Structure may be corrupted.');
end
fprintf('\n');

%% ========== 3. EXPLORE MATLAB TABLES ==========
fprintf('📊 STEP 3: Working with Tables (readtable)\n');
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
    error('❌ No discharge cycle found in battery %s!', test_battery);
end

% Get the discharge data (this is a MATLAB TABLE)
discharge_data = BatteryData.cycles(discharge_idx).data;
fprintf('✅ Found discharge cycle #%d\n', discharge_idx);
fprintf('📋 Table dimensions: %d rows, %d columns\n', size(discharge_data,1), size(discharge_data,2));
fprintf('📋 Column names: %s\n', strjoin(discharge_data.Properties.VariableNames, ', '));

% Display first 3 rows
fprintf('\n📋 First 3 rows of data:\n');
disp(discharge_data(1:min(3, height(discharge_data)), :));
fprintf('\n');

%% ========== 4. EXPLORE MATLAB STRUCTS ==========
fprintf('📦 STEP 4: Working with Structs (S.field)\n');
fprintf('----------------------------------------\n');

% Display BatteryData structure fields
fprintf('📦 BatteryData fields:\n');
fields = fieldnames(BatteryData);
for i = 1:length(fields)
    field_value = BatteryData.(fields{i});
    if isstruct(field_value) || istable(field_value)
        fprintf('   • %s: (%s)\n', fields{i}, class(field_value));
    else
        fprintf('   • %s: %s\n', fields{i}, char(field_value));
    end
end

% Display cycle structure
fprintf('\n🔋 First cycle structure:\n');
if ~isempty(BatteryData.cycles)
    cycle_fields = fieldnames(BatteryData.cycles(1));
    for i = 1:length(cycle_fields)
        value = BatteryData.cycles(1).(cycle_fields{i});
        if isstruct(value) || istable(value)
            fprintf('   • %s: (%s', cycle_fields{i}, class(value));
            if istable(value)
                fprintf(', %dx%d', size(value,1), size(value,2));
            end
            fprintf(')\n');
        elseif ischar(value)
            fprintf('   • %s: %s\n', cycle_fields{i}, value);
        elseif isnumeric(value) && isscalar(value)
            fprintf('   • %s: %g\n', cycle_fields{i}, value);
        else
            fprintf('   • %s: (%s', cycle_fields{i}, class(value));
            if isnumeric(value)
                fprintf(', %s', mat2str(size(value)));
            end
            fprintf(')\n');
        end
    end
end
fprintf('\n');

%% ========== 5. PLOTTING ==========
fprintf('📈 STEP 5: Plotting (plot, subplot)\n');
fprintf('----------------------------------------\n');

% Create figure with subplots
figure('Name', 'Battery BMS - Sanity Check', 'Position', [100, 100, 1200, 800]);

% Get time vector if available
if ismember('Time', discharge_data.Properties.VariableNames)
    time = discharge_data.Time;
else
    time = (1:height(discharge_data))';  % Create index if no time column
end

% Plot 1: Voltage vs Time (discharge)
subplot(2,2,1);
if ismember('Voltage_measured', discharge_data.Properties.VariableNames)
    voltage = discharge_data.Voltage_measured;
    plot(time, voltage, 'b-', 'LineWidth', 1.5);
    xlabel('Time (s)');
    ylabel('Voltage (V)');
    title(sprintf('Battery %s - Discharge Cycle', test_battery));
    grid on;
    if max(time) > 0
        xlim([0, max(time)]);
    end
    ylim([2.7, 4.2]);
else
    text(0.5, 0.5, 'Voltage data not available', 'HorizontalAlignment', 'center');
end

% Plot 2: Current vs Time (discharge)
subplot(2,2,2);
if ismember('Current_measured', discharge_data.Properties.VariableNames)
    current = discharge_data.Current_measured;
    plot(time, current, 'r-', 'LineWidth', 1.5);
    xlabel('Time (s)');
    ylabel('Current (A)');
    title('Discharge Current');
    grid on;
    if max(time) > 0
        xlim([0, max(time)]);
    end
else
    text(0.5, 0.5, 'Current data not available', 'HorizontalAlignment', 'center');
end

% Plot 3: Temperature vs Time
subplot(2,2,3);
if ismember('Temperature_measured', discharge_data.Properties.VariableNames)
    temp = discharge_data.Temperature_measured;
    plot(time, temp, 'g-', 'LineWidth', 1.5);
    xlabel('Time (s)');
    ylabel('Temperature (°C)');
    title('Battery Temperature');
    grid on;
    if max(time) > 0
        xlim([0, max(time)]);
    end
else
    text(0.5, 0.5, 'Temperature data not available', 'HorizontalAlignment', 'center');
end

% Plot 4: Voltage vs Time (zoomed)
subplot(2,2,4);
if ismember('Voltage_measured', discharge_data.Properties.VariableNames)
    plot(time, voltage, 'b-', 'LineWidth', 1.5);
    xlabel('Time (s)');
    ylabel('Voltage (V)');
    title('Voltage vs Time (first 500s)');
    grid on;
    if max(time) > 0
        xlim([0, min(500, max(time))]);
    end
else
    text(0.5, 0.5, 'Data not available', 'HorizontalAlignment', 'center');
end

sgtitle(sprintf('MATLAB Sanity Check - %s', datestr(now)), 'FontSize', 14, 'FontWeight', 'bold');
fprintf('✅ Created figure with 4 subplots\n\n');

%% ========== 6. SAVE & LOAD EXAMPLE ==========
fprintf('💾 STEP 6: Save/Load .mat Files\n');
fprintf('----------------------------------------\n');

% Create a small workspace to save
example_data = discharge_data(1:min(100, height(discharge_data)), :);  % First 100 rows
example_info = struct();
example_info.battery = test_battery;
example_info.cycle = discharge_idx;
example_info.timestamp = datestr(now);

% Save to file
test_save_path = fullfile(processed_path, 'test_save.mat');
save(test_save_path, 'example_data', 'example_info');
fprintf('✅ Saved test file: %s\n', test_save_path);

% Clear and load back
clear example_data example_info;
load(test_save_path, 'example_data', 'example_info');
fprintf('✅ Loaded test file successfully\n');
fprintf('   📊 example_data: %d rows, %d columns\n', size(example_data,1), size(example_data,2));
fprintf('   📝 example_info.battery: %s\n', example_info.battery);
fprintf('   📝 example_info.cycle: %d\n', example_info.cycle);

%% ========== 7. SUMMARY ==========
fprintf('\n========================================\n');
fprintf('🎉 SANITY CHECK PASSED!\n');
fprintf('========================================\n');
fprintf('✅ You have successfully:\n');
fprintf('   1. Checked MATLAB version and paths\n');
fprintf('   2. Verified your organized battery data\n');
fprintf('   3. Worked with TABLES (readtable)\n');
fprintf('   4. Worked with STRUCTS (BatteryData.cycles)\n');
fprintf('   5. Created PLOTS with subplots\n');
fprintf('   6. Saved and loaded .MAT files\n\n');
fprintf('📚 These are ALL the MATLAB skills you need!\n');
fprintf('========================================\n');