        .exportzp usr_irq
        
        .zeropage        
usr_irq:                .res 2, 0  ; the jump vector for user IRQ routines