%% COULOMB COUNTING SOC ESTIMATION
% Simple current integration with bias correction and clamping
%
% Inputs:
%   I         - Current vector (A) - positive charge, negative discharge
%   t         - Time vector (s)
%   Q_nom     - Nominal capacity (Ah)
%   SOC0      - Initial SOC (0-1), default = 1
%   I_bias    - Current sensor bias (A), default = 0
%
% Outputs:
%   SOC       - State of Charge trajectory (0-1)
%   Q_removed - Cumulative charge removed (Ah)
%   info      - Structure with additional info
%
% File: matlab/06_soc_estimation/soc_coulomb.m

function [SOC, Q_removed, info] = soc_coulomb(I, t, Q_nom, SOC0, I_bias)
    % SOC_COULOMB Coulomb counting SOC estimation with bias correction
    
    %% INPUT PARSING
    if nargin < 4 || isempty(SOC0)
        SOC0 = 1.0;
    end
    
    if nargin < 5 || isempty(I_bias)
        I_bias = 0;
    end
    
    I = I(:);
    t = t(:);
    
    if length(I) ~= length(t)
        error('Current and time vectors must have same length');
    end
    
    N = length(I);
    
    %% CALCULATE TIME STEPS
    dt = [0; diff(t)];
    
    %% APPLY BIAS CORRECTION
    I_corrected = I - I_bias;
    
    I_threshold = 0.01;
    I_corrected(abs(I_corrected) < I_threshold) = 0;
    
    %% COULOMB COUNTING
    dQ = I_corrected .* dt;
    
    dQ_Ah = dQ / 3600;
    Q_removed = cumsum(-dQ_Ah);
    
    SOC = SOC0 - Q_removed / Q_nom;
    
    %% CLAMP SOC TO [0, 1]
    SOC = max(min(SOC, 1), 0);
    
    %% CREATE INFO STRUCTURE
    info = struct();
    info.method = 'Coulomb counting';
    info.Q_nom = Q_nom;
    info.SOC0 = SOC0;
    info.I_bias = I_bias;
    info.I_corrected = I_corrected;
    info.dQ_Ah = dQ_Ah;
    info.Q_removed_cumulative = Q_removed;
    info.final_SOC = SOC(end);
    info.total_capacity_used = Q_removed(end);
    info.charge_transferred = sum(dQ_Ah(dQ_Ah > 0));
    info.discharge_transferred = -sum(dQ_Ah(dQ_Ah < 0));
    
    fprintf('Coulomb Counting SOC:\n');
    fprintf('   Initial SOC: %.3f\n', SOC0);
    fprintf('   Final SOC: %.3f\n', SOC(end));
    fprintf('   Capacity used: %.3f Ah\n', Q_removed(end));
    fprintf('   Bias correction: %.3f A\n', I_bias);
    
end
