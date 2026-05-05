function [k, L0, R2, rmse, n_pts] = analyze_leg_2param(L, F, ax)
% ANALYZE_LEG_2PARAM  Fit a linear spring model F = k*(L - L0) to one leg.
%
%   [k, L0, R2, rmse, n_pts] = analyze_leg_2param(L, F)
%   [k, L0, R2, rmse, n_pts] = analyze_leg_2param(L, F, ax)
%
%   Only data points with F > 10 N are used (excludes swing phase).
%   If ax is provided, the scatter and fit are drawn on that axes handle.
%
%   Returns NaN for all outputs when there are fewer than 10 valid points.

k = NaN;  L0 = NaN;  R2 = NaN;  rmse = NaN;  n_pts = 0;

valid = isfinite(L) & isfinite(F) & (F > 10);
n_pts = nnz(valid);
if n_pts < 10,  return;  end

Lv = L(valid);
Fv = F(valid);

ft   = fittype('k*(x - L0)', 'independent', 'x', 'coefficients', {'k','L0'});
opts = fitoptions(ft);
opts.Robust     = 'LAR';
opts.Lower      = [-Inf, -Inf];
opts.Upper      = [Inf,  Inf];
p0              = polyfit(Lv, Fv, 1);
opts.StartPoint = [p0(1), -p0(2)/p0(1)];

try
    [mdl_fit, gof] = fit(Lv(:), Fv(:), ft, opts);
    k    = mdl_fit.k;
    L0   = mdl_fit.L0;
    R2   = gof.rsquare;
    rmse = gof.rmse;
catch
    return;
end

if nargin >= 3 && ~isempty(ax)
    hold(ax, 'on');
    scatter(ax, Lv, Fv, 15, [0.15 0.15 0.15], 'filled', 'MarkerFaceAlpha', 0.4);
    L_grid = linspace(min(Lv), max(Lv), 200);
    plot(ax, L_grid, mdl_fit(L_grid), 'r-', 'LineWidth', 1.8);
    xlabel(ax, 'Leg length L [m]',  'FontWeight', 'bold');
    ylabel(ax, 'Leg force F [N]',   'FontWeight', 'bold');
    subtitle(ax, sprintf('k = %.0f N/m | R^2 = %.2f | n = %d', k, R2, n_pts));
    grid(ax, 'on');
end
end
