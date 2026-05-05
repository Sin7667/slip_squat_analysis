function dqdt = eom_asymmetric(~, q, mdl)
% EOM_ASYMMETRIC  Equations of motion for a 2D asymmetric two-legged SLIP.
%
%   State vector  q = [x; y; x_dot; y_dot]   (same as symmetric version)
%
%   Model struct  mdl
%     mdl.m    – body mass (kg)
%     mdl.g    – gravitational acceleration (m/s^2)
%     mdl.xf   – half stance width (m)
%     mdl.K_R  – right leg stiffness (N/m)  [foot at +xf]
%     mdl.L0_R – right leg rest length (m)
%     mdl.K_L  – left  leg stiffness (N/m)  [foot at -xf]
%     mdl.L0_L – left  leg rest length (m)
%
%   Unlike the symmetric version, horizontal acceleration is computed from
%   the lateral spring-force components (full 2D dynamics).

x  = q(1);
y  = q(2);
xd = q(3);
yd = q(4);
xf = mdl.xf;

l_R = hypot(x - xf, y);
l_L = hypot(x + xf, y);

F_R = mdl.K_R * max(0, mdl.L0_R - l_R);
F_L = mdl.K_L * max(0, mdl.L0_L - l_L);

ux_R = (x - xf) / l_R;   uy_R = y / l_R;
ux_L = (x + xf) / l_L;   uy_L = y / l_L;

xdd = (F_R * ux_R + F_L * ux_L) / mdl.m;
ydd = (F_R * uy_R + F_L * uy_L) / mdl.m - mdl.g;

dqdt = [xd; yd; xdd; ydd];
end
