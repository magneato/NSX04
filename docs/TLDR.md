# 🧠 NSX4004 TLDR — Intel 4004 Neural Network Project

**Who is this for?** This brief overview is designed for ADHD adults and autistic folks who prefer concise, visual summaries. It boils down a complex retro‑computing project into digestible pieces.

## 🚀 What’s NSX4004?

NSX4004 is an experiment proving you can train and run a tiny neural network (a NAND gate) on a **1971 Intel 4004** microprocessor. The 4004 has only **2,300 transistors**, yet this project shows it can still learn. Modern tools assemble the code and an 8086 emulator (DUCKER) lets the 4004 run in a 2025 PC. This demonstrates **substrate independence**—the idea that intelligence doesn’t require billions of transistors.

## 🧩 How It Works

- **Neural network topology:** 2 inputs → 3 hidden neurons → 1 output (implements NAND logic).
- **Extreme Learning Machine (ELM):** Hidden weights are assigned random values once and **never updated**. Only the output weights and bias learn via a simple **perceptron rule**.
- **Fixed‑point math:** All numbers use **Q4.4** (4 bits integer, 4 bits fraction). This means there are 16 levels between 0 and 1, with a resolution of 0.0625.
- **Step activation:** After summing the weighted inputs plus bias, the neuron outputs 1.0 (0x10) if the value ≥ 0.5 and 0.0 (0x00) otherwise.
- **Training:** The 4004 loops through 4 input/output samples for the NAND gate. If the prediction is wrong, it updates the output weight by `Δw = η × error × hidden_activation`, where `η` is the learning rate. Training stops when there are zero errors or after a maximum number of epochs.

## 🛠️ Files & Components

| File | Purpose | Notes |
|-----|---------|------|
| **src/asm/tran4004.asm** | 4004 assembly that trains the NAND network using ELM/perceptron updates | Hidden weights randomised once; output weights updated until no errors |
| **src/asm/infr4004.asm** | 4004 assembly that performs inference using the trained weights | Reads fixed weights from ROM and runs a forward pass |
| **src/asm/ducker.asm / DUCKER.COM** | 8086 emulator that runs the 4004 ROMs | Assembled with NASM; includes support for custom traps (DuckOps) |
| **scripts/duckasm.py** | Preprocessor that expands custom pseudo‑ops (DuckOps) in `.ASM` files | Optional; used when you need host‑side I/O |
| **scripts/asm4004_lite.py** | Lightweight Python assembler for a subset of Intel 4004 opcodes | Converts `.ASM` to `.ROM` and produces `.lst` listings |
| **BUILD_GUIDE.md** | Step‑by‑step build instructions | Shows how to assemble and run the project |
| **README_DUCKER.md** | Detailed explanation of the emulator and neural network | For deeper reading |

## 📦 Running the Project (overview)

1. Install prerequisites: Python 3, NASM and DOSBox.
2. Assemble the ROMs with the provided scripts:
   ```bash
   python3 scripts/duckasm.py src/asm/tran4004.asm -o TRAN4004.exp.asm
   python3 scripts/asm4004_lite.py TRAN4004.exp.asm -o TRAN4004.ROM -l TRAN4004.lst
   python3 scripts/asm4004_lite.py src/asm/infr4004.asm -o INFR4004.ROM -l INFR4004.lst
   nasm src/asm/ducker.asm -o DUCKER.COM
   ```
3. Launch **DOSBox** and run:
   ```
   DUCKER.COM TRAN4004.ROM
   DUCKER.COM INFR4004.ROM
   ```
4. You should see training epochs counted until zero errors, then the NAND output printed in the inference run.

## 🌈 Why It Matters

- It’s a tangible demonstration that **learning isn’t about transistor count**. A 4‑bit CPU can emulate simple neural learning if the algorithm is adapted.
- **ELM/perceptron** shows that you don’t need backpropagation; random features + simple updates work for linearly separable functions.
- The project is an approachable way to learn about assembly, emulation, and neural networks all at once.

## 🧠 Tips for Visual & ADHD Learners

- Break tasks into short steps (see build guide).
- Use the file table above as a checklist.
- Focus on the flow: randomise → train → infer.
- Remember: the hidden layer never changes; only the output layer learns.

Enjoy exploring the intersection of retro computing and AI!
