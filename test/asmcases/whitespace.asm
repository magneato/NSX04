        ; leading whitespace followed by ORG
        ORG 0x000
CONST    EQU 0x05

START:
        
        NOP
        
        ; blank line with spaces above
        JUN NextLabel

    ; random spaces in label casing
NextLabel:
        DB CONST , 0x02
        DW START
        BBL 0
