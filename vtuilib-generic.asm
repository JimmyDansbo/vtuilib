!cpu w65c02
; Program counter is set to 0 to make it easier to calculate the addresses
; in the jumptable as all that needs to be done is add the actual offset.
*=$0000

; ******************************* Jumptable ***********************************
INIT:	bra	initialize	; No inputs
SCRS:	jmp	vtui_screen_set	; .A = Screenmode ($00, $02 or $FF)
SETB:	jmp	vtui_set_bank	; .C = bank number (0 or 1)
SETS:	jmp	vtui_set_stride	; .A = Stride value
SETD:	jmp	vtui_set_decr	; .C (1 = decrement, 0 = increment)
CLRS:	jmp	vtui_clr_scr	; .A = Character, .X = bg-/fg-color
GOTO:	jmp	vtui_gotoxy	; .A = x coordinate, .Y = y coordinate
PLCH:	jmp	vtui_plot_char	; .A = character, .X = bg-/fg-color
SCCH:	jmp	vtui_scan_char	; like plot_char
HLIN:	jmp	vtui_hline	; .A = Character, .Y = length, .X = color
VLIN:	jmp	vtui_vline	; .A = Character, .Y = height, .X = color
PSTR:	jsr	vtui_print_str	; r0 = pointer to string, .X = color
FBOX:	jmp	vtui_fill_box	; .A=Char,r1l=width,r2l=height,.X=color
P2SC:	jmp	vtui_pet2scr	; .A = character to convert to screencode
SC2P:	jmp	vtui_scr2pet	; .A = character to convert to petscii
BORD:	jsr	vtui_border	; .A=border,r1l=width,r2l=height,.X=color
SREC:	jmp	vtui_save_rect	; .C=vrambank,.A=destram,r0=destaddr,r1l=width,r2l=height
RREC:	jmp	vtui_rest_rect	; .C=vrambank,.A=srcram,r0=srcaddr,r1l=width,r2l=height
	jmp	$0000		; Show that there are no more jumps

; ******************************* Constants ***********************************
PLOT_CHAR	= $10		; zp jump to plot_char function
HLINE		= $13		; zp jump to hline function
VLINE		= $16		; zp jump to vline function
PET2SCR		= $19		; zp jump to pet2scr function

VERA_ADDR_L	= $9F20
VERA_ADDR_M	= $9F21
VERA_ADDR_H	= $9F22
VERA_DATA0	= $9F23
VERA_DATA1	= $9F24
VERA_CTRL	= $9F25

r0	= $02
r0l	= r0
r0h	= r0+1
r1	= $04
r1l	= r1
r1h	= r1+1
r2	= $06
r2l	= r2
r2h	= r2+1
r3	= $08
r3l	= r3
r3h	= r3+1
r4	= $0A
r4l	= r4
r4h	= r4+1
r5	= $0C
r5l	= r5
r5h	= r5+1
r6	= $0E
r6l	= r6
r6h	= r6+1

r7	= $10
r7l	= r7
r7h	= r7+1
r8	= $12
r8l	= r8
r8h	= r8+1
r9	= $14
r9l	= r9
r9h	= r9+1
r10	= $16
r10l	= r10
r10h	= r10+1
r11	= $18
r11l	= r11
r11h	= r11+1
r12	= $1A
r12l	= r12
r12h	= r12+1

; *************************** Internal Macros *********************************

; *****************************************************************************
; Increment 16bit value
; *****************************************************************************
; INPUT:	.addr = low byte of the 16bit value to increment
; *****************************************************************************
!macro INC16 .addr {
	inc	.addr
	bne	.end
	inc	.addr+1
.end:
}

; ******************************* Functions ***********************************

; *****************************************************************************
; Initialize the jumptable with correct addresses calculated from the address
; where this code is loaded.
; *****************************************************************************
; USES:		.A, .X & .Y
;		r0, r1, r2 & r3 (ZP addresses $02-$09)
; *****************************************************************************
initialize:
	; Write code to ZP to figure out where the library is loaded.
	; This is done by jsr'ing to the code in ZP which in turn reads the
	; return address from the stack.
