# 🔋 Model-Based Battery Management System (BMS)

### MATLAB → Simulink → Real-Time Embedded C | NASA Li-ion Dataset

[![MATLAB](https://img.shields.io/badge/MATLAB-R2023b-blue)](https://www.mathworks.com/)
[![C](https://img.shields.io/badge/C-99-green)](https://en.wikipedia.org/wiki/C99)
[![Simulink](https://img.shields.io/badge/Simulink-Validated-orange)](https://www.mathworks.com/products/simulink.html)
[![Dataset](https://img.shields.io/badge/Dataset-NASA%20PCoE-red)](https://www.nasa.gov/)

---

## 📌 Project Summary

End-to-end **model-based development of a real-time Battery Management System**:

➡ Data → MATLAB modelling → Simulink validation → production-ready embedded C

The system estimates:

* 🔋 State of Charge (SOC)
* 🛡️ State of Health (SOH)
* ⚠️ Safety states (fault handling)

using a **1-RC Equivalent Circuit Model + Extended Kalman Filter**, validated on real NASA aging data.

---

## ⭐ Key Results

| Metric                  | Performance              |
| ----------------------- | ------------------------ |
| Voltage RMSE (Embedded) | **37.6 mV**              |
| SOC Estimation Error    | **±5.43 %**              |
| Capacity Fade Tracked   | **28.7 %**               |
| Cycles Analyzed         | **168**                  |
| Safety FSM Tests        | **100 % Pass**           |
| Execution               | **Fixed-step real-time** |

---

## 🧠 System Architecture

```
INPUTS
  │  Voltage | Current | Temperature
  ▼
SAFETY LAYER
  • Fault detection
  • OV / UV protection
  • State machine
  ▼
BATTERY MODEL
  • 1-RC ECM
  • OCV-SOC relationship
  ▼
STATE ESTIMATION
  • EKF-based SOC
  ▼
HEALTH ESTIMATION
  • Capacity fade tracking
  ▼
OUTPUTS
  → SOC
  → SOH
```

---

## 🔬 Methods

### 1️⃣ Equivalent Circuit Model (1-RC)

State equations:

SOC[k+1] = SOC[k] + (I·Δt) / (3600·Q_nom)
V₁[k+1] = V₁[k]·e^(−Δt/τ) + I·R₁·(1 − e^(−Δt/τ))

Terminal voltage:

V = OCV(SOC) − V₁ − I·R₀

---

### 2️⃣ Parameter Identification

* Least-squares optimization
* Initial: τ = 80,000 s
* Embedded optimized: **τ = 20 s**

---

### 3️⃣ Extended Kalman Filter (EKF)

State vector:

x = [SOC  V₁]ᵀ

Measurement:

y = terminal voltage

---

### 4️⃣ SOH Estimation

* Cycle-wise coulomb counting
* Capacity fade monitoring
* End-of-life prediction (80%)

---

## 🗂 Repository Structure

```
battery-bms-model-based/
├── matlab/        # Data processing & modelling
├── simulink/      # Simulink validation
├── embedded_c/    # Real-time implementation
│   ├── inc/
│   ├── src/
│   ├── test/
│   └── build/
└── docs/          # Reports & results
```

---

## ▶️ How to Run

### MATLAB Pipeline

```matlab
cd matlab/00_setup
run setup.m

cd ../08_simulink_validation
run validate_simulink_ecm.m
```

### Simulink

```matlab
open_system('simulink/ecm_1rc')
sim('ecm_1rc')
```

### Embedded C (GCC)

```bash
cd embedded_c

gcc -o bms_test src/*.c test/test_bms.c -Iinc -lm
./bms_test
```

---

## ⚙️ Technical Stack

* MATLAB / Simulink
* Embedded C (C99)
* GCC
* Fixed-step discrete implementation
* Static memory allocation

---

## 🎯 Target Applications

* Electric Vehicles
* Energy Storage Systems
* Portable Electronics
* Real-time battery diagnostics

---

## 👨‍💻 Engineering Highlights

✔ Model-based design workflow
✔ Real dataset validation
✔ Embedded-ready architecture
✔ Safety-critical FSM
✔ Modular & testable codebase

---

## 📄 License

MIT License

---

## 📬 Contact

**Krupal Ashokkumar Babariya**
M.Sc. Electrical & Microsystems Engineering


