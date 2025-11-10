#!/usr/bin/env python3
"""
AGI4004 Training Visualizer
"Watching 4 bits learn is surprisingly hypnotic"
"""

import numpy as np
import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation
import sys
import re

class NeuralVisualizer4004:
    """Visualizes neural network training on 4-bit architecture"""
    
    def __init__(self):
        self.fig, self.axes = plt.subplots(2, 2, figsize=(12, 10))
        self.fig.suptitle('AGI4004: Neural Training on 2,300 Transistors', 
                         fontsize=16, fontweight='bold')
        
        # Subplot configurations
        self.error_ax = self.axes[0, 0]
        self.weight_ax = self.axes[0, 1]
        self.arch_ax = self.axes[1, 0]
        self.nibble_ax = self.axes[1, 1]
        
        self.setup_plots()
        
    def setup_plots(self):
        """Initialize all subplot configurations"""
        
        # Error plot
        self.error_ax.set_title('Bresenham Gradient Descent')
        self.error_ax.set_xlabel('Epoch')
        self.error_ax.set_ylabel('Error (4-bit quantized)')
        self.error_ax.grid(True, alpha=0.3)
        
        # Weight distribution
        self.weight_ax.set_title('Weight Evolution (Q4.4 Fixed-Point)')
        self.weight_ax.set_xlabel('Weight Index')
        self.weight_ax.set_ylabel('Value (nibbles)')
        
        # Architecture diagram
        self.arch_ax.set_title('2-3-1 Neural Architecture')
        self.arch_ax.axis('off')
        self.draw_architecture()
        
        # Nibble consumption (nom nom)
        self.nibble_ax.set_title('Cookie Monster Consumption Rate')
        self.nibble_ax.set_xlabel('Time (740 Hz ticks)')
        self.nibble_ax.set_ylabel('Nibbles Consumed')
        
    def draw_architecture(self):
        """Draw the neural network architecture"""
        # Input layer
        for i in range(2):
            circle = plt.Circle((0.2, 0.3 + i*0.4), 0.08, 
                               color='lightblue', ec='black')
            self.arch_ax.add_patch(circle)
            self.arch_ax.text(0.2, 0.3 + i*0.4, f'X{i}', 
                            ha='center', va='center')
        
        # Hidden layer
        for i in range(3):
            circle = plt.Circle((0.5, 0.2 + i*0.3), 0.08, 
                               color='lightgreen', ec='black')
            self.arch_ax.add_patch(circle)
            self.arch_ax.text(0.5, 0.2 + i*0.3, f'H{i}', 
                            ha='center', va='center')
            
            # Connections from input
            for j in range(2):
                self.arch_ax.plot([0.28, 0.42], 
                                [0.3 + j*0.4, 0.2 + i*0.3], 
                                'k-', alpha=0.3)
        
        # Output layer
        circle = plt.Circle((0.8, 0.5), 0.08, 
                          color='salmon', ec='black')
        self.arch_ax.add_patch(circle)
        self.arch_ax.text(0.8, 0.5, 'Y', ha='center', va='center')
        
        # Connections to output
        for i in range(3):
            self.arch_ax.plot([0.58, 0.72], 
                            [0.2 + i*0.3, 0.5], 
                            'k-', alpha=0.3)
        
        self.arch_ax.set_xlim(0, 1)
        self.arch_ax.set_ylim(0, 1)
        
    def parse_training_log(self, logfile):
        """Parse training log from 4004 emulation"""
        epochs = []
        errors = []
        weights = []
        
        with open(logfile, 'r') as f:
            for line in f:
                # Parse epoch errors
                match = re.search(r'Epoch (\d+): (\d+) errors', line)
                if match:
                    epochs.append(int(match.group(1)))
                    errors.append(int(match.group(2)))
                
                # Parse weight updates (Q4.4 format)
                match = re.search(r'W\[(\d+)\] = 0x([0-9A-F]+)', line)
                if match:
                    idx = int(match.group(1))
                    val = int(match.group(2), 16)
                    # Convert Q4.4 to float
                    weight_val = (val >> 4) + (val & 0x0F) / 16.0
                    weights.append((idx, weight_val))
        
        return epochs, errors, weights
    
    def animate_training(self, logfile):
        """Animate the training process"""
        epochs, errors, weights = self.parse_training_log(logfile)
        
        def update(frame):
            # Update error plot
            if frame < len(errors):
                self.error_ax.clear()
                self.error_ax.plot(epochs[:frame+1], errors[:frame+1], 
                                 'b-', linewidth=2)
                self.error_ax.scatter(epochs[:frame+1], errors[:frame+1], 
                                    c='red', s=30)
                self.error_ax.set_title(f'BGD Convergence (Epoch {frame})')
                self.error_ax.set_xlabel('Epoch')
                self.error_ax.set_ylabel('Error Count')
                self.error_ax.grid(True, alpha=0.3)
                
                # Show convergence point
                if frame > 0 and errors[frame] == 0:
                    self.error_ax.axvline(x=frame, color='green', 
                                        linestyle='--', alpha=0.5)
                    self.error_ax.text(frame, max(errors)/2, 
                                     'Converged!', rotation=90, 
                                     color='green')
            
            # Update weight visualization
            if frame < len(weights) // 13:
                self.weight_ax.clear()
                current_weights = weights[frame*13:(frame+1)*13]
                if current_weights:
                    indices = [w[0] for w in current_weights]
                    values = [w[1] for w in current_weights]
                    self.weight_ax.bar(indices, values, color='purple', alpha=0.7)
                    self.weight_ax.set_title('Weight Distribution (Q4.4)')
                    self.weight_ax.set_xlabel('Weight Index')
                    self.weight_ax.set_ylabel('Value')
            
            # Nibble consumption animation (nom nom)
            self.nibble_ax.clear()
            nibbles_consumed = frame * 26  # 13 weights * 2 nibbles
            ticks = np.arange(0, frame * 100, 10)
            consumption = np.cumsum(np.random.poisson(4, len(ticks)))
            self.nibble_ax.plot(ticks, consumption, 'g-', linewidth=2)
            self.nibble_ax.fill_between(ticks, 0, consumption, alpha=0.3)
            self.nibble_ax.set_title(f'🍪 NOM NOM: {nibbles_consumed} nibbles')
            self.nibble_ax.set_xlabel('Clock Cycles @ 740 Hz')
            self.nibble_ax.set_ylabel('Nibbles Consumed')
            
            return self.error_ax, self.weight_ax, self.nibble_ax
        
        anim = FuncAnimation(self.fig, update, frames=len(errors), 
                           interval=200, repeat=True)
        
        plt.tight_layout()
        return anim
    
    def plot_final_results(self, logfile):
        """Generate final training summary plots"""
        epochs, errors, weights = self.parse_training_log(logfile)
        
        # Create figure with philosophy
        fig = plt.figure(figsize=(15, 10))
        fig.suptitle('AGI4004: Proof That Intelligence Fits in 640 Bytes', 
                    fontsize=18, fontweight='bold')
        
        # Add philosophical quote
        fig.text(0.5, 0.95, 
                '"While OpenAI needs 10 nuclear reactors, we need 4 bits"',
                ha='center', style='italic', fontsize=12)
        
        # Error convergence
        ax1 = plt.subplot(2, 3, 1)
        ax1.plot(epochs, errors, 'b-', linewidth=2, label='Training Error')
        ax1.fill_between(epochs, 0, errors, alpha=0.3)
        ax1.set_title('Convergence via BGD')
        ax1.set_xlabel('Epoch')
        ax1.set_ylabel('Errors')
        ax1.grid(True, alpha=0.3)
        ax1.legend()
        
        # Weight histogram
        ax2 = plt.subplot(2, 3, 2)
        final_weights = [w[1] for w in weights[-13:]]
        ax2.hist(final_weights, bins=16, color='purple', alpha=0.7, 
                edgecolor='black')
        ax2.set_title('Final Weight Distribution')
        ax2.set_xlabel('Weight Value (Q4.4)')
        ax2.set_ylabel('Count')
        
        # Efficiency comparison
        ax3 = plt.subplot(2, 3, 3)
        systems = ['4004\n(1971)', 'H100\n(2024)']
        transistors = [2300, 80e9]
        colors = ['green', 'red']
        ax3.bar(systems, np.log10(transistors), color=colors, alpha=0.7)
        ax3.set_title('Transistor Count (log scale)')
        ax3.set_ylabel('log₁₀(transistors)')
        
        # Power consumption
        ax4 = plt.subplot(2, 3, 4)
        power = [0.75, 700]  # Watts
        ax4.bar(systems, power, color=colors, alpha=0.7)
        ax4.set_title('Power Consumption')
        ax4.set_ylabel('Watts')
        
        # Training speed
        ax5 = plt.subplot(2, 3, 5)
        speed = [0.1, 0.00001]  # Seconds for NAND
        ax5.bar(systems, np.log10(speed), color=colors, alpha=0.7)
        ax5.set_title('Training Time (log scale)')
        ax5.set_ylabel('log₁₀(seconds)')
        
        # Efficiency metric
        ax6 = plt.subplot(2, 3, 6)
        efficiency = [100, 0.000003]  # Percentage
        ax6.bar(systems, np.log10(efficiency + 1e-10), color=colors, alpha=0.7)
        ax6.set_title('Computational Efficiency')
        ax6.set_ylabel('log₁₀(efficiency %)')
        
        plt.tight_layout()
        return fig

def main():
    """Main visualization entry point"""
    if len(sys.argv) < 2:
        print("Usage: visualize_training.py <logfile>")
        sys.exit(1)
    
    logfile = sys.argv[1]
    viz = NeuralVisualizer4004()
    
    # Generate static plot
    fig = viz.plot_final_results(logfile)
    plt.savefig('output/visualizations/training_summary.png', dpi=150)
    
    # Create animation
    anim = viz.animate_training(logfile)
    anim.save('output/visualizations/training_animation.gif', writer='pillow')
    
    print("✓ Visualizations saved to output/visualizations/")
    print("  - training_summary.png")
    print("  - training_animation.gif")
    
    plt.show()

if __name__ == '__main__':
    main()