OP_PHA	= $48		; PHA opcode
OP_PLA	= $68		; PLA opcode
OP_PHY	= $5A		; PHY opcode
OP_PLY	= $7A		; PLY opcode
OP_RTS	= $60		; RTS opcode

	lda	#OP_PLA
	sta	r0
	lda	#OP_PLY
	sta	r0+1
	lda	#OP_PHY
	sta	r0+2
	lda	#OP_PHA
	sta	r0+3
	lda	#OP_RTS
	sta	r0+4

	; Jump to the code in ZP that was just copied there by the code above.
	; This is to get the return address stored on stack
	jsr	r0		; Get current PC value
	sec
	sbc	#*-2		; Calculate start of our program
	sta	r0		; And store it in r0
	tya
	sbc	#$00
	sta	r0+1
	lda	r0		; Calculate location of first address in
	clc			; jump table
	adc	#$03
	sta	r1
	lda	r0+1
	adc	#$00
	sta	r1+1
	ldy	#$01		; .Y used for indexing high byte of pointers
	lda	(r1),y
	beq	@loop		; If high byte of pointer is 0, we can continue
	rts			; Otherwise initialization has already been run
@loop:	clc
	lda	(r1)		; Low part of jumptable address
	beq	@mightend	; If it is zero, we might have reaced the end of jumptable
	adc	r0l		; Add start address of our program to the jumptable address
	sta	(r1)
	lda	(r1),y
	adc	r0h
	sta	(r1),y
	bra	@prepnext
@mightend:
	adc	r0l		; Add start address of our program to the jumptable address
	sta	(r1)
	lda	(r1),y		; High part of jumptable address
	beq	@end		; If it is zero, we have reaced end of jumptable
	adc	r0h
	sta	(r1),y
@prepnext:			; Prepare r1 pointer for next entry in jumptable
	clc			; (add 3 to current value)
	lda	r1l
	adc	#$03
	sta	r1l
	lda	r1h
	adc	#$00
	sta	r1h
	bra	@loop
@end:	rts

; *****************************************************************************
; Use KERNAL API to set screen to 80x60 or 40x30 or swap between them.
; *****************************************************************************
; INPUT:		.A = Screenmode ($00, $02 or $FF)
; USES:			.A, .X & ,Y
; RETURNS:		.C = 1 in case of error.
; *****************************************************************************
vtui_screen_set:
	cmp	#0
	beq	@doset		; If 0, we can set mode
	cmp	#$02
	beq	@doset		; If 2, we can set mode
	cmp	#$FF
	bne	@end		; If $FF, we can set mode
@doset:	jsr	$FF5F		; screen_set_mode X16 kernal API call.
@end:
	rts

; *****************************************************************************
; Set VERA bank (High memory) without touching anything else
; *****************************************************************************
; INPUTS:	.C = Bank number, 0 or 1
; USES:		.A
; *****************************************************************************
vtui_set_bank:
	lda	VERA_ADDR_H
	bcc	@setzero
	; Bank = 1
	ora	#$01
	bra	@end
@setzero:
	; Bank = 0
	and	#$FE
@end:	sta	VERA_ADDR_H
	rts

; *****************************************************************************
; Set the stride without changing other values in VERA_ADDR_H
; *****************************************************************************
; INPUT:		.A = Stride value
; USES:			r0l
; *****************************************************************************
vtui_set_stride:
	asl			; Stride is stored in upper nibble
	asl
	asl
	asl
	sta	r0l
	lda	VERA_ADDR_H	; Set stride value to 0 in VERA_ADDR_H
	and	#$0F
	ora	r0l
	sta	VERA_ADDR_H
	rts

; *****************************************************************************
; Set the decrement value without changing other values in VERA_ADDR_H
; *****************************************************************************
; INPUT:		.C (1 = decrement, 0 = increment)
; USES:			.A
; *****************************************************************************
vtui_set_decr:
	lda	VERA_ADDR_H
	bcc	@setnul
	ora	#%00001000
	bra	@end
