function [t_sim, q_sim] = simulate_slip(mdl, q0, sim_dur, model_type)
% SIMULATE_SLIP  Run a forward ODE simulation of the SLIP model.
%
%   [t_sim, q_sim] = simulate_slip(mdl, q0, sim_dur, model_type)
%
%   model_type : 'symmetric'  – uses eom_symmetric  (mdl.K, mdl.L0)
%                'asymmetric' – uses eom_asymmetric  (mdl.K_R/L, mdl.L0_R/L)
%
%   Returns t_sim (Nx1) and q_sim (Nx4) from ode45.
%   Throws an error if integration fails or produces non-finite values.

switch lower(model_type)
    case 'symmetric'
        eom = @(t,q) eom_symmetric(t, q, mdl);
    case 'asymmetric'
        eom = @(t,q) eom_asymmetric(t, q, mdl);
    otherwise
        error('simulate_slip: model_type must be ''symmetric'' or ''asymmetric''.');
end

opts = odeset('RelTol', 1e-6, 'AbsTol', 1e-8);
[t_sim, q_sim] = ode45(eom, [0, sim_dur], q0, opts);

if any(~isfinite(q_sim(:)))
    error('simulate_slip: integration produced non-finite values.');
end
end
