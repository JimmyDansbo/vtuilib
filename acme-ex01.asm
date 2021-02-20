!cpu w65c02
*=$0801
!byte $0C,$08,$0A,$00,$9E,' ','2','0','6','4',$00,$00,$00
*=$0810
!src "vtuilib-acme.inc"

main:
	stz	xcord
	stz	ycord
	stz	newx
	stz	newy

	sec			; BANK 1
	jsr	vtui_set_bank

	stz	$9F20
	lda	#1
	sta	$9F21
	ldx	#64
	lda	#' '
	ldy	#$61
-	sta	$9F23
	sty	$9F23
	dex
	bne	-

	clc			; BANK 0
	jsr	vtui_set_bank

	lda	xcord
	ldy	ycord
	jsr	vtui_gotoxy

	lda	#7
	sta	r1l		; Width
	sta	r2l		; Height
	lda	#1		; Save to VRAM
	sec			; Bank 1
	stz	r0l		; ADDR $0000
	stz	r0h
	jsr	vtui_save_rect

	lda	#32		; X
	ldy	#30		; Y
	jsr	vtui_gotoxy

	lda	#<my_str	; Ptr to string in r0
	sta	r0l
	lda	#>my_str
	sta	r0h
	ldx	#$61		; Color
	lda	#1
	jsr	vtui_print_str

-	jsr	$FFE4		; GETIN
	beq	-
	cmp	#$9D		; Left arrow
	bne	@isup
	lda	newx
	beq	-
	dec	newx
	jsr	move_logo
	bra	-
@isup:	cmp	#$91		; Up arrow
	bne	@isright
	lda	newy
	beq	-
	dec	newy
	jsr	move_logo
	bra	-
@isright:
	cmp	#$1D		; Right arrow
	bne	@isdown
	lda	newx
	cmp	#73
	beq	-
	inc	newx
	jsr	move_logo
	bra	-
@isdown:
	cmp	#$11		; Down arrow
	bne	@end
	lda	newy
	cmp	#53
	beq	-
	inc	newy
	jsr	move_logo
	bra	-
@end:
	rts

move_logo:
	lda	xcord
	ldy	ycord
	jsr	vtui_gotoxy

	lda	#7
	sta	r1l		; Width
	sta	r2l		; Height
	lda	#1		; Restore from VRAM
	sec			; Bank 1
	stz	r0l		; ADDR $0100
	sta	r0h
	jsr	vtui_rest_rect

	lda	newx
	ldy	newy
	jsr	vtui_gotoxy

	lda	#7
	sta	r1l		; Width
	sta	r2l		; Height
	lda	#1		; Save to VRAM
	sec			; Bank 1
	stz	r0l		; ADDR $0100
	sta	r0h
	jsr	vtui_save_rect

	lda	newx
	ldy	newy
	jsr	vtui_gotoxy

	lda	#7
	sta	r1l		; Width
	sta	r2l		; Height
	lda	#1		; Restore from VRAM
	sec			; Bank 1
	stz	r0l		; ADDR $0000
	stz	r0h
	jsr	vtui_rest_rect

	lda	newx
	sta	xcord
	lda	newy
	sta	ycord
	rts

my_str	!text	"USE ARROW KEYS!",0
xcord	!byte	0
ycord	!byte	0
newx	!byte	0
newy	!byte	0
