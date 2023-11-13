;Diego Luis Ignacio Rodriguez Quintero
.segment "HEADER"
  ; .byte "NES", $1A      ; iNES header identifier
  .byte $4E, $45, $53, $1A
  .byte 2               ; 2x 16KB PRG code
  .byte 1               ; 1x  8KB CHR data
  .byte $01, $00        ; mapper 0, vertical mirroring

.segment "VECTORS"
  ;; When an NMI happens (once per frame if enabled) the label nmi:
  .addr nmi
  ;; When the processor first turns on or is reset, it will jump to the label reset:
  .addr reset
  ;; External interrupt IRQ (unused)
  .addr 0

; "nes" linker config requires a STARTUP section, even if it's empty
.segment "STARTUP"

; Main code segment for the program
.segment "CODE"

reset:
  sei		; disable IRQs
  cld		; disable decimal mode
  ldx #$40
  stx $4017	; disable APU frame IRQ
  ldx #$ff 	; Set up stack
  txs		;  .
  inx		; now X = 0
  stx $2000	; disable NMI
  stx $2001 	; disable rendering
  stx $4010 	; disable DMC IRQs

;; first wait for vblank to make sure PPU is ready
vblankwait1:
  bit $2002
  bpl vblankwait1

clear_memory:
  lda #$00
  sta $0000, x
  sta $0100, x
  sta $0200, x
  sta $0300, x
  sta $0400, x
  sta $0500, x
  sta $0600, x
  sta $0700, x
  inx
  bne clear_memory

;; second wait for vblank, PPU is ready after this
vblankwait2:
  bit $2002
  bpl vblankwait2

main:
load_palettes:
  lda $2002 ;reads from the CPU-RAM PPU address register to reset it
  lda #$3f  ;loads the higher byte of the PPU address register of the palettes in a (we want to write in $3f00 of the PPU since it is the address where the palettes of the PPU are stored)
  sta $2006 ;store what's in a (higher byte of PPU palettes address register $3f00) in the CPU-RAM memory location that transfers it into the PPU ($2006)
  lda #$00  ;loads the lower byte of the PPU address register in a
  sta $2006 ;store what's in a (lower byte of PPU palettes address register $3f00) in the CPU-RAM memory location that transfers it into the PPU ($2006)
  ldx #$00  ;AFTER THIS, THE PPU-RAM GRAPHICS POINTER WILL BE POINTING TO THE MEMORY LOCATION THAT CONTAINS THE SPRITES, NOW WE NEED TO TRANSFER SPRITES FROM THE CPU-ROM TO THE PPU-RAM
            ;THE PPU-RAM POINTER GETS INCREASED AUTOMATICALLY WHENEVER WE WRITE ON IT

; NO NEED TO MODIFY THIS LOOP SUBROUTINE, IT ALWAYS LOADS THE SAME AMOUNT OF PALETTE REGISTER. TO MODIFY PALETTES, REFER TO THE PALETTE SECTION
@loop: 
  lda palettes, x   ; as x starts at zero, it starts loading in a the first element in the palettes code section ($0f). This address mode allows us to copy elements from a tag with .data directives and the index in x
  sta $2007         ;THE PPU-RAM POINTER GETS INCREASED AUTOMATICALLY WHENEVER WE WRITE ON IT
  inx
  cpx #$20

  bne @loop


load_sprites:
  LDX #$00

load_sprites_loop:
  LDA sprites, x
  STA $0200, x
  INX
  CPX #$c0
  BNE load_sprites_loop

load_background: 
  LDA $2002
  LDA #$20
  STA $2006
  LDA #$00
  STA $2006
  LDX #$00

LoadBackground1:
  LDA background, x
  STA $2007
  INX 
  BNE LoadBackground1
  LDX #$00

LoadBackground2:
  LDA background + 256, x
  STA $2007
  INX 
  BNE LoadBackground2
  LDX #$00

LoadBackground3:
  LDA background + 512, x
  STA $2007
  INX 
  BNE LoadBackground3
  LDX #$00

LoadBackground4:
  LDA background + 768, x
  STA $2007
  INX 
  BNE LoadBackground4


