%% SAVE SEGMENTED CYCLES WITH CELL NAMING CONVENTION
% Converts battery IDs to cell numbers and saves as cellXX_cycles.mat
%
% NASA ID → Cell Number mapping:
%   B0005 → cell01
%   B0006 → cell02
%   B0007 → cell03
%   B0018 → cell04
%   B0025 → cell05
%   ... etc

function save_cell_cycles(battery_id, cycles)
    % SAVE_CELL_CYCLES Save cycles with cell naming convention
    %
    % Inputs:
    %   battery_id - string, e.g., 'B0005'
    %   cycles     - struct array of segmented cycles
    
    %% ========== MAP BATTERY ID TO CELL NUMBER ==========
    % NASA dataset battery mapping
    battery_map = containers.Map();
    battery_map('B0005') = '01';
    battery_map('B0006') = '02';
    battery_map('B0007') = '03';
    battery_map('B0018') = '04';
    battery_map('B0025') = '05';
    battery_map('B0026') = '06';
    battery_map('B0027') = '07';
    battery_map('B0028') = '08';
    battery_map('B0029') = '09';
    battery_map('B0030') = '10';
    battery_map('B0031') = '11';
    battery_map('B0032') = '12';
    battery_map('B0033') = '13';
    battery_map('B0034') = '14';
    battery_map('B0036') = '15';
    battery_map('B0038') = '16';
    battery_map('B0039') = '17';
    battery_map('B0040') = '18';
    battery_map('B0041') = '19';
    battery_map('B0042') = '20';
    battery_map('B0043') = '21';
    battery_map('B0044') = '22';
    battery_map('B0045') = '23';
    battery_map('B0046') = '24';
    battery_map('B0047') = '25';
    battery_map('B0048') = '26';
    battery_map('B0049') = '27';
    battery_map('B0050') = '28';
    battery_map('B0051') = '29';
    battery_map('B0052') = '30';
    battery_map('B0053') = '31';
    battery_map('B0054') = '32';
    battery_map('B0055') = '33';
    battery_map('B0056') = '34';
    
    % Get cell number
    if isKey(battery_map, battery_id)
        cell_num = battery_map(battery_id);
        cell_name = sprintf('cell%s', cell_num);
    else
        % Fallback: use battery_id directly
        cell_name = lower(battery_id);
        fprintf('⚠️  No mapping for %s, using %s\n', battery_id, cell_name);
    end
    
    %% ========== SAVE WITH CELL NAMING ==========
    filename = sprintf('%s_cycles.mat', cell_name);
    filepath = fullfile('data/processed', filename);
    
    save(filepath, 'cycles');
    fprintf('✅ Saved: %s → %s\n', battery_id, filename);
    
    % Also save a copy with battery_id for backward compatibility
    backup_filename = sprintf('%s_segmented_cycles.mat', battery_id);
    backup_path = fullfile('data/processed', backup_filename);
    save(backup_path, 'cycles');
end