@setnul:
	and	#%11110111
@end:	sta	VERA_ADDR_H
	rts

; *****************************************************************************
; Write character and possibly color to current VERA address
; If VERA stride = 1 and decrement = 0, colorcode in X will be written as well.
; *****************************************************************************
; INPUTS:	.A = character
;		.X = bg-/fg-color
; USES:		.A
; *****************************************************************************
vtui_plot_char:
	sta	VERA_DATA0	; Store character
	lda	VERA_ADDR_H	; Isolate stride & decr value
	and	#$F7
	cmp	#$10		; If stride=1 & decr=0 we can write color
	bne	+
	stx	VERA_DATA0	; Write color
+	rts

; *****************************************************************************
; Read character and possibly color from current VERA address
; If VERA stride = 1 and decrement = 0, colorcode will be returned in X
; *****************************************************************************
; OUTPUS:	.A = character
;		.X = bg-/fg-color
; USES		.X
; *****************************************************************************
vtui_scan_char:
	ldx	VERA_DATA0	; Read character
	lda	VERA_ADDR_H	; Isolate stride & decr value
	and	#$F8
	cmp	#$10		; If stride=1 & decr=0 we can read color
	bne	+
	txa			; Move char to .A
	ldx	VERA_DATA0	; Read color
	bra	@end
+	txa			; Move char to .A
@end:	rts

; *****************************************************************************
; Create a horizontal line going from left to right.
; *****************************************************************************
; INPUTS:	.A	= Character to use for drawing the line
;		.Y	= Length of the line
;		.X	= bg- & fg-color
; *****************************************************************************
vtui_hline:
@loop:	sta	VERA_DATA0
	stx	VERA_DATA0
	dey
	bne	@loop
	rts

; *****************************************************************************
; Create a vertical line going from top to bottom.
; *****************************************************************************
; INPUTS:	.A	= Character to use for drawing the line
;		.Y	= Height of the line
;		.X	= bg- & fg-color
; *****************************************************************************
vtui_vline:
.loop:	sta	VERA_DATA0
	stx	VERA_DATA0
	dec	VERA_ADDR_L	; Return to original X coordinate
	dec	VERA_ADDR_L
	inc	VERA_ADDR_M	; Increment Y coordinate
	dey
	bne	.loop
	rts

; *****************************************************************************
; Set VERA address to point to specific point on screen
; *****************************************************************************
; INPUTS:	.A = x coordinate
;		.Y = y coordinate
; *****************************************************************************
vtui_gotoxy:
	sty	VERA_ADDR_M	; Set y coordinate
	asl			; Multiply x coord with 2 for correct coordinate
	sta	VERA_ADDR_L	; Set x coordinate
	rts

; *****************************************************************************
; Convert PETSCII codes between $20 and $5F to screencodes.
; *****************************************************************************
; INPUTS:	.A = character to convert
; OUTPUS:	.A = converted character or $56 if invalid input
; *****************************************************************************
vtui_pet2scr:
	cmp	#$20
	bcc	@nonprintable	; .A < $20
	cmp	#$40
	bcc	@end		; .A < $40 means screen code is the same
	; .A >= $40 - might be letter
	cmp	#$60
	bcs	@nonprintable	; .A < $60 so it is a letter, subtract ($3F+1)
	sbc	#$3F		; to convert to screencode
	bra	@end
@nonprintable:
	lda	#$56
@end:	rts

; *****************************************************************************
; Convert screencodes between $00 and $3F to PETSCII.
; *****************************************************************************
; INPUTS:	.A = character to convert
; OUTPUS:	.A = converted character or $76 if invalid input
; *****************************************************************************
vtui_scr2pet:
	cmp	#$40
	bcs	@nonprintable	; .A >= $40
	cmp	#$20
	bcs	@end		; .A >=$20 & < $40 means petscii is the same
	; .A < $20 and is a letter
	adc	#$40
	bra	@end
