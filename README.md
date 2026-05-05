# SLIP Squat Analysis

A universal, subject-agnostic MATLAB pipeline for fitting and evaluating Spring-Loaded Inverted Pendulum (SLIP) models to human squat kinematics.

---

## Overview

This codebase implements a two-legged 2D SLIP model fitted to OpenSim-exported body kinematics and ground reaction force (GRF) data from squat experiments.  
It was developed as part of a master's thesis on biomechanical modelling of human squats.

### Supported subjects
The pipeline is configured for subjects **S13 – S16** and can be extended to any subject by adding a `case` block in `config/get_subject_config.m`.

### Trial types
| Key | Description |
|-----|-------------|
| `E1` | Forward lean |
| `E2` | Correct movement |
| `E3` | Right-side movement |

---

## Project structure

```
slip_squat_analysis/
├── config/
│   └── get_subject_config.m     Subject-specific settings (thresholds, axes, filenames)
├── functions/
│   ├── read_motionFile.m        Read OpenSim .mot / .sto files
│   ├── eom_symmetric.m          Equations of motion – symmetric SLIP (K, L0)
│   ├── eom_asymmetric.m         Equations of motion – asymmetric SLIP (K_R, K_L, L0_R, L0_L)
│   ├── cost_fn_symmetric.m      Weighted MSE cost – symmetric optimiser
│   ├── cost_fn_asymmetric.m     Weighted MSE cost – asymmetric optimiser
│   ├── simulate_slip.m          Forward ODE simulation wrapper (ode45)
│   ├── analyze_leg_2param.m     Single spring fit per leg (F = k·(L−L0))
│   ├── analyze_leg_4param.m     Separate flexion/extension fits + hysteresis
│   ├── compute_stat_bounds.m    Statistical search bounds from Excel data
│   ├── log_to_excel.m           Append results to Excel log file
│   └── animate_squat_com.m      2D squat animation (optional MP4 / GIF export)
├── segmentation.m              Detect and save individual squat cycles
├── curve_fit_2param.m          Batch 2-parameter GRF curve fitting
├── curve_fit_4param.m          Batch 4-parameter GRF curve fitting (with hysteresis)
├── optimize_symmetric_GA.m     Symmetric SLIP – Genetic Algorithm
├── optimize_asymmetric_GA.m    Asymmetric SLIP – Genetic Algorithm
├── optimize_symmetric_Bayes.m  Symmetric SLIP – Bayesian Optimisation
├── optimize_asymmetric_Bayes.m Asymmetric SLIP – Bayesian Optimisation
└── simulate_forward.m          Forward simulation and visual validation
```

---

## Required MATLAB toolboxes

| Toolbox | Used for |
|---------|----------|
| Optimization Toolbox | `ga`, `fmincon` |
| Statistics and Machine Learning Toolbox | `bayesopt`, `prctile`, `median` with `omitnan` |
| Curve Fitting Toolbox | `fit`, `fitoptions` |
| Signal Processing Toolbox | `sgolayfilt`, `gradient` |

---

## Required input data (not included)

Raw data files must be placed in the MATLAB **working directory** before running each script.  
They are **not** included in this repository.

| File type | Description | Example name |
|-----------|-------------|--------------|
| `*_BodyKinematics_pos_global.sto` | COM and segment positions | `S14_E1_T1_..._pos_global.sto` |
| `*_BodyKinematics_vel_global.sto` | COM and segment velocities | `S14_E1_T1_..._vel_global.sto` |
| `*_GRF.mot` | Ground reaction forces | `S14_E1_T1_001_GRF.mot` |

These files are exported from OpenSim after running Inverse Kinematics and Body Kinematics analyses.

---

## How to use

Each script is **independent** — run them one at a time in the order below.  
Set the `USER SETTINGS` block at the top of each script before running.

### Step-by-step

**Step 1 – Segmentation** (`segmentation.m`)  
Detects all squat cycles from the `torso_Y` signal and saves each as a `.mat` Segment file.  
Kinematics files are found automatically from `subject_id` and `trial_key`.

```matlab
subject_id = 14;   % 13 | 14 | 15 | 16
trial_key  = 'E1'; % 'E1' | 'E2' | 'E3'
```

Output: `Segment_S14_E1_<t0>_<t1>.mat` (one file per detected cycle)

---

**Step 2 – 2-parameter curve fitting** (`curve_fit_2param.m`)  
Fits `F = k·(L − L0)` to GRF data for each leg, batch-processed over all saved segments.

