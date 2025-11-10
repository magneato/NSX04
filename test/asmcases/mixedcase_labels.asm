org 0x000

InitLabel:
    JUN runLoop

runloop:
    Kbp
    jCn 0x0F, endlabel
    JUN RUNLOOP

endLabel:
    BBL 0
