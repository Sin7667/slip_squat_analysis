%% =========================================================================
%  01_segmentation.m
%  Detects and saves ALL squat cycles for one subject and one trial.
%
%  WHAT IT DOES
%  ------------
%  Loads the BodyKinematics pos/vel files, detects every downward-then-
%  upward threshold crossing of the torso_Y signal, and saves each
%  complete cycle as its own Segment_*.mat file (~10 files per trial).
%
%  HOW TO USE
%  ----------
%  1. Set subject_id and trial_key below.
%  2. Place the corresponding .sto files in the MATLAB working directory.
%  3. Run.  All detected cycles are saved automatically.
%
%  The kinematics filenames are detected automatically using the naming
%  pattern stored in get_subject_config (cfg.kin_prefix):
%    S13  → S13_E1_T1_*BodyKinematics_pos_global.sto
%    S14  → S14_E1_T1_*BodyKinematics_pos_global.sto
%    S15  → E1_T1_*BodyKinematics_pos_global.sto
%    S16  → E1_T1_*BodyKinematics_pos_global.sto
%
%  OUTPUTS  (one file per detected cycle)
%  -------
%  Segment_<prefix><trial>_<t0>_<t1>.mat  containing struct 'Segment':
%    .time_abs    absolute time vector (s)
%    .time_rel    time relative to segment start (s)
%    .COMX        COM sagittal position (m)
%    .COMY        COM vertical position (m)
%    .Vx          COM sagittal velocity (m/s)
%    .Vy          COM vertical velocity (m/s)
%    .XFootRight  right calcaneus sagittal position (m)
%    .XFootLeft   left  calcaneus sagittal position (m)
%    .torso_Y     torso vertical position (m)
%% =========================================================================

clc; clear; close all;

%% --- USER SETTINGS -------------------------------------------------------
subject_id = 14;    % 13 | 14 | 15 | 16
trial_key  = 'E3';  % 'E1' | 'E2' | 'E3'
%% -------------------------------------------------------------------------

addpath(fullfile(fileparts(mfilename('fullpath')), 'config'));
addpath(fullfile(fileparts(mfilename('fullpath')), 'functions'));
cfg = get_subject_config(subject_id);

threshold = cfg.threshold.(trial_key);
ax_label  = cfg.forward_axis;   % always 'X'

fprintf('Subject %s | Trial %s | Threshold = %.3f m\n', ...
        cfg.subject_tag, trial_key, threshold);

%% --- Auto-detect kinematics files ----------------------------------------
pos_pattern = [cfg.kin_prefix trial_key '_T1_*BodyKinematics_pos_global.sto'];
vel_pattern = [cfg.kin_prefix trial_key '_T1_*BodyKinematics_vel_global.sto'];

pos_list = dir(pos_pattern);
vel_list = dir(vel_pattern);

if isempty(pos_list)
    error('No position file found matching: %s\nPlace .sto files in the working directory.', pos_pattern);
end
if isempty(vel_list)
    error('No velocity file found matching: %s', vel_pattern);
end

pos_file = pos_list(1).name;
vel_file = vel_list(1).name;
fprintf('Position file : %s\n', pos_file);
fprintf('Velocity file : %s\n', vel_file);

%% --- Load kinematics files -----------------------------------------------
q_pos = read_motionFile(pos_file, 1);
q_vel = read_motionFile(vel_file, 1);
time  = q_pos.data(:, 1);

%% --- Column indices ------------------------------------------------------
col       = @(labels, name) find(strcmpi(labels, name), 1);

y_idx     = col(q_pos.labels, 'center_of_mass_Y');
yd_idx    = col(q_vel.labels, 'center_of_mass_Y');
x_idx     = col(q_pos.labels, ['center_of_mass_' ax_label]);
xd_idx    = col(q_vel.labels, ['center_of_mass_' ax_label]);
xr_idx    = col(q_pos.labels, ['calcn_r_' ax_label]);
xl_idx    = col(q_pos.labels, ['calcn_l_' ax_label]);
torso_idx = col(q_pos.labels, 'torso_Y');

