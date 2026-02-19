%% COMPUTE CAPACITY FOR ALL DISCHARGE CYCLES
% Calculates capacity (Ah) for each discharge cycle using Coulomb counting
% Q = ∫|I(t)|dt / 3600
%
% Input:  cycles struct array from segmentation
% Output: capacity_data struct with:
%           .cycle_index    - cycle number
%           .Q              - capacity (Ah)
%           .I_avg          - average current (A)
%           .duration       - discharge duration (s)
%           .V_min, V_max   - voltage range
%           .timestamp      - relative time of cycle
%
% File: matlab/02_cycle_segmentation/compute_capacity.m

function capacity_data = compute_capacity(cycles, battery_id)
    % COMPUTE_CAPACITY Calculate capacity for all discharge cycles
    %
    % Inputs:
    %   cycles      - struct array from segment_cycles.m
    %   battery_id  - string, e.g., 'B0005' or 'cell01'
    %
    % Output:
    %   capacity_data - table with columns:
    %       cycle_idx, capacity_Ah, I_avg, duration, V_min, V_max, timestamp
    
    %% ========== FIND ALL DISCHARGE CYCLES ==========
    discharge_idx = find(strcmp({cycles.type}, 'discharge'));
    
    if isempty(discharge_idx)
        error('❌ No discharge cycles found for %s', battery_id);
    end
    
    fprintf('🔋 %s: Computing capacity for %d discharge cycles...\n', ...
        battery_id, length(discharge_idx));
    
    %% ========== INITIALIZE CAPACITY ARRAY ==========
    n_cycles = length(discharge_idx);
    cycle_numbers = 1:n_cycles;
    capacities = zeros(n_cycles, 1);
    I_avg = zeros(n_cycles, 1);
    durations = zeros(n_cycles, 1);
    V_min = zeros(n_cycles, 1);
    V_max = zeros(n_cycles, 1);
    timestamps = zeros(n_cycles, 1);
    
    %% ========== COMPUTE CAPACITY FOR EACH CYCLE ==========
    for i = 1:n_cycles
        idx = discharge_idx(i);
        cycle = cycles(idx);
        
        % Get time and current
        t = cycle.time;
        I = cycle.I;
        
        % Calculate time step (should be constant 1s from our resampling)
        dt = mean(diff(t));
        
        % Coulomb counting: Q = ∫|I|dt / 3600 (Ah)
        % I is negative for discharge, so we take absolute value
        Q = sum(abs(I)) * dt / 3600;
        
        % Store values
        capacities(i) = Q;
        I_avg(i) = abs(cycle.I_avg);  % Store as positive value
        durations(i) = cycle.duration;
        V_min(i) = cycle.V_min;
        V_max(i) = cycle.V_max;
        
        % Approximate timestamp (cumulative time from first cycle)
        if i == 1
            timestamps(i) = 0;
        else
            timestamps(i) = timestamps(i-1) + durations(i-1);
        end
        
        fprintf('   Cycle %3d: Q = %.3f Ah, I_avg = %.3f A, Dur = %.0f s\n', ...
            i, Q, abs(cycle.I_avg), cycle.duration);
    end
    
    %% ========== CREATE OUTPUT TABLE ==========
    capacity_data = table();
    capacity_data.cycle_idx = cycle_numbers';
    capacity_data.capacity_Ah = capacities;
    capacity_data.I_avg = I_avg;
    capacity_data.duration_s = durations;
    capacity_data.V_min = V_min;
    capacity_data.V_max = V_max;
    capacity_data.timestamp_s = timestamps;
    capacity_data.battery_id = repmat({battery_id}, n_cycles, 1);
    
    %% ========== ADD METADATA ==========
    fprintf('\n   📊 Summary for %s:\n', battery_id);
    fprintf('      Initial capacity: %.3f Ah\n', capacities(1));
    fprintf('      Final capacity: %.3f Ah\n', capacities(end));
    fprintf('      Capacity fade: %.1f%%\n', ...
        (1 - capacities(end)/capacities(1)) * 100);
    fprintf('      Total cycles: %d\n', n_cycles);
    fprintf('      Total discharge time: %.1f hours\n', sum(durations)/3600);
    
end