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


  LDA #$80
  STA x_pos_p1
  LDA #$ab
  STA y_pos_p1
  LDA #$00
  STA clock
  LDA #$00
  STA set_walking
  LDA #$00
  STA player_dir


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


.proc draw_playerR
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA

  LDA #$00   ;This second batch loads attributes for all the sprites and stores them
  STA $0202
  STA $0206
  STA $020a
  STA $020e

  LDA y_pos_p1 ; These next batches select the coordinates for each sprite
  STA $0200
  LDA x_pos_p1
  STA $0203

  LDA y_pos_p1
  STA $0204
  LDA x_pos_p1
  CLC
  ADC #$08
  STA $0207

  LDA y_pos_p1
  CLC
  ADC #$08
  STA $0208
  LDA x_pos_p1
  STA $020b

  LDA y_pos_p1
  CLC
  ADC #$08
  STA $020c
  LDA x_pos_p1
  CLC
  ADC #$08
  STA $020f

  PLA
  TAY
  PLA
  TAX
  PLA
  PLP
  RTS
.endproc

.proc draw_playerL
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA

  LDA #%01000000   ;This second batch loads attributes for all the sprites and stores them
  STA $0202
  STA $0206
  STA $020a
  STA $020e

  LDA y_pos_p1 ; These next batches select the coordinates for each sprite
  STA $0204
  LDA x_pos_p1
  STA $0207

  LDA y_pos_p1
  STA $0200
  LDA x_pos_p1
  CLC
  ADC #$08
  STA $0203

  LDA y_pos_p1
  CLC
  ADC #$08
  STA $020c
  LDA x_pos_p1
  STA $020f

  LDA y_pos_p1
  CLC
  ADC #$08
  STA $0208
  LDA x_pos_p1
  CLC
  ADC #$08
  STA $020b

  PLA
  TAY
  PLA
  TAX
  PLA
  PLP
  RTS
.endproc

.proc update_player
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA

LatchController: ;Tells First controller to check button status
  LDA #$01
  STA $4016
  LDA #$00
  STA $4016    

; Now, we iteratively check each button in the following order:
; A, B, Select, Start, Up, Down, Left, Right.

ReadA: 
  LDA $4016       ; First we check button A
  AND #%00000001  ; We only check the first bit (0) since we need the most recent press
  BEQ ReadADone   ; if button wasn't pressed, branch to next scan 
                  ; Otherwise, execute instructions here
  DEC y_pos_p1
ReadADone:        ; Scan for this button is done, go to the next, repeat for every button
  

ReadB: 
  LDA $4016       
  AND #%00000001  
  BEQ ReadBDone   
                  
  
  INC y_pos_p1
ReadBDone:        

ReadSelect: 
  LDA $4016       
  AND #%00000001  
  BEQ ReadSelectDone   
  
  ;Instruction for button would be here:

ReadSelectDone:       

ReadStart: 
  LDA $4016       
  AND #%00000001  
  BEQ ReadStartDone   
  
  ;Instruction for button would be here:

ReadStartDone:     

ReadUp: 
  LDA $4016       
  AND #%00000001  
  BEQ ReadUpDone  
  
  
  
  DEC y_pos_p1
  DEC y_pos_p1
ReadUpDone: 

ReadDown: 
  LDA $4016       
  AND #%00000001  
  BEQ ReadDownDone

  

  LDA y_pos_p1
  CMP #$C7
  BEQ ReadDownDone

  


  INC y_pos_p1
  

ReadDownDone: 

ReadLeft: 
  LDA $4016       
  AND #%00000001  
  BEQ ReadLeftDone 

  LDA x_pos_p1
  CMP #$00
  BEQ ReadLeftDone

  DEC x_pos_p1
  DEC x_pos_p1
  INC clock
  lda #$01
  sta set_walking
  lda #$01
  sta player_dir

ReadLeftDone: 
  lda #$00
  sta set_walking
  lda #$00
  sta clock
ReadRight: 
  LDA $4016       
  AND #%00000001  
  BEQ ReadRightDone 

  LDA x_pos_p1
  CMP #$f0
  BEQ ReadRightDone



  INC x_pos_p1
  INC x_pos_p1
  INC clock
  lda #$01
  sta set_walking
  lda #$00
  sta player_dir

ReadRightDone: 
  lda #$00
  sta set_walking
  lda #$00
  sta clock

exit_subroutine:
  PLA
  TAY
  PLA
  TAX
  PLA
  PLP
  RTS

.endproc

.proc animation_state_machine
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA


checkFalling:
  LDA y_pos_p1
  CMP #$C7
  BNE jump_animation
  

checkwalking:
  lda set_walking
  CMP #$00
  BNE donewalking
  jsr draw_standing_sprite1