load_attributes:
  LDA $2002
  LDA #$23
  STA $2006
  LDA #$c0
  STA $2006
  LDX #$00

load_attributes_loop:
  LDA attributes, x
  STA $2007
  INX
  CPX #$08
  BNE load_attributes_loop


enable_rendering: ;
  lda #%10000000	; Enable NMI
  sta $2000
  lda #%00010000	; Enable Sprites
  sta $2001

forever: 
  jmp forever

nmi:      ;Specifies interruptions for the rendering loops
  LDA #$00
  STA $2003
  LDA #$02
  STA $4014
	LDA #$00
	STA $2005
	STA $2005

  LDA #%10010000
  STA $2000
  LDA #%00011110
  STA $2001

  RTI



palettes: 
  ;Background Palettes
  .byte $0C, $31, $20, $28
  .byte $0C, $17, $06, $28
  .byte $0C, $00, $00, $00
  .byte $0C, $00, $00, $00

  ; Sprite Palettes
  .byte $0C, $17, $10, $37
  .byte $0C, $20, $2d, $2c
  .byte $0C, $00, $00, $00
  .byte $0C, $00, $00, $00

sprites:
        ;Y   tile attribute   X
  .byte $40, $00, %00000000, $58 ;Attribute bits represent: VFlip, HFlip, 
  .byte $40, $01, %00000000, $60 ;Front or behind background, unused, unused, unused, Pallete bit, Pallete bit
  .byte $48, $10, %00000000, $58
  .byte $48, $11, %00000000, $60 ;Standing Sprite

  .byte $50, $02, %00000000, $58 
  .byte $50, $03, %00000000, $60 
  .byte $58, $12, %00000000, $58
  .byte $58, $13, %00000000, $60; Walking 1 Sprite

  .byte $60, $04, %00000000, $58 
  .byte $60, $05, %00000000, $60 
  .byte $68, $14, %00000000, $58
  .byte $68, $15, %00000000, $60 ; Walkiing 2 Srpite

  .byte $70, $06, %00000000, $58 
  .byte $70, $07, %00000000, $60 
  .byte $78, $16, %00000000, $58
  .byte $78, $17, %00000000, $60 ; Walking 3 Sprite

  .byte $80, $08, %00000000, $58 
  .byte $80, $09, %00000000, $60 
  .byte $88, $18, %00000000, $58
  .byte $88, $19, %00000000, $60 ; Jumping Sprite

  .byte $90, $0a, %00000000, $58 
  .byte $90, $0b, %00000000, $60 
  .byte $98, $1a, %00000000, $58
  .byte $98, $1b, %00000000, $60 ; Hurt Sprite

  .byte $40, $00, %01000000, $70 
  .byte $40, $01, %01000000, $68 
  .byte $48, $10, %01000000, $70
  .byte $48, $11, %01000000, $68 ;Standing Sprite (Horizontal Flip)

  .byte $50, $02, %01000000, $70 
  .byte $50, $03, %01000000, $68 
  .byte $58, $12, %01000000, $70
  .byte $58, $13, %01000000, $68; Walking 1 Sprite (Horizontal Flip)

  .byte $60, $04, %01000000, $70 
  .byte $60, $05, %01000000, $68 
  .byte $68, $14, %01000000, $70
  .byte $68, $15, %01000000, $68 ; Walkiing 2 Sprite (Horizontal Flip)

  .byte $70, $06, %01000000, $70 
  .byte $70, $07, %01000000, $68 
  .byte $78, $16, %01000000, $70
  .byte $78, $17, %01000000, $68 ; Walking 3 Sprite (Horizontal Flip)

  .byte $80, $08, %01000000, $70 
  .byte $80, $09, %01000000, $68 
  .byte $88, $18, %01000000, $70
  .byte $88, $19, %01000000, $68 ; Jumping Sprite (Horizontal Flip)

  .byte $90, $0a, %01000000, $70 
  .byte $90, $0b, %01000000, $68 
  .byte $98, $1a, %01000000, $70
  .byte $98, $1b, %01000000, $68 ; Hurt Sprite (Horizontal Flip)







