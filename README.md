# SLIP Squat Analysis — Biomechanical Modelling of Human Squats

> **Bachelor's Thesis Project** · MATLAB · Biomechanics · Spring-Loaded Inverted Pendulum (SLIP)

A universal, subject-agnostic MATLAB pipeline for fitting and evaluating **Spring-Loaded Inverted Pendulum (SLIP)** models to human squat kinematics, using OpenSim-exported data and Genetic Algorithm optimisation.

---

## What this project does

Human squats are modelled as a two-legged spring system. Each leg is represented as a spring with stiffness *K* and rest length *L₀*. The model is fitted to real motion-capture data using **Genetic Algorithm + fmincon** optimisation, minimising the difference between the simulated and measured centre-of-mass (COM) trajectory.

Three model variants of increasing complexity are implemented:

| Model | Parameters | Description |
|-------|-----------|-------------|
| **Symmetric** | 2 | `K`, `L0` — same for both legs |
| **Asymmetric** | 4 | `K_R`, `K_L`, `L0_R`, `L0_L` — left/right independent |
| **8-Parameter** | 8 | Separate flexion and extension phases × left/right legs |

```
          COM (x, y)
         /          \
        /  K_R, L0_R \ K_L, L0_L
       /              \
  Right foot        Left foot
   (+xf, 0)          (-xf, 0)
```

**Spring force (compression only):**  `F = K · max(0, L₀ − L)`

---

## Key features

- Automatic squat cycle detection from torso height signal
- Batch GRF curve fitting (2-param and 4-param / hysteresis)
- Statistical search bounds (p10–p90 per trial type)
- GA + fmincon hybrid optimiser with reproducible random seed
- Phase-aware 8-parameter model (flexion → extension switch at deepest point)
- 2D animation with real-time COM trajectory and spring force arrows
- Excel logging of all optimisation results
- Fully subject-agnostic — configured for S13–S16, extendable to any subject

---

## Project structure

```
slip_squat_analysis/
│
├── config/
│   └── get_subject_config.m        Subject-specific settings (thresholds, prefixes, filenames)
│
├── functions/
│   ├── read_motionFile.m           Read OpenSim .mot / .sto files
│   │
│   ├── eom_symmetric.m             EOM – symmetric SLIP  (K, L0)
│   ├── eom_asymmetric.m            EOM – asymmetric SLIP (K_R/L, L0_R/L)
│   ├── eom_8param.m                EOM – 8-param 2-phase SLIP (flex/ext × L/R)
│   │
│   ├── simulate_slip.m             ODE45 wrapper – symmetric & asymmetric
│   ├── simulate_8param.m           ODE45 wrapper – two-phase (flexion → extension)
│   │
│   ├── cost_fn_symmetric.m         Weighted MSE cost – symmetric optimiser
│   ├── cost_fn_asymmetric.m        Weighted MSE cost – asymmetric optimiser
│   ├── cost_fn_8param.m            Weighted MSE cost – 8-param optimiser
│   │
│   ├── analyze_leg_2param.m        Spring fit per leg: F = k·(L − L0)
│   ├── analyze_leg_4param.m        Flex/ext fits + hysteresis energy dissipation
│   │
│   ├── compute_stat_bounds.m       GA search bounds from GRF statistics
│   ├── log_to_excel.m              Append results to Excel log file
│   └── animate_squat_com.m         2D animation (symmetric / asymmetric / 8-param)
│
├── segmentation.m                  Detect and save individual squat cycles
├── curve_fit_2param.m              Batch 2-parameter GRF curve fitting
├── curve_fit_4param.m              Batch 4-parameter GRF fitting (+ hysteresis)
├── optimize_symmetric_GA.m         GA optimisation – symmetric model
├── optimize_asymmetric_GA.m        GA optimisation – asymmetric model
├── optimize_8param_GA.m            GA optimisation – 8-parameter 2-phase model
├── simulate_forward.m              Forward simulation + animation
│
├── optimize_symmetric_Bayes.m      (Bayesian optimisation – experimental)
└── optimize_asymmetric_Bayes.m     (Bayesian optimisation – experimental)
```

---

## Required MATLAB toolboxes

| Toolbox | Used for |
|---------|----------|
| Optimization Toolbox | `ga`, `fmincon` |
| Curve Fitting Toolbox | `fit`, `fitoptions` (spring fitting) |
| Signal Processing Toolbox | `sgolayfilt`, `gradient` (mass estimation) |
| Statistics and Machine Learning Toolbox | `prctile` (bounds), `median(...,'omitnan')` |

---

## Required input data (not included)

Raw data files must be placed in the MATLAB **working directory**.  
They are excluded from this repository (see `.gitignore`).

| File type | Description |
|-----------|-------------|
| `*_BodyKinematics_pos_global.sto` | COM and segment positions (from OpenSim) |
| `*_BodyKinematics_vel_global.sto` | COM and segment velocities (from OpenSim) |
| `*_GRF.mot` | Ground reaction forces |

> Data is exported from OpenSim after running **Inverse Kinematics** and **Body Kinematics** analyses.

---

## How to use

Each script is **independent** — run them in order, one at a time.  
Set only the `USER SETTINGS` block at the top of each script.

---

### Step 1 — Segmentation (`segmentation.m`)
Detects all squat cycles automatically from the torso-Y signal and saves each cycle as a `.mat` file.

```matlab
subject_id = 14;    % 13 | 14 | 15 | 16
trial_key  = 'E1';  % 'E1' | 'E2' | 'E3'
```

**Output:** `Segment_S14_E1_<t0>_<t1>.mat` — one file per detected squat cycle

