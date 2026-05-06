%% =========================================================================
%  08_simulate_forward.m
%  Forward simulation and visual validation of fitted SLIP parameters.
%
%  WHAT IT DOES
%  ------------
%  Given a segment .mat file and either manually specified or Excel-loaded
%  parameters, runs forward simulation for both symmetric and asymmetric
%  models and compares against measured kinematics in a 2x2 subplot.
%  Optionally plays back an animation.
%
%  HOW TO USE
%  ----------
%  1. Set subject_id, trial_key, mat_file, and the parameter source.
%  2. Set model_type = 'symmetric' or 'asymmetric'.
%  3. Run.
%% =========================================================================

clc; clear; close all;

%% --- USER SETTINGS -------------------------------------------------------
subject_id = 14;
trial_key  = 'E1';
mat_file   = 'Segment_S14_E1_10.642_14.333.mat';
model_type = 'symmetric';   % 'symmetric' | 'asymmetric'

% === Parameter source ===
% Option A: load from optimisation log (set use_log = true)
use_log    = false;

% Option B: manual parameters (used when use_log = false)
K_manual   = 128;    % N/m  (symmetric: single value; asymmetric: [K_R, K_L])
L0_manual  = 3.1;   % m    (symmetric: single value; asymmetric: [L0_R, L0_L])

% === Animation ===
run_animation = true;   % set true to open animation window
save_mp4      = false;
save_gif      = false;
%% -------------------------------------------------------------------------

addpath(fullfile(fileparts(mfilename('fullpath')), 'config'));
addpath(fullfile(fileparts(mfilename('fullpath')), 'functions'));
cfg = get_subject_config(subject_id);

if ~isfile(mat_file), error('Segment file not found: %s', mat_file); end
S = load(mat_file);
C = select_struct(S);

%% --- Optionally load parameters from log ---------------------------------
if use_log
    if strcmp(model_type, 'symmetric')
        log_file = cfg.log_file_sym;
        col_K    = 'K_opt_Nm';
        col_L0   = 'L0_opt_m';
    else
        log_file = cfg.log_file_asym;
    end

    if ~isfile(log_file)
        error('Log file not found: %s\nRun the optimiser first.', log_file);
    end
    T = readtable(log_file, 'VariableNamingRule', 'preserve');
    row_idx = find(strcmp(T.Cut_Filename, mat_file), 1, 'last');
    if isempty(row_idx)
        error('Segment not found in log file.');
    end

    if strcmp(model_type, 'symmetric')
        K_manual  = T.(col_K)(row_idx);
        L0_manual = T.(col_L0)(row_idx);
    else
        K_manual  = [T.K_R_opt(row_idx), T.K_L_opt(row_idx)];
        L0_manual = [T.L0_R_opt(row_idx), T.L0_L_opt(row_idx)];
    end
    fprintf('Parameters loaded from log: %s\n', log_file);
end

%% --- Human struct --------------------------------------------------------
XR    = C.XFootRight(1);  XL    = C.XFootLeft(1);
x_mid = 0.5*(XR+XL);       xFoot = 0.5*abs(XR-XL);

Human.time  = C.time_rel(:);
Human.x_rel = C.COMX(:) - x_mid;
Human.y     = C.COMY(:);
Human.vx    = C.Vx(:);
Human.vy    = C.Vy(:);

%% --- Build model struct --------------------------------------------------
mdl.g  = 9.81;
mdl.xf = xFoot;

% Estimate mass from GRF if available in any param table, else use default
param_file = cfg.param_file_2p;
if isfile(param_file)
    Tab = readtable(param_file, 'VariableNamingRule', 'preserve');
    row = find(strcmp(Tab.Cut_Filename, mat_file), 1);
    if ~isempty(row) && isfinite(Tab.Mass_Dyn_kg(row))
        mdl.m = Tab.Mass_Dyn_kg(row);
    else
        mdl.m = 70;
        warning('Mass not found in parameter table; using default 70 kg.');
    end
else
    mdl.m = 70;
    warning('Parameter file not found; using default mass 70 kg.');
end

if strcmp(model_type, 'symmetric')
    mdl.K  = K_manual(1);
    mdl.L0 = L0_manual(1);
    fprintf('Symmetric model:  K = %.2f N/m,  L0 = %.3f m\n', mdl.K, mdl.L0);
