%% =========================================================================
%  03_curve_fit_4param.m
%  Universal 4-parameter GRF curve fitting  (separate flexion / extension).
%
%  MODEL:  F_leg = k_phase * (L - L0_phase)   for each phase
%    k_flex,  L0_flex  – spring stiffness/rest-length during flexion
%    k_ext,   L0_ext   – spring stiffness/rest-length during extension
%
%  The split point is the moment of maximum leg compression (min(L)).
%  Energy dissipation (hysteresis) is also computed from both raw data
%  and from the fitted model curves.
%
%  HOW TO USE
%  ----------
%  1. Set subject_id, trial_key, and grf_file.
%  2. Run.  Results appended to the 4-parameter Excel file.
%
%  OUTPUTS
%  -------
%  <param_file_4p>  (Excel) – one row per segment:
%    Cut_Filename, GRF_Filename, Mass_Dyn_kg,
%    k_L_Flex, L0_L_Flex, k_L_Ext, L0_L_Ext, E_diss_L_Raw, E_diss_L_Fit,
%    k_R_Flex, L0_R_Flex, k_R_Ext, L0_R_Ext, E_diss_R_Raw, E_diss_R_Fit
%  Plots_4Param_<trial_key>/  – one PNG per segment
%% =========================================================================

clc; clear; close all;

%% --- USER SETTINGS -------------------------------------------------------
subject_id = 14;
trial_key  = 'E1';
grf_file   = 'S14_E1_T1_001_GRF.mot';
%% -------------------------------------------------------------------------

addpath(fullfile(fileparts(mfilename('fullpath')), 'config'));
addpath(fullfile(fileparts(mfilename('fullpath')), 'functions'));
cfg = get_subject_config(subject_id);

excel_file  = cfg.param_file_4p;
plot_folder = ['Plots_4Param_' trial_key];
if ~exist(plot_folder, 'dir'), mkdir(plot_folder); end

%% --- Locate segment files ------------------------------------------------
seg_pattern = ['Segment_' cfg.segment_prefix trial_key '_*.mat'];
file_list   = dir(seg_pattern);
if isempty(file_list)
    error('No segment files found matching: %s', seg_pattern);
end

% Sort by start time
start_times = zeros(numel(file_list), 1);
for k = 1:numel(file_list)
    parts = strsplit(file_list(k).name, '_');
    for pi = numel(parts):-1:1
        val = str2double(strrep(parts{pi}, '.mat', ''));
        if ~isnan(val), start_times(k) = val; break; end
    end
end
[~, sort_idx] = sort(start_times);
file_list = file_list(sort_idx);

fprintf('Processing %d segment file(s) for %s %s ...\n', ...
        numel(file_list), cfg.subject_tag, trial_key);

%% --- Load GRF file -------------------------------------------------------
GRF_raw = read_motionFile(grf_file);

%% --- Batch loop ----------------------------------------------------------
all_results = table();
h_wait = waitbar(0, 'Processing segments...');

for i = 1:numel(file_list)
    seg_file = file_list(i).name;
    waitbar(i / numel(file_list), h_wait, ...
            sprintf('Segment %d / %d', i, numel(file_list)));
    try
        S = load(seg_file);
        C = select_struct(S);
        t_ref = C.time_abs;

        GRF_i = interp1(GRF_raw.data(:,1), GRF_raw.data(:,2:end), ...
                        t_ref, 'linear', 'extrap');
        Fx_R = GRF_i(:,1);  Fy_R = GRF_i(:,2);
        Fx_L = GRF_i(:,7);  Fy_L = GRF_i(:,8);

        dx_R = C.COMX - C.XFootRight;
        dx_L = C.COMX - C.XFootLeft;
        dy   = C.COMY;
        L_R  = hypot(dx_R, dy);
        L_L  = hypot(dx_L, dy);
        uRx = dx_R ./ L_R;  uRy = dy ./ L_R;
        uLx = dx_L ./ L_L;  uLy = dy ./ L_L;
        F_leg_R = Fx_R .* uRx + Fy_R .* uRy;
        F_leg_L = Fx_L .* uLx + Fy_L .* uLy;

        %% Plot & analyse
        hFig = figure('Visible', 'off', 'Color', 'w', 'Position', [0 0 1400 580]);
        tlo  = tiledlayout(1, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
        title(tlo, ['4-Param: ' seg_file], 'Interpreter', 'none');

        nexttile;
        Res_L = analyze_leg_4param(L_L, F_leg_L, gca, 'Left Leg');

        nexttile;
        Res_R = analyze_leg_4param(L_R, F_leg_R, gca, 'Right Leg');

        exportgraphics(hFig, ...
                       fullfile(plot_folder, strrep(seg_file, '.mat', '.png')), ...
                       'Resolution', 150);
        close(hFig);

        %% Dynamic mass
        g      = 9.81;
        Fy_sum = Fy_R + Fy_L;
        Vy_f   = sgolayfilt(C.Vy, 3, 21);
        a_y    = gradient(Vy_f, t_ref);
        valid_m = isfinite(Fy_sum) & abs(Fy_sum) > 50;
        if nnz(valid_m) > 5
            m_dyn = median(Fy_sum(valid_m) ./ (g + a_y(valid_m)));
        else
            m_dyn = NaN;
        end

        row = table(string(seg_file), string(grf_file), m_dyn, ...
                    Res_L.k_flex, Res_L.L0_flex, Res_L.k_ext, Res_L.L0_ext, ...
                    Res_L.E_diss_raw, Res_L.E_diss_fit, ...
                    Res_R.k_flex, Res_R.L0_flex, Res_R.k_ext, Res_R.L0_ext, ...
                    Res_R.E_diss_raw, Res_R.E_diss_fit, ...
            'VariableNames', { ...
                'Cut_Filename', 'GRF_Filename', 'Mass_Dyn_kg', ...
                'k_L_Flex', 'L0_L_Flex', 'k_L_Ext', 'L0_L_Ext', ...
                'E_diss_L_Raw', 'E_diss_L_Fit', ...
                'k_R_Flex', 'L0_R_Flex', 'k_R_Ext', 'L0_R_Ext', ...
                'E_diss_R_Raw', 'E_diss_R_Fit'});

        all_results = [all_results; row]; %#ok<AGROW>

    catch ME
        fprintf('  ERROR in %s: %s\n', seg_file, ME.message);
    end
end
close(h_wait);

%% --- Save ----------------------------------------------------------------
if ~isempty(all_results)
    log_to_excel(excel_file, all_results);
    fprintf('Results saved to: %s\n', excel_file);
    fprintf('Plots saved to:   %s/\n', plot_folder);
end

%% =========================================================================
function C = select_struct(S)
% Return the kinematics struct regardless of field name (Segment or Schnitt)
if isfield(S, 'Segment')
    C = S.Segment;
elseif isfield(S, 'Schnitt')
    C = S.Schnitt;
else
    error('No Segment or Schnitt struct found in loaded file.');
end
end