---

### Step 2 — 2-parameter GRF curve fitting (`curve_fit_2param.m`)
Fits a single spring model `F = k·(L − L0)` to the GRF data of each leg.  
Processes all segments of the given trial in one batch run.

```matlab
subject_id = 14;
trial_key  = 'E1';
grf_file   = 'S14_E1_T1_001_GRF.mot';
```

**Output:** `S14_Leg_2_Param.xlsx`, plots in `Plots_2Param_E1/`

---

### Step 3 — 4-parameter GRF curve fitting (`curve_fit_4param.m`)
Fits separate spring models for the **flexion** and **extension** phases and computes hysteresis energy dissipation for each leg.

**Output:** `S14_Leg_4_Param.xlsx`, plots in `Plots_4Param_E1/`

---

### Step 4 — GA optimisation

Run **one** of the three optimisers (each requires the corresponding GRF Excel from Steps 2–3):

| Script | Model | Requires |
|--------|-------|----------|
| `optimize_symmetric_GA.m` | Symmetric (2 params) | Step 2 Excel |
| `optimize_asymmetric_GA.m` | Asymmetric (4 params) | Step 2 Excel |
| `optimize_8param_GA.m` | 8-parameter (2-phase) | Step 3 Excel |

```matlab
subject_id = 14;
trial_key  = 'E1';
mat_file   = 'Segment_S14_E1_10.642_14.333.mat';
```

**Output:** Excel log, plot and run-data `.mat` in `Results_E1/`

---

### Step 5 — Forward simulation & animation (`simulate_forward.m`)
Runs a forward simulation with logged or manually set parameters and visualises the result.  
Optionally plays back a 2D animation with spring force arrows.

```matlab
model_type    = '8param';  % 'symmetric' | 'asymmetric' | '8param'
use_log       = true;      % load optimised parameters from log automatically
run_animation = true;
```

---

## SLIP model — conventions

```
State vector:  q = [x_rel, y, vx, vy]

   x_rel = COM horizontal position relative to foot midpoint (m)
   y     = COM vertical position (m)
   vx    = horizontal velocity (m/s)
   vy    = vertical velocity (m/s)

Foot positions:
   Right foot:  (+xf, 0)    xf = half stance width
   Left  foot:  (-xf, 0)

Leg lengths:
   L_R = sqrt((x − xf)² + y²)
   L_L = sqrt((x + xf)² + y²)

Spring force (compression only):
   F = K · max(0, L0 − L)
```

**Symmetric model:** `K_R = K_L = K`,  `L0_R = L0_L = L0`  
**Asymmetric model:** independent `K_R`, `K_L`, `L0_R`, `L0_L`  
**8-parameter model:** flex and ext parameters switch at the deepest COM point (`t_switch`)

---

## Cost function weights

| Model | Formula |
|-------|---------|
| Symmetric / Asymmetric | `cost = 100·MSE_y + 50·MSE_x + 0.1·MSE_vy + 10·MSE_vx` |
| 8-Parameter | `cost = 200·MSE_y + 40·MSE_x + 20·MSE_vy + 5·MSE_vx` |

Weights can be adjusted in the corresponding `functions/cost_fn_*.m` files.

---

## GA optimisation settings

| Setting | Value |
|---------|-------|
| Population size | 100 |
| Max generations | 200 |
| Hybrid function | `fmincon` (local refinement after GA) |
| Random seed | `rng(42)` — reproducible |
| Bounds strategy (E1/E2) | p10–p90 percentiles across all segments |
| Bounds strategy (E3) | data-driven: min/max ± 30 % padding |

---

## Subjects and trials

| Subject | Gender | Threshold (m) |
|---------|--------|---------------|
| S13 | F | 1.30 |
| S14 | M | 1.26 |
| S15 | F | 1.50 |
| S16 | M | 1.50 |

| Trial | Description |
|-------|-------------|
| `E1` | Forward lean |
| `E2` | Correct movement |
| `E3` | Right-side movement (asymmetric load) |

---

## Excel output columns

### `*_Leg_2_Param.xlsx`
`Cut_Filename`, `GRF_Filename`, `Mass_Dyn_kg`,  
`k_L_Nm`, `L0_L_m`, `R2_L`, `RMSE_L`, `N_L`,  
`k_R_Nm`, `L0_R_m`, `R2_R`, `RMSE_R`, `N_R`

### `*_Leg_4_Param.xlsx`
`Cut_Filename`, `GRF_Filename`, `Mass_Dyn_kg`,  
`k_L_Flex`, `L0_L_Flex`, `k_L_Ext`, `L0_L_Ext`, `E_diss_L_Raw`, `E_diss_L_Fit`,  
`k_R_Flex`, `L0_R_Flex`, `k_R_Ext`, `L0_R_Ext`, `E_diss_R_Raw`, `E_diss_R_Fit`

### `*_Log_Sym.xlsx` / `*_Log_Asym.xlsx` / `*_Log_8Param.xlsx`
`Cut_Filename`, `Timestamp`, `Trial`, `Subject`, `Gender`, optimised parameters, cost, RMSE, search bounds.

---

## Adding a new subject

1. Open `config/get_subject_config.m`
2. Copy an existing `case` block and set:
   - `gender`, `forward_axis` (always `'X'`)
   - `kin_prefix`, `segment_prefix`
   - `threshold` struct for each trial
   - `param_file_2p`, `param_file_4p`, log filenames
3. Place data files in the working directory and run from Step 1.

---

## License

This code is part of a bachelor's thesis.  
Please cite appropriately if used in academic work.
