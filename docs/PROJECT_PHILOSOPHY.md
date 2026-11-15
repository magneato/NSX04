# NSX4004: The Geometric Proof
## Where Intelligence Meets Its Minimum Viable Substrate

*Made by Robert L. Sitton, Jr. of Neural Splines, LLC.*

*"Intelligence is not measured in transistors, but in transformations without transformers."*

---

## The Core Insight

While the world builds massive clusters to power trillion-parameter models, NSX4004 proves that neural learning fits in **288 bytes** (training) and **282 bytes** (inference) on a 4-bit Intel 4004 processor from 1971. This isn't minimalism for its own sake—it's discovering that intelligence is pattern transformation, not parameter bloat.

## The Three Pillars

### 1. **Substrate Independence**
Running neural networks on the Intel 4004 proves intelligence isn't tied to:
- Floating-point precision (we use signed 8-bit Q4.4 fixed-point on a 4-bit ALU)
- Modern instruction sets (we use 46 opcodes, zero hardware multiply)
- High clock speeds (740 kHz is enough)
- Large memory (< 300 bytes of ROM, 8 nibbles of RAM for weights)

### 2. **Algorithmic Compression**
Intelligence emerges from structure:
- **NomNom ROM Codebooks**: Fixed hidden-layer feature maps evaluated in a single `FIN` lookup
- **Zero-Multiply Binary Gates**: Conditional nibble addition instead of shift-and-add loops
- **Sign-Selected Perceptron Steps**: Discrete `±η` updates (`+0x02` / `-0x02`) without gradient multiply
- **Dual-Chiral Equilibrium**: Zero phase rupture between predictions and targets across the truth table

### 3. **The Nom Nom Philosophy**
- Consume exactly 4 bits at a time (the natural nibble)
- Every nibble is purposeful
- No wasted cycles, no excess precision

## Technical Artifacts
1. **`src/asm/tran4004.asm` (`288 bytes`)**: Full Q4.4 perceptron training converging to 0 errors in 6 epochs
2. **`src/asm/infr4004.asm` (`282 bytes`)**: Pre-trained 2→3→1 NAND inference in Q4.4
3. **`src/asm/ducker.asm` (`1,410 bytes`)**: 8086 DOS emulator for 4004 ROMs
4. **`scripts/sim4004.py`**: Cycle-accurate 4004 verifier integrated into CTest

---

*"The future was always in the past, waiting for someone to notice."*

— Robert L. Sitton, Jr. of Neural Splines, LLC
