function cfg = get_subject_config(subject_id)
% GET_SUBJECT_CONFIG  Returns all subject-specific settings as a struct.
%
%   cfg = get_subject_config(subject_id)
%
%   subject_id : integer (e.g. 13, 14, 15, 16, or any future subject)
%
%   To add a new subject: copy one of the existing 'case' blocks and
%   fill in the subject-specific values.
%
%   Returned fields
%   ---------------
%   cfg.subject_id     – integer
%   cfg.subject_tag    – string, e.g. 'S13'
%   cfg.gender         – 'M' or 'F'
%   cfg.category       – free-text label (e.g. 'healthy_young')
%   cfg.forward_axis   – always 'X': the global axis for the sagittal
%                        direction in all BodyKinematics files.
%   cfg.kin_prefix     – filename prefix of the BodyKinematics .sto files.
%                        e.g. 'S14_' → 'S14_E1_T1_*BodyKinematics_pos_global.sto'
%                        Use '' when files have no subject prefix (S15, S16).
%   cfg.segment_prefix – filename prefix for saved segment .mat files,
%                        e.g. 'S14_' → files named 'Segment_S14_E1_*.mat'.
%                        Use '' for no prefix (as in original S13 files).
%   cfg.threshold      – struct with fields E1, E2, E3: torso_Y threshold
%                        (metres) used for cycle detection in segmentation.
%   cfg.trials         – struct mapping trial keys to human-readable names:
%                          E1: 'Forward lean'
%                          E2: 'Correct movement'
%                          E3: 'Right-side movement'
%   cfg.param_file_2p  – suggested filename for 2-parameter Excel results
%   cfg.param_file_4p  – suggested filename for 4-parameter Excel results
%   cfg.log_file_sym   – suggested log filename for symmetric optimisation
%   cfg.log_file_asym  – suggested log filename for asymmetric optimisation

cfg.subject_id  = subject_id;
cfg.subject_tag = sprintf('S%d', subject_id);

% Trial names are universal.
cfg.trials = struct( ...
    'E1', 'Forward lean', ...
    'E2', 'Correct movement', ...
    'E3', 'Right-side movement');

switch subject_id

    % ------------------------------------------------------------------ %
    case 13
        cfg.gender         = 'F';
        cfg.category       = 'healthy';
        cfg.forward_axis   = 'X';   % sagittal = global X (same as all other subjects)
        cfg.kin_prefix     = 'S13_';
        cfg.segment_prefix = '';    % files: Segment_E1_*.mat
        cfg.threshold      = struct('E1', 1.30, 'E2', 1.30, 'E3', 1.30);
        cfg.param_file_2p  = 'S13_Leg_2_Param.xlsx';
        cfg.param_file_4p  = 'S13_Leg_4_Param.xlsx';
        cfg.log_file_sym   = 'S13_Log_Sym.xlsx';
        cfg.log_file_asym  = 'S13_Log_Asym.xlsx';

    % ------------------------------------------------------------------ %
    case 14
        cfg.gender         = 'M';
        cfg.category       = 'healthy';
        cfg.forward_axis   = 'X';
        cfg.kin_prefix     = 'S14_';
        cfg.segment_prefix = 'S14_';
        cfg.threshold      = struct('E1', 1.26, 'E2', 1.26, 'E3', 1.26);
        cfg.param_file_2p  = 'S14_Leg_2_Param.xlsx';
        cfg.param_file_4p  = 'S14_Leg_4_Param.xlsx';
        cfg.log_file_sym   = 'S14_Log_Sym.xlsx';
        cfg.log_file_asym  = 'S14_Log_Asym.xlsx';

    % ------------------------------------------------------------------ %
    case 15
        cfg.gender         = 'F';
        cfg.category       = 'healthy';
        cfg.forward_axis   = 'X';
        cfg.kin_prefix     = '';    % S15 .sto files have no subject prefix
        cfg.segment_prefix = 'S15_';
        cfg.threshold      = struct('E1', 1.50, 'E2', 1.50, 'E3', 1.49);
        cfg.param_file_2p  = 'S15_Leg_2_Param.xlsx';
        cfg.param_file_4p  = 'S15_Leg_4_Param.xlsx';
        cfg.log_file_sym   = 'S15_Log_Sym.xlsx';
        cfg.log_file_asym  = 'S15_Log_Asym.xlsx';

    % ------------------------------------------------------------------ %
    case 16
        cfg.gender         = 'M';
        cfg.category       = 'healthy';
        cfg.forward_axis   = 'X';
        cfg.kin_prefix     = '';    % S16 .sto files have no subject prefix
        cfg.segment_prefix = 'S16_';
        cfg.threshold      = struct('E1', 1.50, 'E2', 1.50, 'E3', 1.50);
        cfg.param_file_2p  = 'S16_Leg_2_Param.xlsx';
        cfg.param_file_4p  = 'S16_Leg_4_Param.xlsx';
        cfg.log_file_sym   = 'S16_Log_Sym.xlsx';
        cfg.log_file_asym  = 'S16_Log_Asym.xlsx';

    % ------------------------------------------------------------------ %
    otherwise
        % Template for new subjects – fill in the values below.
        error(['Subject %d is not configured yet.\n' ...
               'Add a ''case %d'' block to get_subject_config.m.'], ...
              subject_id, subject_id);
end
end
