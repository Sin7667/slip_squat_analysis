function dqdt = eom_8param(~, q, mdl, phase)
% EOM_8PARAM  Equations of motion for the 8-parameter 2-phase asymmetric SLIP.
%
%   dqdt = eom_8param(t, q, mdl, phase)
%
%   State vector  q = [x; y; vx; vy]
%     x   – COM horizontal position relative to stance midpoint (m)
%     y   – COM vertical position (m)
%     vx  – horizontal velocity (m/s)
%     vy  – vertical velocity (m/s)
%
%   Model struct  mdl
%     mdl.m        – body mass (kg)
%     mdl.g        – gravitational acceleration (m/s^2)
%     mdl.xf       – half stance width (m); right foot at +xf, left at -xf
%
%     Flexion phase parameters:
%     mdl.KL_flex,  mdl.L0_L_flex  – left  leg stiffness/rest-length (flex)
%     mdl.KR_flex,  mdl.L0_R_flex  – right leg stiffness/rest-length (flex)
%
%     Extension phase parameters:
%     mdl.KL_ext,   mdl.L0_L_ext   – left  leg stiffness/rest-length (ext)
%     mdl.KR_ext,   mdl.L0_R_ext   – right leg stiffness/rest-length (ext)
%
%   phase : 'flex'  – use flexion parameters
%           'ext'   – use extension parameters

x  = q(1);  y  = q(2);
vx = q(3);  vy = q(4);

m  = mdl.m;
g  = mdl.g;
xf = mdl.xf;

% Leg lengths (left foot at -xf, right foot at +xf)
l_L = max(hypot(x + xf, y), eps);
l_R = max(hypot(x - xf, y), eps);

% Unit vectors from foot toward COM
ux_L = (x + xf) / l_L;   uy_L = y / l_L;
ux_R = (x - xf) / l_R;   uy_R = y / l_R;

% Phase-specific spring parameters
switch phase
    case 'flex'
        K_L = mdl.KL_flex;   L0_L = mdl.L0_L_flex;
        K_R = mdl.KR_flex;   L0_R = mdl.L0_R_flex;
    case 'ext'
        K_L = mdl.KL_ext;    L0_L = mdl.L0_L_ext;
        K_R = mdl.KR_ext;    L0_R = mdl.L0_R_ext;
    otherwise
        error('eom_8param: phase must be ''flex'' or ''ext''.');
end

% Spring forces (compression only)
F_L = K_L * max(0, L0_L - l_L);
F_R = K_R * max(0, L0_R - l_R);

% Accelerations
xdd = (F_L * ux_L + F_R * ux_R) / m;
ydd = (F_L * uy_L + F_R * uy_R) / m - g;

dqdt = [vx; vy; xdd; ydd];
end
