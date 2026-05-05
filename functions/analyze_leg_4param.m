function Res = analyze_leg_4param(L, F, ax, side_name)
% ANALYZE_LEG_4PARAM  Fit separate flexion/extension spring models to one leg.
%
%   Res = analyze_leg_4param(L, F)
%   Res = analyze_leg_4param(L, F, ax)
%   Res = analyze_leg_4param(L, F, ax, side_name)
%
%   The signal is split at the minimum leg-length point (max compression):
%     Flexion  phase : L(1) → L(min)
%     Extension phase: L(min) → L(end)
%
%   Each phase is fitted with poly1 (robust Bisquare weighting).
%   Conversion:  F = p1*L + p2  →  k = p1,  L0 = -p2/p1
%
%   Returned struct fields
%   ----------------------
%   k_flex, L0_flex  – flexion  spring parameters
%   k_ext,  L0_ext   – extension spring parameters
%   E_diss_raw       – energy dissipated from raw data (hysteresis area, J)
%   E_diss_fit       – energy dissipated from fitted curves (J)

Res = struct('k_flex', NaN, 'L0_flex', NaN, ...
             'k_ext',  NaN, 'L0_ext',  NaN, ...
             'E_diss_raw', NaN, 'E_diss_fit', NaN);

if nargin < 3, ax = []; end
if nargin < 4, side_name = ''; end

[~, idx_min] = min(L);
L_flex = L(1:idx_min);     F_flex = F(1:idx_min);
L_ext  = L(idx_min:end);   F_ext  = F(idx_min:end);

ft   = 'poly1';
opts = fitoptions(ft, 'Robust', 'Bisquare');

% --- Hysteresis area from raw data ---
if numel(L_flex) > 2 && numel(L_ext) > 2
    [Lfs, iF] = sort(L_flex);  [Les, iE] = sort(L_ext);
    E_in  = trapz(Lfs, F_flex(iF));
    E_out = trapz(Les, F_ext(iE));
    Res.E_diss_raw = abs(E_in) - abs(E_out);
end

% --- Flexion fit ---
mdl_flex = [];  L_grid_f = [];  F_fit_f = [];
if numel(L_flex) > 5
    try
        mdl_flex = fit(L_flex(:), F_flex(:), ft, opts);
        Res.k_flex  = mdl_flex.p1;
        Res.L0_flex = -mdl_flex.p2 / mdl_flex.p1;
        L_grid_f = linspace(min(L_flex), max(L_flex), 100)';
        F_fit_f  = feval(mdl_flex, L_grid_f);
    catch; end
end

% --- Extension fit ---
mdl_ext = [];  L_grid_e = [];  F_fit_e = [];
if numel(L_ext) > 5
    try
        mdl_ext = fit(L_ext(:), F_ext(:), ft, opts);
        Res.k_ext  = mdl_ext.p1;
        Res.L0_ext = -mdl_ext.p2 / mdl_ext.p1;
        L_grid_e = linspace(min(L_ext), max(L_ext), 100)';
        F_fit_e  = feval(mdl_ext, L_grid_e);
    catch; end
end

% --- Hysteresis area from fitted curves ---
if ~isempty(mdl_flex) && ~isempty(mdl_ext)
    try
        E_abs = integral(@(x) feval(mdl_flex, x), min(L_flex), max(L_flex), 'ArrayValued', true);
        E_gen = integral(@(x) feval(mdl_ext,  x), min(L_ext),  max(L_ext),  'ArrayValued', true);
        Res.E_diss_fit = abs(E_abs) - abs(E_gen);
    catch; end
end

% --- Optional plot ---
if ~isempty(ax)
    hold(ax, 'on');
    grid(ax, 'on');  box(ax, 'on');
    xlabel(ax, 'Leg length L [m]', 'FontWeight', 'bold');
    ylabel(ax, 'Leg force F [N]',  'FontWeight', 'bold');
    if ~isempty(side_name), title(ax, side_name); end

    % Hysteresis fill (raw)
    if ~isnan(Res.E_diss_raw)
        [Lfs, iF] = sort(L_flex);  [Les, iE] = sort(L_ext);
        Lp = [Les; flipud(Lfs)];
        Fp = [F_ext(iE); flipud(F_flex(iF))];
        fill(ax, Lp, Fp, [0.2 0.8 0.2], ...
             'FaceAlpha', 0.2, 'EdgeColor', 'none', ...
             'DisplayName', 'Hysteresis (raw)');
    end

    % Fitted fill (orange)
    if ~isempty(L_grid_f) && ~isempty(L_grid_e)
        Lpf = [L_grid_e; flipud(L_grid_f)];
        Fpf = [F_fit_e;  flipud(F_fit_f)];
        fill(ax, Lpf, Fpf, [1 0.6 0.2], ...
             'FaceAlpha', 0.3, 'EdgeColor', 'none', ...
             'DisplayName', 'Hysteresis (model)');
        plot(ax, L_grid_f, F_fit_f, 'b-', 'LineWidth', 2, 'DisplayName', 'Fit flexion');
        plot(ax, L_grid_e, F_fit_e, 'r-', 'LineWidth', 2, 'DisplayName', 'Fit extension');
    end

    % Data points
    plot(ax, L_flex, F_flex, '.', 'Color', [0.5 0.5 0.9], 'MarkerSize', 5, ...
         'DisplayName', 'Data flexion');
    plot(ax, L_ext,  F_ext,  '.', 'Color', [0.9 0.5 0.5], 'MarkerSize', 5, ...
         'DisplayName', 'Data extension');

    % Parameter annotation
    xl = xlim(ax);  yl = ylim(ax);
    txt = {sprintf('k_{flex} = %.0f', Res.k_flex), ...
           sprintf('k_{ext}  = %.0f', Res.k_ext), ...
           sprintf('L_{0,flex} = %.3f', Res.L0_flex), ...
           sprintf('L_{0,ext}  = %.3f', Res.L0_ext)};
    text(ax, xl(2) - 0.02*diff(xl), yl(2) - 0.02*diff(yl), txt, ...
         'VerticalAlignment', 'top', 'HorizontalAlignment', 'right', ...
         'BackgroundColor', [1 1 1 0.8], 'EdgeColor', 'k', 'FontSize', 8);

    legend(ax, 'Location', 'northwest', 'FontSize', 7);
end
end
