%% SEGMENT BATTERY CYCLES FROM CONTINUOUS DATA
% Detects discharge and charge cycles based on current threshold
% Groups consecutive samples of same type into cycles
%
% Input: 
%   clean_data - struct with fields:
%       .time - time vector (s)
%       .I    - current vector (A)
%       .V    - voltage vector (V)
%       .T    - temperature vector (C)
%       .step - cell array of labels
%
% Output:
%   cycles - struct array with segmented cycles
%
% File: matlab/02_cycle_segmentation/segment_cycles.m

function cycles = segment_cycles(clean_data, I_thr)
    % SEGMENT_CYCLES Split continuous data into individual cycles
    %
    % Inputs:
    %   clean_data - struct with .time, .I, .V, .T, .step
    %   I_thr      - current threshold for detection (default 0.1A)
    %
    % Output:
    %   cycles     - struct array with fields:
    %       .type       - 'discharge', 'charge', or 'rest'
    %       .start_idx  - start index in original data
    %       .end_idx    - end index in original data
    %       .time       - time vector (s)
    %       .I          - current vector (A)
    %       .V          - voltage vector (V)
    %       .T          - temperature vector (C)
    %       .duration   - cycle duration (s)
    %       .I_avg      - average current (A)
    %       .V_min      - minimum voltage (V)
    %       .V_max      - maximum voltage (V)
    %       .Q          - capacity (Ah) for discharge cycles
    
    %% STEP 1: SET DEFAULTS
    if nargin < 2
        I_thr = 0.1;
    end
    
    fprintf('Segmenting cycles (I_thr = +/- %.2f A)...\n', I_thr);
    
    %% STEP 2: DETECT CYCLE STATES
    I = clean_data.I;
    time = clean_data.time;
    V = clean_data.V;
    T = clean_data.T;
    
    state = zeros(length(I), 1);
    
    state(I < -I_thr) = 1;
    state(I > I_thr) = 2;
    state(state == 0) = 3;
    
    %% STEP 3: FIND TRANSITIONS
    transitions = [1; find(diff(state) ~= 0) + 1; length(state) + 1];
    
    fprintf('   Found %d state transitions\n', length(transitions)-1);
    
    %% STEP 4: GROUP INTO CYCLES
    cycles = struct();
    cycle_count = 0;
    
    for i = 1:length(transitions)-1
        start_idx = transitions(i);
        end_idx = transitions(i+1) - 1;
        
        if end_idx - start_idx < 5
            continue;
        end
        
        current_state = state(start_idx);
        
        switch current_state
            case 1
                type = 'discharge';
            case 2
                type = 'charge';
            case 3
                type = 'rest';
        end
        
        cycle_count = cycle_count + 1;
        
        cycles(cycle_count).type = type;
        cycles(cycle_count).start_idx = start_idx;
        cycles(cycle_count).end_idx = end_idx;
        cycles(cycle_count).time = time(start_idx:end_idx) - time(start_idx);
        cycles(cycle_count).I = I(start_idx:end_idx);
        cycles(cycle_count).V = V(start_idx:end_idx);
        cycles(cycle_count).T = T(start_idx:end_idx);
        
        cycles(cycle_count).duration = time(end_idx) - time(start_idx);
        cycles(cycle_count).I_avg = mean(I(start_idx:end_idx));
        cycles(cycle_count).V_min = min(V(start_idx:end_idx));
        cycles(cycle_count).V_max = max(V(start_idx:end_idx));
        
        if strcmp(type, 'discharge')
            dt = mean(diff(time(start_idx:end_idx)));
            cycles(cycle_count).Q = sum(abs(I(start_idx:end_idx))) * dt / 3600;
        elseif strcmp(type, 'charge')
            dt = mean(diff(time(start_idx:end_idx)));
            cycles(cycle_count).Q = sum(I(start_idx:end_idx)) * dt / 3600;
        end
    end
    
    fprintf('   Extracted %d cycles (%d discharge, %d charge, %d rest)\n', ...
        cycle_count, ...
        sum(strcmp({cycles.type}, 'discharge')), ...
        sum(strcmp({cycles.type}, 'charge')), ...
        sum(strcmp({cycles.type}, 'rest')));
    
end