missing = [y_idx, yd_idx, x_idx, xd_idx, xr_idx, xl_idx, torso_idx];
if any(isnan(missing))
    error('Required column not found. Check that forward_axis = ''%s'' is correct.', ax_label);
end

%% --- Detect all cycle boundaries -----------------------------------------
signal_raw = q_pos.data(:, torso_idx);

[cross_t, cross_dir] = find_threshold_crossings(time, signal_raw, threshold);
[starts, ends]       = pair_cycles(cross_t, cross_dir);

if isempty(starts)
    error('No complete cycles detected. Try adjusting the threshold (currently %.3f m).', threshold);
end

fprintf('Detected %d complete cycle(s). Saving all ...\n\n', numel(starts));

%% --- Loop: save every cycle ----------------------------------------------
for cycle_idx = 1:numel(starts)
    t0      = starts(cycle_idx);
    t1      = ends(cycle_idx);
    idx_cut = (time >= t0) & (time <= t1);

    Segment.time_abs    = time(idx_cut);
    Segment.time_rel    = time(idx_cut) - t0;
    Segment.COMY        = q_pos.data(idx_cut, y_idx);
    Segment.Vy          = q_vel.data(idx_cut, yd_idx);
    Segment.COMX        = q_pos.data(idx_cut, x_idx);
    Segment.Vx          = q_vel.data(idx_cut, xd_idx);
    Segment.XFootRight  = q_pos.data(idx_cut, xr_idx);
    Segment.XFootLeft   = q_pos.data(idx_cut, xl_idx);
    Segment.torso_Y     = signal_raw(idx_cut);

    out_name = sprintf('Segment_%s%s_%.3f_%.3f.mat', ...
                       cfg.segment_prefix, trial_key, t0, t1);
    save(out_name, 'Segment');
    fprintf('  [%2d/%2d]  %.3f – %.3f s  →  %s\n', ...
            cycle_idx, numel(starts), t0, t1, out_name);
end

fprintf('\nDone. %d segment file(s) saved.\n', numel(starts));

%% --- Plot ----------------------------------------------------------------
figure('Color', 'w', 'Position', [100 100 1300 500]);
hold on;  grid on;  box on;

plot(time, signal_raw, 'Color', [0.4 0.4 0.4], 'LineWidth', 1.2);
yline(threshold, '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 1.5);

yS = interp1(time, signal_raw, starts, 'linear', 'extrap');
yE = interp1(time, signal_raw, ends,   'linear', 'extrap');
plot(starts, yS, 's', 'MarkerSize', 9, 'MarkerFaceColor', [0.2 0.6 1.0], 'MarkerEdgeColor', 'k');
plot(ends,   yE, '^', 'MarkerSize', 9, 'MarkerFaceColor', [1.0 0.4 0.2], 'MarkerEdgeColor', 'k');

title(sprintf('Segmentation – %s %s | %d cycles', cfg.subject_tag, trial_key, numel(starts)));
xlabel('Time [s]');  ylabel('torso\_Y [m]');
legend({'torso\_Y', sprintf('Threshold = %.2f m', threshold), 'Start', 'End'}, 'Location', 'best');

%% =========================================================================
%% Local helper functions
%% =========================================================================

function [t_cross, dir] = find_threshold_crossings(t, y, thr)
s    = y - thr;
sg   = sign(s);  sg(sg == 0) = eps;
chg  = find(sg(1:end-1) .* sg(2:end) < 0);
t_cross = zeros(size(chg));
dir     = zeros(size(chg));
for i = 1:numel(chg)
    k     = chg(i);
    alpha = -s(k) / (s(k+1) - s(k));
    t_cross(i) = t(k) + alpha * (t(k+1) - t(k));
    dir(i)     = sign(s(k+1) - s(k));
end
end

function [starts, ends] = pair_cycles(t_cross, dir)
starts = [];  ends = [];  i = 1;
while i <= numel(t_cross)
    if dir(i) == -1
        j = find(dir(i+1:end) == 1, 1);
        if ~isempty(j)
            starts(end+1, 1) = t_cross(i);       %#ok<AGROW>
            ends(end+1,   1) = t_cross(i + j);   %#ok<AGROW>
            i = i + j + 1;
        else
            break;
        end
    else
        i = i + 1;
    end
end
end
