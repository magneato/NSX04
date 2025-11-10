; =========================================================
; NSX4004 Project - Intel 4004 Neural Network Experiments
; File: hell8086.asm
; Copyright (c) 2025 Neural Splines, LLC - Licensed under AGPL-3.0-or-later
; License: GNU AGPL-3.0-or-later
; =========================================================

; 8086 COM demo, assembled with NASM on Ubuntu
; Produces a flat .com binary for use in DOS/DOSBox

BITS 16
ORG 100h

start:
    mov  dx, msg
    mov  ah, 09h
    int  21h           ; print $-terminated string

    mov  ax, 4C00h
    int  21h           ; exit to DOS

msg db 'Hello from 8086 NASM (NSX4004)!$', 0
