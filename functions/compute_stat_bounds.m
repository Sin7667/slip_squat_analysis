function [lb, ub] = compute_stat_bounds(tab, trial_key, model_type)
% COMPUTE_STAT_BOUNDS  Derive GA / Bayesian search bounds from parameter table.
%
%   [lb, ub] = compute_stat_bounds(tab, trial_key, model_type)
%
%   tab        – table loaded from a 2-parameter Excel file with columns:
%                  Cut_Filename, k_L_Nm, L0_L_m, k_R_Nm, L0_R_m
%   trial_key  – 'E1', 'E2', or 'E3'
%   model_type – 'symmetric'  → lb/ub are [K_low, L0_low; K_high, L0_high]
%                               returns lb = [K_low, L0_low]
%                               returns ub = [K_high, L0_high]
%                'asymmetric' → lb = [K_R_low, K_L_low, L0_R_low, L0_L_low]
%                               ub = [K_R_high, K_L_high, L0_R_high, L0_L_high]
%
%   Bound strategy
%   --------------
%   E1 / E2 : tight – [p10, p90] across left & right legs
%   E3      : wide  – [min, max] with 30 % padding for K, 5 cm for L0

mask = contains(tab.Cut_Filename, trial_key);
if ~any(mask)
    error('compute_stat_bounds: no rows found for trial ''%s''.', trial_key);
end

kL  = abs(tab.k_L_Nm(mask));
kR  = abs(tab.k_R_Nm(mask));
L0L = abs(tab.L0_L_m(mask));
L0R = abs(tab.L0_R_m(mask));

% Remove obvious outliers (NaN)
kL  = kL(isfinite(kL));   kR  = kR(isfinite(kR));
L0L = L0L(isfinite(L0L)); L0R = L0R(isfinite(L0R));

if any(strcmp(trial_key, {'E1','E2'}))
    K_low   = min(prctile(kL,  10), prctile(kR,  10));
    K_high  = max(prctile(kL,  90), prctile(kR,  90));
    L0_low  = min(prctile(L0L, 10), prctile(L0R, 10));
    L0_high = max(prctile(L0L, 90), prctile(L0R, 90));
else
    padK  = 0.30;
    padL0 = 0.05;
    K_low   = (1 - padK) * min([kL;  kR]);
    K_high  = (1 + padK) * max([kL;  kR]);
    L0_low  = max(0.01, min([L0L; L0R]) - padL0);
    L0_high =           max([L0L; L0R]) + padL0;
end

% Safety floor
if K_low  >= K_high,  K_low  = K_low  * 0.8;  K_high  = K_high  * 1.2; end
if L0_low >= L0_high, L0_low = L0_low * 0.9;  L0_high = L0_high * 1.1; end

switch lower(model_type)
    case 'symmetric'
        lb = [K_low,  L0_low];
        ub = [K_high, L0_high];
    case 'asymmetric'
        % Same bounds applied to each leg independently
        lb = [K_low,  K_low,  L0_low,  L0_low];
        ub = [K_high, K_high, L0_high, L0_high];
    otherwise
        error('compute_stat_bounds: model_type must be ''symmetric'' or ''asymmetric''.');
end
end
