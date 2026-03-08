# Hardware Implementations of Deep Neural Networks using Various Multiplier Architectures

## Project Overview

This project explores the **hardware implementation of a Deep Neural Network (DNN) on FPGA** using different **multiplier architectures**. Neural networks require a large number of **multiply-accumulate (MAC) operations** during inference. The efficiency of these operations depends heavily on the **hardware multiplier design**, making multiplier architecture a critical component in neural network accelerators.

The objective of this work is to implement and evaluate different multiplier architectures within a **hardware neuron model written in Verilog HDL**, and analyze how these multipliers affect the neural network computation on FPGA.

The neural network used in this project is trained in **Python using the MNIST handwritten digit dataset**, and the trained parameters (weights and biases) are exported and integrated into the FPGA hardware design.

The final design is implemented and simulated using **Xilinx Vivado**, where the neural network hardware architecture is synthesized and tested.

---

# Neural Network Hardware Architecture

The hardware design models the operation of a neuron inside a neural network layer.

Each neuron performs the following operations:

1. Multiply inputs with their corresponding weights
2. Accumulate the results
3. Add bias
4. Apply an activation function

Mathematically, the neuron operation can be expressed as:

```
y = f( Σ (wi × xi) + b )
```

Where:

* `xi` = input values
* `wi` = weights
* `b` = bias
* `f()` = activation function

In this project, these computations are implemented directly in **Verilog hardware modules**.

Activation functions implemented include:

* **ReLU**
* **Sigmoid (implemented using lookup table ROM)**

---

# Multiplier Architectures in the Design

The performance of neural networks in hardware is highly dependent on the multiplier used during weight-input multiplication.

This project explores different multiplier implementations that can be used within the neuron computation.

The multiplier logic inside the neuron module can be modified to evaluate different architectures.

The following multiplier implementations are included in the repository:

* **DSP48 Baseline Multiplier (default implementation inside `neuron.v`)**
* **Booth Multiplier (`booth_mult.v`)**
* **Shared DSP Multiplier (`shared_dsp.v`)**

The default implementation in `neuron.v` uses the **DSP48-based multiplier**, which acts as the **baseline design**.

The multiplier architecture can be changed by **replacing the multiplication logic inside `neuron.v` with the code from the desired multiplier module**.

For example:

* If the **Booth multiplier code** is inserted inside `neuron.v`, the neuron computation will use the **Booth multiplier architecture**.
* If the **Shared DSP multiplier code** is inserted instead, the neuron computation will use the **shared DSP-based multiplication approach**.

This allows easy comparison between different multiplier architectures while keeping the rest of the neural network design unchanged.

---

# Repository Structure

```
DNN
│
├── booth_mult.v
├── shared_dsp.v
│
├── Tut-1
│   Hardware building blocks of the neural network
│
│   ├── neuron.v
│   ├── relu.v
│   ├── Sig_ROM.v
│   ├── Weight_Memory.v
│   ├── sigContent.mif
│   └── genSigmoid.py
│
├── Tut-2
│   Vivado FPGA implementation of the neural network
│
│   ├── myProject1
│   │   └── myProject1.xpr
│   │
│   ├── src
│   ├── zynet
│   ├── mnistZyNet.py
│   ├── zynet.tcl
│   └── weight and bias files
│
├── Tut-3
│   Neural network training and dataset preparation
│
│   ├── trainNN.py
│   ├── network2.py
│   ├── mnist_loader.py
│   ├── genTestData.py
│   ├── genWeightsAndBias.py
│   ├── mnist.pkl
│   ├── testData
│   └── w_b
│
└── Tut-4
    Additional testing scripts
```

---

# Description of Important Files

### neuron.v

Implements the **core neuron computation module**.
This module performs the weighted sum and applies the activation function.

The multiplication logic inside this file can be modified to test different multiplier architectures.

---

### relu.v

Implements the **ReLU activation function** used in the neural network.

---

### Sig_ROM.v

Implements the **Sigmoid activation function** using a **lookup table ROM**.

---

### Weight_Memory.v

Stores the trained **weights used by the neuron**.

---

### sigContent.mif

Memory initialization file used for the **sigmoid lookup table**.

---

### booth_mult.v

Contains the **Booth multiplier implementation** which can replace the default multiplication logic inside the neuron module.

---

### shared_dsp.v

Contains a **shared DSP-based multiplier architecture** designed for more efficient hardware utilization.

---

# Neural Network Training

The neural network used in this project is trained using Python scripts located in the `Tut-3` directory.

Key scripts include:

* `trainNN.py` – trains the neural network
* `network2.py` – neural network architecture definition
* `mnist_loader.py` – loads the MNIST dataset
* `genWeightsAndBias.py` – converts trained weights into a format suitable for hardware implementation
* `genTestData.py` – generates input data for hardware testing

The trained parameters are exported and used by the hardware modules in the Vivado design.

The dataset used for training is the **MNIST handwritten digit dataset**.

---

# Opening the Vivado Project

The FPGA implementation is located in the `Tut-2` directory.

To open the project in Vivado:

1. Launch **Xilinx Vivado**
2. Click **Open Project**
3. Navigate to:

```
Tut-2/myProject1/myProject1.xpr
```

4. Open the project file

Vivado will automatically load the full design including source files, simulation files, and constraints.

---

# Tools Used

| Tool          | Purpose                       |
| ------------- | ----------------------------- |
| Python        | Neural network training       |
| Verilog HDL   | Hardware design               |
| Xilinx Vivado | FPGA synthesis and simulation |
| MNIST Dataset | Neural network training       |

---

# Author

**Akhilesh Bharadhwaj S**
B.Tech Electronics and Computer Engineering
VIT Chennai

**Joshittha K**
B.Tech VLSI and Design Engineering
VIT Chennai