```matlab
subject_id = 14;
trial_key  = 'E3';
grf_file   = 'S14_E3_T1_001_GRF.mot';
```

Output: `S14_Leg_2_Param.xlsx`, plots in `Plots_2Param_E3/`

---

**Step 3 – 4-parameter curve fitting** (`curve_fit_4param.m`)  
Fits separate spring parameters for the flexion and extension phases and computes hysteresis energy dissipation.

Output: `S14_Leg_4_Param.xlsx`, plots in `Plots_4Param_E3/`

---

**Step 4 – GA optimisation** (`optimize_symmetric_GA.m` / `optimize_asymmetric_GA.m`)  
Optimises spring parameters by minimising weighted MSE between simulated and measured COM trajectories.  
Requires the 2-parameter Excel from Step 2.

```matlab
subject_id = 14;
trial_key  = 'E1';
mat_file   = 'Segment_S14_E1_10.642_14.333.mat';
```

Output: `S14_Log_Sym.xlsx` / `S14_Log_Asym.xlsx`, plots and run-data `.mat` in `Results_E1/`

---

**Step 5 – Bayesian optimisation** (`optimize_symmetric_Bayes.m` / `optimize_asymmetric_Bayes.m`)  
Alternative to GA.  Uses `bayesopt` (Statistics and Machine Learning Toolbox required).  
Logs to the same Excel file as the GA scripts.

---

**Step 6 – Forward simulation** (`simulate_forward.m`)  
Runs a forward simulation with manually specified or log-loaded parameters and visualises the result. Optionally plays back an animation.

```matlab
subject_id    = 14;
trial_key     = 'E1';
mat_file      = 'Segment_S14_E1_10.642_14.333.mat';
model_type    = 'symmetric';   % or 'asymmetric'
use_log       = true;          % load parameters from optimisation log
run_animation = true;
```

---

## SLIP model conventions

```
        COM (x, y)
       /          \
      /            \
 Right foot      Left foot
  (+xf, 0)        (-xf, 0)
```

- `xf` = half stance width (m)
- Right leg length: `L_R = sqrt((x − xf)² + y²)`
- Left leg length:  `L_L = sqrt((x + xf)² + y²)`
- Spring force (compression only): `F = K · max(0, L0 − L)`

**Symmetric model**: `K_R = K_L = K`,  `L0_R = L0_L = L0`  
**Asymmetric model**: independent `K_R`, `K_L`, `L0_R`, `L0_L`

Horizontal dynamics are frozen (`ẍ = 0`) in the symmetric model; full 2D dynamics are active in the asymmetric model.

---

## Adding a new subject

1. Open `config/get_subject_config.m`.
2. Copy an existing `case` block.
3. Set the subject number, `forward_axis` (`'X'` or `'Z'`), `segment_prefix`, thresholds, gender, and file names.
4. Place data files in the working directory and update the file names in the pipeline scripts.

---

## Cost function weights

The optimisers minimise:

```
cost = 100·MSE_y + 50·MSE_x + 0.1·MSE_vy + 10·MSE_vx
```

where `y` is COM vertical position and `x` is COM horizontal position relative to the foot midpoint.  
These weights can be adjusted in `functions/cost_fn_symmetric.m` and `functions/cost_fn_asymmetric.m`.

---

## Excel output columns

### 2-parameter file (`*_Leg_2_Param.xlsx`)
`Cut_Filename`, `GRF_Filename`, `Mass_Dyn_kg`, `k_L_Nm`, `L0_L_m`, `R2_L`, `RMSE_L`, `N_L`, `k_R_Nm`, `L0_R_m`, `R2_R`, `RMSE_R`, `N_R`

### 4-parameter file (`*_Leg_4_Param.xlsx`)
`Cut_Filename`, `GRF_Filename`, `Mass_Dyn_kg`,  
`k_L_Flex`, `L0_L_Flex`, `k_L_Ext`, `L0_L_Ext`, `E_diss_L_Raw`, `E_diss_L_Fit`,  
`k_R_Flex`, `L0_R_Flex`, `k_R_Ext`, `L0_R_Ext`, `E_diss_R_Raw`, `E_diss_R_Fit`

### Optimisation logs (`*_Log_Sym.xlsx`, `*_Log_Asym.xlsx`)
`Cut_Filename`, `Timestamp`, `Trial`, `Subject`, `Gender`, `Category`, reference parameters, optimised parameters, cost metrics, search bounds.

---

## License

This code is part of a bachelor's thesis project.  
Please cite appropriately if used in academic work.