@nonprintable:
	lda	#$76
@end:	rts

; *****************************************************************************
; Print a 0 terminated PETSCII/Screencode string.
; *****************************************************************************
; INPUTS	.A = Convert string (0 = Convert from PETSCII, $80 = no conversion)
;		r0 = pointer to string
;		.X  = bg-/fg color (0 = don't change color)
; USES:		.A, .Y & r1l
; *****************************************************************************
vtui_print_str:
	sta	r1l

	lda	#$4C		; JMP absolute
	sta	PLOT_CHAR
	sta	PET2SCR

	pla			; Get low part of address and save i .Y
	tay
	sec
	sbc	#(PSTR-PLCH)+2	; Caculate low jumptable address of PLOT_CHAR
	sta	PLOT_CHAR+1
	pla			; Get high part of address and store in stack again
	pha
	sbc	#$00		; Calculate high jumptable addr of PLOT_CHAR
	sta	PLOT_CHAR+2

	tya			; Get low part of address
	clc
	adc	#(P2SC-PSTR)-2
	sta	PET2SCR+1
	pla
	adc	#$00
	sta	PET2SCR+2

	ldy	#0
@loop:	lda	(r0),y		; Load character
	beq	@end		; If 0, we are done
	iny
	bit	r1l		; Check if we need to convert character
	bmi	@noconv
	jsr	PET2SCR		; Do conversion
@noconv:
	jsr	PLOT_CHAR
	bra	@loop		; Get next character
@end:	rts

; *****************************************************************************
; Clear the entire screen with specific character and color
; *****************************************************************************
; INPUTS:	.A	= Character to use for filling
;		.X	= bg- & fg-color
; USES:		.Y, r1l & r2l
; *****************************************************************************
vtui_clr_scr:
	stz	VERA_ADDR_M	; Ensure VERA address is at top left corner
	stz	VERA_ADDR_L
	ldy	#80		; Store max width = 80 columns
	sty	r1l
	ldy	#60		; Store max height = 60 lines
	sty	r2l
	; this falls through to vtui_fill_box

; *****************************************************************************
; Create a filled box drawn from top left to bottom right
; *****************************************************************************
; INPUTS:	.A	= Character to use for drawing the line
;		r1l	= Width of box
;		r2l	= Height of box
;		.X	= bg- & fg-color
; *****************************************************************************
vtui_fill_box:
	ldy	VERA_ADDR_L
	sty	r0l
@vloop:	ldy	r0l		; Load x coordinate
	sty	VERA_ADDR_L	; Set x coordinate
	ldy	r1l
@hloop:	sta	VERA_DATA0
	stx	VERA_DATA0
	dey
	bne	@hloop
	inc	VERA_ADDR_M
	dec	r2l
	bne	@vloop
	rts

; *****************************************************************************
; Create a box with a specific border
; *****************************************************************************
; INPUTS:	.A	= Border mode (0-6) any other will default to mode 0
;		r1l	= width
;		r2l	= height
;		.X	= bg-/fg-color
; USES		.Y, r0l & r0h
; *****************************************************************************
vtui_border:
	; Define local variable names for ZP variables
	; Makes the source a bit more readable
@top_right=r3l
@top_left =r3h
@bot_right=r4l
@bot_left =r4h
@top	  =r5l
@bottom   =r5h
@left	  =r6l
@right	  =r6h

	; Set the border drawing characters according to the border mode in .A
@mode1: cmp	#1
	bne	@mode2
	lda	#$66
	bra	@def
@mode2: cmp	#2
	bne	@mode3
	lda	#$6E
	sta	@top_right
	lda	#$70
	sta	@top_left
	lda	#$7D
	sta	@bot_right
	lda	#$6D
	sta	@bot_left
@clines:
	lda	#$40		; centered lines
	sta	@top
	sta	@bottom
	lda	#$42
	sta	@left
	sta	@right
	bra	@dodraw
@mode3:	cmp	#3
	bne	@mode4
	lda	#$49
	sta	@top_right
	lda	#$55
	sta	@top_left
	lda	#$4B
	sta	@bot_right
	lda	#$4A
	sta	@bot_left
	bra	@clines
@mode4:	cmp	#4
	bne	@mode5
	lda	#$50
	sta	@top_right
	lda	#$4F
	sta	@top_left
	lda	#$7A
	sta	@bot_right
	lda	#$4C
	sta	@bot_left
@elines:
	lda	#$77		; lines on edges
	sta	@top
	lda	#$6F
	sta	@bottom
	lda	#$74
	sta	@left
	lda	#$6A
	sta	@right
	bra	@dodraw
@mode5:	cmp	#5
	bne	@mode6
	lda	#$5F
	sta	@top_right
	lda	#$69
	sta	@top_left
	lda	#$E9
	sta	@bot_right
	lda	#$DF
	sta	@bot_left
	bra	@elines
@mode6:	cmp	#6
	beq	@dodraw		; Assume border chars are already set
@default:
	lda	#$20
@def:	sta	@top_right
	sta	@top_left
	sta	@bot_right
	sta	@bot_left
	sta	@top
	sta	@bottom
	sta	@left
	sta	@right
@dodraw:

	lda	#$4C		; JMP absolute
	sta	PLOT_CHAR
	sta	HLINE
	sta	VLINE

	pla			; Get low part of address and save i .Y
	tay
	sec
	sbc	#(BORD-PLCH)+2	; Caculate low jumptable address of PLOT_CHAR
	sta	PLOT_CHAR+1
	pla			; Get high part of address and store in stack again
	pha
	sbc	#$00		; Calculate high jumptable addr of PLOT_CHAR
	sta	PLOT_CHAR+2

	tya			; Get low part of address
	sec
	sbc	#(BORD-HLIN)+2	; Calculate low jumptable address of HLINE
	sta	HLINE+1
	pla			; Get high part of address and store in stack again
	pha
	sbc	#$00		; Calculate high jumptable addr of HLINE
	sta	HLINE+2

	tya			; Get low part of address
	sec
	sbc	#(BORD-VLIN)+2	; Calculate low jumptable address of VLINE
	sta	VLINE+1
	pla
	sbc	#$00
	sta	VLINE+2

	; Save initial position
	lda	VERA_ADDR_L
	sta	r0l
	lda	VERA_ADDR_M
	sta	r0h
	ldy	r1l		; width
	dey
	lda	@top_left
	jsr	PLOT_CHAR	; Top left corner
	dey
	lda	@top
	jsr	HLINE		; Top line
	lda	@top_right
	jsr	PLOT_CHAR	; Top right corner
	dec	VERA_ADDR_L
	dec	VERA_ADDR_L
	inc	VERA_ADDR_M
	ldy	r2l		;height
	dey
	dey
	lda	@right
	jsr	VLINE		; Right line
	; Restore initial VERA address
	lda	r0l
	sta	VERA_ADDR_L
	lda	r0h
	inc
	sta	VERA_ADDR_M
	ldy	r2l		;height
	dey
	lda	@left
	jsr	VLINE		; Left line
	dec	VERA_ADDR_M
	lda	@bot_left
	jsr	PLOT_CHAR	; Bottom left corner
	ldy	r1l
	dey
	lda	@bottom
	JSR	HLINE		; Bottom line
	dec	VERA_ADDR_L
	dec	VERA_ADDR_L
	lda	@bot_right
	jsr	PLOT_CHAR	; Bottom right corner
	rts

; *****************************************************************************
; Copy contents of screen from current position to other memory area in
; either system RAM or VRAM
; *****************************************************************************
; INPUTS:	.C	= VRAM Bank (0 or 1) if .A=$80
;		.A	= Destination RAM (0=system RAM, $80=VRAM)
;		r0 	= Destination address
;		r1l	= width
;		r2l	= height
; USES:		r1h
; *****************************************************************************
vtui_save_rect:
	ldy	VERA_ADDR_L	; Save X coordinate for later
	sta	r1h		; Save destination RAM 0=sys $80=vram
	bit	r1h
	bpl	@skip_vram_prep
	lda	#1		; Set ADDRsel to 1
	sta	VERA_CTRL
	; Set stride and bank for VERA_DATA1
	lda	VERA_ADDR_H
	bcc	@bankzero
	and	#$0F		; Set stride to 0, leave rest alone
	ora	#$11		; Set stride to 1, bank to 1
	bra	@storeval
@bankzero:
	and	#$0E		; Set stride to 0, bank to 0, leave rest
	ora	#$10		; Set stride to 1, leave rest.
@storeval:
	sta	VERA_ADDR_H
	; Set destination address for VERA_DATA1
	lda	r0l
	sta	VERA_ADDR_L
	lda	r0h
	sta	VERA_ADDR_M
	stz	VERA_CTRL	; Set ADDRsel back to 0
@skip_vram_prep:
	ldx	r1l		; Load width
@loop:	lda	VERA_DATA0	; Load character
	bit	r1h
	bmi	@sto_char_vram
	sta	(r0)
	+INC16	r0
	bra	@get_col
@sto_char_vram:
	sta	VERA_DATA1
@get_col:
	lda	VERA_DATA0	; Load color code
	bit	r1h
	bmi	@sto_col_vram
	sta	(r0)
	+INC16	r0
	bra	@cont
@sto_col_vram:
	sta	VERA_DATA1
@cont:	dex
	bne	@loop
	ldx	r1l		; Restore width
	sty	VERA_ADDR_L	; Restore X coordinate
	inc	VERA_ADDR_M
	dec	r2l
	bne	@loop
	rts

; *****************************************************************************
; Restore contents of screen from other memory area in either system RAM
; or VRAM starting at current position
; *****************************************************************************
; INPUTS:	.C	= VRAM Bank (0 or 1) if .A=$80
;		.A	= Source RAM (0=system RAM, $80=VRAM)
;		r0 	= Source address
;		r1l	= width
;		r2l	= height
; *****************************************************************************
vtui_rest_rect:
	ldy	VERA_ADDR_L	; Save X coordinate for later
	sta	r1h		; Save source RAM 0=sys $80=vram
	bit	r1h
	bpl	@skip_vram_prep
	lda	#1		; Set ADDRsel to 1
	sta	VERA_CTRL
	; Set stride and bank for VERA_DATA1
	lda	VERA_ADDR_H
	bcc	@bankzero
	and	#$0F		; Set stride to 0, leave rest alone
	ora	#$11		; Set stride to 1, bank to 1
	bra	@storeval
@bankzero:
	and	#$0E		; Set stride to 0, bank to 0, leave rest
	ora	#$10		; Set stride to 1, leave rest.
@storeval:
	sta	VERA_ADDR_H
	; Set source address for VERA_DATA1
	lda	r0l
	sta	VERA_ADDR_L
	lda	r0h
	sta	VERA_ADDR_M
	stz	VERA_CTRL	; Set ADDRsel back to 0
@skip_vram_prep:
	ldx	r1l		; Load width
@loop:	bit	r1h
	bmi	@cpy_char_vram
	lda	(r0)		; Copy char from sysram
	+INC16	r0
	bra	@sto_char
@cpy_char_vram:
	lda	VERA_DATA1	; Copy char from VRAM
@sto_char:
	sta	VERA_DATA0	; Store char to screen
	bit	r1h
	bmi	@cpy_col_vram
	lda	(r0)		; Copy color from sysram
	+INC16	r0
	bra	@sto_col
@cpy_col_vram:
	lda	VERA_DATA1	; Copy color from VRAM
@sto_col:
	sta	VERA_DATA0	; Store color to screen
@cont:	dex
	bne	@loop
	ldx	r1l		; Restore width
	sty	VERA_ADDR_L	; Restore X coordinate
	inc	VERA_ADDR_M
	dec	r2l
	bne	@loop
	rts