donewalking:
  jsr walk_loop
  jmp checkFalling


jump_animation:
  jsr draw_jumping_sprite1
  


  PLA
  TAY
  PLA
  TAX
  PLA
  PLP
  RTS
.endproc




.proc draw_standing_sprite1
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA

  LDA #$00  
  STA $0201
  LDA #$01
  STA $0205
  LDA #$10
  STA $0209
  LDA #$11
  STA $020d

  PLA
  TAY
  PLA
  TAX
  PLA
  PLP
  RTS
.endproc

.proc draw_1stwalking_sprite1
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA

  LDA #$02  
  STA $0201
  LDA #$03
  STA $0205
  LDA #$12
  STA $0209
  LDA #$13
  STA $020d

  PLA
  TAY
  PLA
  TAX
  PLA
  PLP
  RTS
.endproc

.proc draw_2ndwalking_sprite1
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA

  LDA #$04  ;This first batch of selects the sprite via tiles and stores them
  STA $0201
  LDA #$04
  STA $0205
  LDA #$14
  STA $0209
  LDA #$15
  STA $020d

  PLA
  TAY
  PLA
  TAX
  PLA
  PLP
  RTS
.endproc

.proc draw_3rdwalking_sprite1
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA

  LDA #$06  
  STA $0201
  LDA #$07
  STA $0205
  LDA #$16
  STA $0209
  LDA #$17
  STA $020d

  PLA
  TAY
  PLA
  TAX
  PLA
  PLP
  RTS
.endproc

.proc draw_jumping_sprite1
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA

  LDA #$08  
  STA $0201
  LDA #$09
  STA $0205
  LDA #$18
  STA $0209
  LDA #$19
  STA $020d

  PLA
  TAY
  PLA
  TAX
  PLA
  PLP
  RTS
.endproc

.proc draw_hurt_sprite1
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA

  LDA #$0a  
  STA $0201
  LDA #$0b
  STA $0205
  LDA #$1a
  STA $0209
  LDA #$1b
  STA $020d

  PLA
  TAY
  PLA
  TAX
  PLA
  PLP
  RTS
.endproc

.proc draw_killed_sprite1
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA

  LDA #$0c  
  STA $0201
  LDA #$0d
  STA $0205
  LDA #$1c
  STA $0209
  LDA #$1d
  STA $020d

  PLA
  TAY
  PLA
  TAX
  PLA
  PLP
  RTS
.endproc

.proc gravity
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA

  LDA y_pos_p1
  CMP #$C7
  BEQ exit


  LDA x_pos_p1
  CMP #$68      
  BCC CheckPlattform 

  LDA x_pos_p1   
  CMP #$98    
  BCS CheckPlattform 

  LDA y_pos_p1  
  CMP #$ab   
  BEQ exit 


CheckPlattform:
  INC y_pos_p1 

exit:
  PLA
  TAY
  PLA
  TAX
  PLA
  PLP
  RTS
.endproc

.proc walk_loop
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA

  lda clock
  CMP #$10
  bcc drawwalk1
  CMP #$20
  bcc drawwalk2
  CMP #$30
  bcc drawwalk3

  drawwalk1:
  jsr draw_1stwalking_sprite1
  jmp exitwalk
drawwalk2:
  jsr draw_2ndwalking_sprite1
  jmp exitwalk
drawwalk3:
  jsr draw_3rdwalking_sprite1


exitwalk:
  PLA
  TAY
  PLA
  TAX
  PLA
  PLP
  RTS
.endproc




nmi:      ;Specifies interruptions for the rendering loops
  LDA #$00
  STA $2003
  LDA #$02
  STA $4014

  lda player_dir
  CMP #$00
  BEQ draw_player_right
  jsr draw_playerL    ;Uses variables in zero page RAM to draw character on screen
  jmp drawplayerleftdone
  draw_player_right:
    jsr draw_playerR
drawplayerleftdone:
  jsr update_player  ;Jump to subroutine that scans button presses to change sprite coordinates in zero page RAM
  jsr gravity
  jsr animation_state_machine
  
  


	LDA #$00
	STA $2005
	STA $2005

  


  LDA #%10010000  ;Turn on NMI's, makes sure sprites use 1st pattern table to render
  STA $2000
  LDA #%00011110  ;Basically enables screen
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
	.byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20 ;These are in hex for simplicity. Imported from NEXXT.
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

.segment "ZEROPAGE"
  x_pos_p1: .res 1 ;Initializes player x position in Zero page RAM
  y_pos_p1: .res 1 ;Initializes player y position in Zero page RAM
  clock: .res 1
  set_walking: .res 1
  player_dir: .res 1

.segment "CHARS" ;Import Spritesheets
.incbin "wars.chr" ;Spritesheets generated by NEXXT