else
    mdl.K_R  = K_manual(1);   mdl.L0_R = L0_manual(1);
    mdl.K_L  = K_manual(end); mdl.L0_L = L0_manual(end);
    fprintf('Asymmetric model:  K_R=%.2f, K_L=%.2f, L0_R=%.3f, L0_L=%.3f\n', ...
            mdl.K_R, mdl.K_L, mdl.L0_R, mdl.L0_L);
end

q0      = [Human.x_rel(1), Human.y(1), Human.vx(1), Human.vy(1)];
sim_dur = Human.time(end) - Human.time(1);

%% --- Forward simulation --------------------------------------------------
[t_sim, q_sim] = simulate_slip(mdl, q0, sim_dur, model_type);

dt = max(1e-3, median(diff(Human.time)));
t0 = max(t_sim(1),  Human.time(1));
t1 = min(t_sim(end), Human.time(end));
tc = (t0:dt:t1).';

Xs  = interp1(t_sim, q_sim(:,1), tc);  Ys  = interp1(t_sim, q_sim(:,2), tc);
Vxs = interp1(t_sim, q_sim(:,3), tc);  Vys = interp1(t_sim, q_sim(:,4), tc);
Xr  = interp1(Human.time, Human.x_rel, tc);
Yr  = interp1(Human.time, Human.y,     tc);
Vxr = interp1(Human.time, Human.vx,    tc);
Vyr = interp1(Human.time, Human.vy,    tc);

MSE_y  = mean((Yr-Ys).^2,  'omitnan');
MSE_x  = mean((Xr-Xs).^2,  'omitnan');
RMSE_y = sqrt(MSE_y);
RMSE_x = sqrt(MSE_x);

fprintf('RMSE_Y = %.4f m  |  RMSE_X = %.4f m\n', RMSE_y, RMSE_x);

%% --- Comparison plots ----------------------------------------------------
param_str = '';
if strcmp(model_type, 'symmetric')
    param_str = sprintf('K=%.0f N/m, L0=%.3f m', mdl.K, mdl.L0);
else
    param_str = sprintf('K_R=%.0f, K_L=%.0f, L0_R=%.3f, L0_L=%.3f', ...
                        mdl.K_R, mdl.K_L, mdl.L0_R, mdl.L0_L);
end

fig = figure('Color','w','Name',sprintf('Forward Simulation – %s', model_type));

subplot(2,2,1); hold on; grid on;
plot(tc, Yr, 'b', 'LineWidth', 1.5);
plot(tc, Ys, 'r--', 'LineWidth', 1.5);
ylabel('y [m]');  title('COM Y');  xlabel('t [s]');
legend('Measured', 'Simulated', 'Location', 'best');

subplot(2,2,2); hold on; grid on;
plot(tc, Xr, 'b', 'LineWidth', 1.5);
plot(tc, Xs, 'r--', 'LineWidth', 1.5);
ylabel('x_{rel} [m]');  title('COM X');  xlabel('t [s]');

subplot(2,2,3); hold on; grid on;
plot(tc, Vyr, 'b', 'LineWidth', 1.5);
plot(tc, Vys, 'r--', 'LineWidth', 1.5);
ylabel('v_y [m/s]');  title('Velocity Y');  xlabel('t [s]');

subplot(2,2,4); hold on; grid on;
plot(tc, Vxr, 'b', 'LineWidth', 1.5);
plot(tc, Vxs, 'r--', 'LineWidth', 1.5);
ylabel('v_x [m/s]');  title('Velocity X');  xlabel('t [s]');

sgtitle(sprintf('%s | %s | %s\n%s | RMSE_Y=%.4f m', ...
        cfg.subject_tag, trial_key, model_type, param_str, RMSE_y), ...
        'FontSize', 10);

%% --- Animation -----------------------------------------------------------
if run_animation
    animate_squat_com(t_sim, q_sim, mdl, ...
        't_real',      Human.time, ...
        'x_real',      Human.x_rel, ...
        'y_real',      Human.y, ...
        'show_forces', true, ...
        'force_scale', 0.002, ...
        'saveMP4',     save_mp4, ...
        'saveGIF',     save_gif);
end

%% =========================================================================
function C = select_struct(S)
if isfield(S,'Segment'),     C = S.Segment;
elseif isfield(S,'Schnitt'), C = S.Schnitt;
else, error('No Segment or Schnitt field.'); end
end
