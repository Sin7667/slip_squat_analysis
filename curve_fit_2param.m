%% =========================================================================
%  02_curve_fit_2param.m
%  Universal 2-parameter GRF curve fitting  (single spring per leg).
%
%  MODEL:  F_leg = k * (L - L0)
%    k  – leg spring stiffness (N/m)
%    L0 – leg spring rest length (m)
%
%  HOW TO USE
%  ----------
%  1. Set subject_id, trial_key, and grf_file below.
%  2. Place segment .mat files and the GRF .mot file in the working dir.
%  3. Run.  Results are appended to the subject's 2-parameter Excel file.
%
%  INPUTS required in the working directory
%  -----------------------------------------
%  Segment_<prefix><trial_key>_*.mat   – from 01_segmentation.m
%  <grf_file>                           – GRF motion file (.mot)
%
%  OUTPUTS
%  -------
%  <param_file_2p>  (Excel)  – one row per segment with:
%    Cut_Filename, GRF_Filename, Mass_Dyn_kg,
%    k_L_Nm, L0_L_m, R2_L, RMSE_L, N_L,
%    k_R_Nm, L0_R_m, R2_R, RMSE_R, N_R
%  Plots_2Param_<trial_key>/  – one PNG per segment
%% =========================================================================

clc; clear; close all;

%% --- USER SETTINGS -------------------------------------------------------
subject_id = 14;
trial_key  = 'E3';   % 'E1' | 'E2' | 'E3'
grf_file   = 'S14_E3_T1_001_GRF.mot';
%% ------------------------------------------------------------------------

addpath(fullfile(fileparts(mfilename('fullpath')), 'config'));
addpath(fullfile(fileparts(mfilename('fullpath')), 'functions'));
cfg = get_subject_config(subject_id);

excel_file  = cfg.param_file_2p;
plot_folder = ['Plots_2Param_' trial_key];
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
    % Last numeric token before extension is the start time
    for pi = numel(parts):-1:1
        val = str2double(strrep(parts{pi}, '.mat', ''));
        if ~isnan(val)
            start_times(k) = val;
            break;
        end
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
        %% Load segment
        S = load(seg_file);
        if isfield(S, 'Segment')
            C = S.Segment;
        elseif isfield(S, 'Schnitt')
            C = S.Schnitt;   % backwards compatibility
        else
            error('No Segment or Schnitt struct found in %s.', seg_file);
        end
        t_ref = C.time_abs;

        %% Interpolate GRF onto segment time
        GRF_i = interp1(GRF_raw.data(:,1), GRF_raw.data(:,2:end), ...
                        t_ref, 'linear', 'extrap');
        % GRF column layout (OpenSim standard):
        % 1-3: ground_force_r (Fx,Fy,Fz), 4-6: ground_torque_r,
        % 7-9: ground_force_l (Fx,Fy,Fz), 10-12: ground_torque_l
        Fx_R = GRF_i(:,1);  Fy_R = GRF_i(:,2);
        Fx_L = GRF_i(:,7);  Fy_L = GRF_i(:,8);

        %% Leg lengths and projected forces
        dx_R = C.COMX - C.XFootRight;
        dx_L = C.COMX - C.XFootLeft;
        dy   = C.COMY;
        L_R  = hypot(dx_R, dy);
        L_L  = hypot(dx_L, dy);

        uRx = dx_R ./ L_R;  uRy = dy ./ L_R;
        uLx = dx_L ./ L_L;  uLy = dy ./ L_L;

        F_leg_R = Fx_R .* uRx + Fy_R .* uRy;
        F_leg_L = Fx_L .* uLx + Fy_L .* uLy;

        %% Curve fitting with plot
        hFig = figure('Visible', 'off', 'Color', 'w', 'Position', [0 0 1000 480]);
        sgtitle(seg_file, 'Interpreter', 'none');

        ax_L = subplot(1, 2, 1);
        title(ax_L, 'Left Leg');
        [k_L, L0_L, R2_L, rmse_L, n_L] = analyze_leg_2param(L_L, F_leg_L, ax_L);
        if isnan(k_L)
            text(ax_L, 0.5, 0.5, 'Too few valid points', ...
                 'HorizontalAlignment', 'center', 'Units', 'normalized');
        end

        ax_R = subplot(1, 2, 2);
        title(ax_R, 'Right Leg');
        [k_R, L0_R, R2_R, rmse_R, n_R] = analyze_leg_2param(L_R, F_leg_R, ax_R);
        if isnan(k_R)
            text(ax_R, 0.5, 0.5, 'Too few valid points', ...
                 'HorizontalAlignment', 'center', 'Units', 'normalized');
        end

        set(hFig, 'InvertHardcopy', 'off');
        saveas(hFig, fullfile(plot_folder, strrep(seg_file, '.mat', '.png')));
        close(hFig);

        %% Dynamic mass estimate
        g     = 9.81;
        Fy_sum = Fy_R + Fy_L;
        Vy_f   = sgolayfilt(C.Vy, 3, 21);
        a_y    = gradient(Vy_f, t_ref);
        valid_m = isfinite(Fy_sum) & abs(Fy_sum) > 50;
        if nnz(valid_m) > 5
            m_dyn = median(Fy_sum(valid_m) ./ (g + a_y(valid_m)));
        else
            m_dyn = NaN;
        end

        %% Collect result row
        row = table(string(seg_file), string(grf_file), m_dyn, ...
                    k_L,  L0_L,  R2_L,  rmse_L,  n_L, ...
                    k_R,  L0_R,  R2_R,  rmse_R,  n_R, ...
            'VariableNames', { ...
                'Cut_Filename', 'GRF_Filename', 'Mass_Dyn_kg', ...
                'k_L_Nm', 'L0_L_m', 'R2_L', 'RMSE_L', 'N_L', ...
                'k_R_Nm', 'L0_R_m', 'R2_R', 'RMSE_R', 'N_R'});

        all_results = [all_results; row]; %#ok<AGROW>

    catch ME
        fprintf('  ERROR in %s: %s\n', seg_file, ME.message);
    end
end
close(h_wait);

%% --- Save Excel ----------------------------------------------------------
if isempty(all_results)
    warning('No results were produced.');
else
    log_to_excel(excel_file, all_results);
    fprintf('Results saved to: %s\n', excel_file);
    fprintf('Plots saved to:   %s/\n', plot_folder);
end