background:
	.byte $10,$10,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20 ;Background bits, specifying positions similar to first project name bits
	.byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20 ;These are in hex for simplicity.
	.byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
	.byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
	.byte $20,$0a,$20,$20,$20,$20,$01,$20,$20,$20,$20,$01,$20,$20,$01,$20
	.byte $0a,$20,$20,$20,$01,$20,$20,$01,$20,$20,$20,$20,$20,$01,$20,$20
	.byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$01,$20,$20,$20,$20,$20,$20
	.byte $20,$0a,$20,$01,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
	.byte $20,$20,$01,$20,$02,$03,$20,$20,$20,$20,$20,$20,$01,$20,$01,$20
	.byte $20,$20,$01,$20,$20,$20,$10,$0a,$10,$01,$20,$20,$01,$20,$20,$20
	.byte $20,$20,$20,$20,$04,$05,$20,$01,$20,$20,$0a,$20,$20,$20,$20,$20
	.byte $20,$10,$10,$10,$0a,$10,$10,$10,$10,$10,$10,$10,$20,$20,$01,$20
	.byte $0a,$20,$20,$20,$20,$20,$06,$07,$20,$20,$0a,$20,$20,$20,$01,$20
	.byte $01,$10,$10,$0a,$10,$10,$10,$10,$10,$10,$10,$10,$20,$20,$20,$20
	.byte $20,$20,$20,$20,$01,$20,$08,$09,$20,$20,$20,$0a,$20,$01,$20,$20
	.byte $20,$10,$10,$20,$20,$20,$01,$10,$20,$10,$0a,$10,$20,$20,$0a,$20
	.byte $20,$20,$0a,$20,$20,$20,$20,$20,$20,$0a,$20,$20,$01,$20,$0a,$20
	.byte $20,$20,$01,$20,$20,$20,$20,$20,$10,$10,$10,$20,$20,$20,$20,$01
	.byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$0a,$20,$20,$01
	.byte $20,$20,$20,$20,$20,$01,$20,$20,$10,$10,$01,$20,$20,$20,$20,$20
	.byte $01,$20,$01,$20,$20,$20,$01,$20,$20,$0a,$20,$20,$0a,$20,$20,$20
	.byte $20,$20,$0a,$20,$20,$20,$20,$20,$01,$10,$20,$20,$20,$20,$01,$20
	.byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$0a
	.byte $20,$20,$20,$01,$20,$20,$20,$20,$20,$10,$20,$0a,$20,$20,$20,$20
	.byte $20,$20,$20,$20,$0a,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
	.byte $20,$20,$20,$20,$20,$20,$0a,$20,$20,$20,$20,$20,$20,$20,$20,$0a
	.byte $01,$20,$0a,$20,$20,$20,$20,$0a,$20,$20,$20,$20,$0a,$20,$20,$20
	.byte $20,$20,$20,$0a,$20,$20,$20,$01,$20,$20,$20,$20,$20,$20,$20,$20
	.byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
	.byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
	.byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
	.byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
	.byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
	.byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
	.byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
	.byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
	.byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
	.byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
	.byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
	.byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
	.byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
	.byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
	.byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
	.byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
	.byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
	.byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
	.byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$0b,$0c
	.byte $0c,$0c,$0c,$0d,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
	.byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$0e,$0f
	.byte $0f,$0f,$0f,$11,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
	.byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
	.byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
	.byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
	.byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$40,$50,$00,$00,$00
	.byte $50,$50,$50,$54,$55,$50,$50,$50,$05,$05,$05,$05,$05,$05,$05,$05



attributes:
  .byte $00, $00, $00, $00, $00, $00, $00, $00  ;Attribute nametable, specifies which palettes every background 
  .byte $00, $00, $00, $00, $00, $00, $00, $00  ;cuadrant uses.
  .byte $00, $00, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $00, $00, $00, $00, $00
  .byte $55, $55, $55, $55, $55, $55, $55, $55
  .byte $55, $55, $55, $55, $55, $55, $55, $55

.segment "CHARS" ;Import Spritesheets
.incbin "wars.chr" ;Spritesheets generated by NEXXT


