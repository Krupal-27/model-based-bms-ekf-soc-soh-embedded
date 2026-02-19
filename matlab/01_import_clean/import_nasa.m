%% IMPORT AND CLEAN NASA BATTERY DATA
% Converts raw cycle data to clean, resampled format
% FIXED VERSION - Handles flexible column names
%
% File: matlab/01_import_clean/import_nasa.m

function clean_data = import_nasa(raw_data, cycle_type)
    % IMPORT_NASA Clean and resample NASA battery cycle data
    %
    % Inputs:
    %   raw_data    - MATLAB table from NASA CSV file
    %   cycle_type  - string: 'charge', 'discharge', or 'impedance'
    %
    % Output:
    %   clean_data  - struct with cleaned, resampled data
    
    fprintf('   🔧 Cleaning %s cycle...\n', cycle_type);
    
    %% ========== STEP 1: VERIFY INPUT ==========
    if ~istable(raw_data)
        error('❌ raw_data must be a table');
    end
    
    % Make a copy to avoid modifying original
    data = raw_data;
    
    % Remove any rows that are completely NaN
    data = rmmissing(data);
    
    %% ========== STEP 2: FIND TIME COLUMN (FLEXIBLE) ==========
    % Get all column names
    col_names = data.Properties.VariableNames;
    col_names_lower = lower(col_names);
    
    % Look for time column (case-insensitive)
    time_idx = find(strcmpi(col_names, 'time'), 1);
    
    if isempty(time_idx)
        % Try alternative names
        alt_names = {'time_s', 't', 'timestamp', 'seconds', 't_s'};
        for i = 1:length(alt_names)
            time_idx = find(strcmpi(col_names, alt_names{i}), 1);
            if ~isempty(time_idx)
                break;
            end
        end
    end
    
    if isempty(time_idx)
        error('❌ No time column found. Available columns: %s', ...
            strjoin(col_names, ', '));
    end
    
    % Extract time data
    time_raw = data{:, time_idx};
    
    % Convert to double if needed
    if ~isfloat(time_raw)
        time_raw = double(time_raw);
    end
    
    % Sort by time (just in case)
    [time_raw, sort_idx] = sort(time_raw);
    data = data(sort_idx, :);
    
    %% ========== STEP 3: EXTRACT VOLTAGE (FLEXIBLE) ==========
    V_raw = [];
    
    if strcmpi(cycle_type, 'charge')
        % Try charge-specific voltage columns first
        voltage_cols = {'Voltage_measured', 'Voltage_charge', 'voltage', 'v'};
    else
        % Discharge or impedance
        voltage_cols = {'Voltage_measured', 'Voltage_load', 'voltage', 'v'};
    end
    
    for i = 1:length(voltage_cols)
        idx = find(strcmpi(col_names, voltage_cols{i}), 1);
        if ~isempty(idx)
            V_raw = data{:, idx};
            break;
        end
    end
    
    if isempty(V_raw)
        error('❌ No voltage column found. Available columns: %s', ...
            strjoin(col_names, ', '));
    end
    
    V_raw = double(V_raw);
    
    %% ========== STEP 4: EXTRACT CURRENT (FLEXIBLE) ==========
    I_raw = [];
    
    if strcmpi(cycle_type, 'charge')
        % Charge cycle - try charge-specific columns
        current_cols = {'Current_measured', 'Current_charge', 'current', 'i'};
    elseif strcmpi(cycle_type, 'discharge')
        % Discharge cycle - try discharge-specific columns
        current_cols = {'Current_measured', 'Current_load', 'current', 'i'};
    else
        % Impedance
        current_cols = {'Current_measured', 'current', 'i'};
    end
    
    for i = 1:length(current_cols)
        idx = find(strcmpi(col_names, current_cols{i}), 1);
        if ~isempty(idx)
            I_raw = data{:, idx};
            break;
        end
    end
    
    if isempty(I_raw)
        if strcmpi(cycle_type, 'impedance')
            I_raw = zeros(size(V_raw));
            fprintf('   ⚠️  No current data, using zeros\n');
        else
            error('❌ No current column found. Available columns: %s', ...
                strjoin(col_names, ', '));
        end
    end
    
    I_raw = double(I_raw);
    
    % Apply sign convention
    if strcmpi(cycle_type, 'charge')
        I_raw = abs(I_raw);  % Positive for charge
    elseif strcmpi(cycle_type, 'discharge')
        I_raw = -abs(I_raw); % Negative for discharge
    end
    
    %% ========== STEP 5: EXTRACT TEMPERATURE (FLEXIBLE) ==========
    T_raw = [];
    
    temp_cols = {'Temperature_measured', 'temperature', 'temp', 't_c', 't_celsius'};
    for i = 1:length(temp_cols)
        idx = find(strcmpi(col_names, temp_cols{i}), 1);
        if ~isempty(idx)
            T_raw = data{:, idx};
            break;
        end
    end
    
    if isempty(T_raw)
        T_raw = 25 * ones(size(V_raw));  % Default 25°C
        fprintf('   ⚠️  No temperature data, using 25°C\n');
    else
        T_raw = double(T_raw);
    end
    
    %% ========== STEP 6: REMOVE NANS AND INF ==========
    valid_idx = isfinite(time_raw) & isfinite(V_raw) & ...
                isfinite(I_raw) & isfinite(T_raw);
    
    time_raw = time_raw(valid_idx);
    V_raw = V_raw(valid_idx);
    I_raw = I_raw(valid_idx);
    T_raw = T_raw(valid_idx);
    
    if length(time_raw) < 2
        error('❌ Insufficient valid data points (need at least 2)');
    end
    
    %% ========== STEP 7: RESAMPLE TO CONSTANT DT ==========
    dt = 1.0;  % Target: 1 second sampling
    
    % Create new time vector
    t_start = floor(time_raw(1));
    t_end = ceil(time_raw(end));
    time_new = (t_start:dt:t_end)';
    
    % Interpolate all signals
    try
        V_new = interp1(time_raw, V_raw, time_new, 'linear', 'extrap');
        I_new = interp1(time_raw, I_raw, time_new, 'linear', 'extrap');
        T_new = interp1(time_raw, T_raw, time_new, 'linear', 'extrap');
    catch ME
        error('Interpolation failed: %s', ME.message);
    end
    
    %% ========== STEP 8: CREATE CLEAN STRUCTURE ==========
    clean_data = struct();
    clean_data.time = time_new;
    clean_data.V = V_new;
    clean_data.I = I_new;
    clean_data.T = T_new;
    clean_data.step = repmat({cycle_type}, length(time_new), 1);
    
    % Add metadata
    clean_data.info.original_rows = height(data);
    clean_data.info.valid_rows = sum(valid_idx);
    clean_data.info.resampled_rows = length(time_new);
    clean_data.info.dt = dt;
    clean_data.info.cycle_type = cycle_type;
    clean_data.info.processed_date = datestr(now);
    clean_data.info.time_column = col_names{time_idx};
    clean_data.info.voltage_column = col_names{find(strcmpi(col_names, voltage_cols{find(~cellfun(@isempty, {V_raw}))}), 1)};
    
    %% ========== STEP 9: QUALITY CHECKS ==========
    % Check for monotonic time
    if any(diff(time_new) <= 0)
        warning('⚠️  Non-monotonic time after resampling');
    end
    
    % Check voltage range (2.5V - 4.2V for Li-ion)
    if any(V_new < 2.0) || any(V_new > 4.5)
        warning('⚠️  Voltage outside expected range (2.0-4.5V)');
    end
    
    % Check temperature range
    if any(T_new < -20) || any(T_new > 80)
        warning('⚠️  Temperature outside expected range (-20 to 80°C)');
    end
    
    fprintf('   ✅ Cleaned: %d -> %d points (%.1f Hz)\n', ...
        length(time_raw), length(time_new), 1/dt);
    
end