%% 1-RC ECM VOLTAGE SIMULATOR
% Simulates terminal voltage for given current profile
%
% Inputs:
%   I         - Current vector (A) - positive = charge, negative = discharge
%   t         - Time vector (s) - same length as I
%   params    - Structure with fields:
%       .R0       - Series resistance (Ω)
%       .R1       - Polarization resistance (Ω)
%       .C1       - Polarization capacitance (F)
%       .Q_nom    - Nominal capacity (Ah)
%       .OCV_SOC  - OCV lookup table [N×2] or structure with .SOC and .OCV
%   SOC0      - Initial state of charge (0-1), default = 1
%
% Outputs:
%   V_sim     - Simulated terminal voltage (V)
%   SOC       - State of charge trajectory
%   V1        - Polarization voltage trajectory
%   struct    - Optional: structure with all internal states
%
% File: matlab/03_ecm_model/sim_ecm_1rc.m

function [V_sim, SOC, V1, debug] = sim_ecm_1rc(I, t, params, SOC0)
    % SIM_ECM_1RC Simulate 1-RC equivalent circuit model
    
    %% ========== INPUT PARSING ==========
    if nargin < 4
        SOC0 = 1.0;  % Default: start fully charged
    end
    
    % Extract parameters
    R0 = params.R0;
    R1 = params.R1;
    C1 = params.C1;
    Q_nom = params.Q_nom;
    
    % Handle OCV lookup table
    if isstruct(params.OCV_SOC)
        % If passed as structure with .SOC and .OCV fields
        SOC_lookup = params.OCV_SOC.SOC;
        OCV_lookup = params.OCV_SOC.OCV;
    else
        % Assume it's an N×2 array [SOC, OCV]
        SOC_lookup = params.OCV_SOC(:,1);
        OCV_lookup = params.OCV_SOC(:,2);
    end
    
    % Ensure inputs are column vectors
    I = I(:);
    t = t(:);
    
    if length(I) ~= length(t)
        error('❌ Current and time vectors must have same length');
    end
    
    N = length(I);
    fprintf('🔧 Simulating 1-RC ECM: %d points, dt = %.3f s\n', N, mean(diff(t)));
    
    %% ========== INITIALIZE ==========
    dt = [0; diff(t)];  % Time steps (first step = 0)
    
    V_sim = zeros(N, 1);
    SOC = zeros(N, 1);
    V1 = zeros(N, 1);
    
    % Initial conditions
    SOC(1) = SOC0;
    V1(1) = 0;  % Assume relaxed at t=0
    
    % Time constant
    tau = R1 * C1;
    fprintf('   τ = %.1f s\n', tau);
    
    %% ========== MAIN SIMULATION LOOP ==========
    fprintf('   Simulating...\n');
    
    for k = 1:N
        % Get OCV at current SOC
        OCV = interp1(SOC_lookup, OCV_lookup, SOC(k), 'linear', 'extrap');
        
        % CHANGED: Terminal voltage: V = OCV - I*R0 - V1
        % I positive for charge, negative for discharge
        V_sim(k) = OCV - abs(I(k)) * R0 - V1(k);
        
        if k < N
            % Time step
            dt_k = dt(k+1);
            
            % CHANGED: SOC update (Coulomb counting)
            % SOC(k+1) = SOC(k) + I*dt / (Q_nom*3600)
            % I positive for charge (increases SOC), negative for discharge (decreases SOC)
            SOC(k+1) = SOC(k) + I(k) * dt_k / (Q_nom * 3600);
            
            % Saturate SOC
            SOC(k+1) = max(min(SOC(k+1), 1), 0);
            
            % RC state update (discrete-time solution)
            % V1(k+1) = exp(-dt/τ) * V1(k) + R1*(1-exp(-dt/τ)) * I(k)
            alpha = exp(-dt_k / tau);
            V1(k+1) = alpha * V1(k) + R1 * (1 - alpha) * I(k);
        end
    end
    
    %% ========== DEBUG STRUCTURE ==========
    if nargout > 3
        debug.params = params;
        debug.SOC0 = SOC0;
        debug.OCV = interp1(SOC_lookup, OCV_lookup, SOC, 'linear', 'extrap');
        debug.IR_drop = I * R0;  % CHANGED: removed abs()
        debug.time = t;
        debug.I = I;
        fprintf('   Debug structure created\n');
    end
    
    fprintf('✅ Simulation complete\n');
end