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


  LDA #$30
  STA x_pos_p1
  LDA #$c0
  STA y_pos_p1
  LDA #$00 ;Ram Addr 0006
  STA clock
  LDA #$00
  STA player_dir
  LDA #$00
  STA timer
  LDA #$00
  STA seconds
  LDA #$00
  STA x_temporary_p1
  LDA #$00
  STA player_hurt
  LDA #$00
  STA player_dead
  LDA #$03
  STA player1_HP
  LDA #$00
  STA player_height
  LDA #$00
  STA player_jump
  LDA #$10
  STA heart_x_pos
  LDA #$10
  STA heart_y_pos
  LDA #$00 ;Ram Addr 000D
  STA player_attack
  LDA #$3f
  STA x_pos_p2
  LDA #$cf
  STA y_pos_p2

  


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

  jsr draw_HP
  INC timer ; Game timer runnning in Ram
  LDA timer
  CMP #$3A
  BEQ update_seconds
  jmp LatchController

update_seconds:
  INC seconds
  LDA #$00
  STA timer
  LDA x_pos_p1
  STA x_temporary_p1 


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
  LDA #$01
  STA player_hurt
  

skipReadAdone:
  jmp ReadB
ReadADone:        ; Scan for this button is done, go to the next, repeat for every button
  LDA #$00
  STA player_hurt

ReadB: 
  LDA $4016       
  AND #%00000001  
  BEQ ReadBDone

  LDA #$01
  STA player_attack               

skipReadBdone:
  jmp ReadSelect
ReadBDone:        
  LDA #$00
  STA player_attack

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
  LDA player1_HP        ; Load player HP
  CMP #$00
  BEQ ReadUpDone

  LDA $4016       
  AND #%00000001  
  BEQ ReadUpDone  
  
  LDA height
  CMP #$30
  BEQ ReadUpDone 

  INC height
  DEC y_pos_p1
  DEC y_pos_p1
ReadUpDone: 

ReadDown: 
  LDA player1_HP        ; Load player HP
  CMP #$00
  BEQ ReadDownDone

  LDA $4016       
  AND #%00000001  
  BEQ ReadDownDone

  
  LDA y_pos_p1
  CMP #$C7
  BEQ ReadDownDone

  


  INC y_pos_p1
  

ReadDownDone: 

ReadLeft: 
  LDA player1_HP        ; Load player HP
  CMP #$00
  BEQ ReadLeftDone

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
  sta player_dir

ReadLeftDone:
  jsr draw_standing_sprite1

ReadRight: 
  LDA player1_HP        ; Load player HP
  CMP #$00
  BEQ ReadRightDone

  LDA $4016       
  AND #%00000001  
  BEQ ReadRightDone 

  LDA x_pos_p1
  CMP #$f0
  BEQ ReadRightDone



  INC x_pos_p1
  INC x_pos_p1
  INC clock
  lda #$00
  sta player_dir

ReadRightDone:
  jsr draw_standing_sprite1

exit_subroutine:
  PLA
  TAY
  PLA
  TAX
  PLA
  PLP
  RTS

.endproc



.proc update_player2
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA




LatchController2: ;Tells First controller to check button status
  LDA #$01
  STA $4017
  LDA #$00
  STA $4017       

; Now, we iteratively check each button in the following order:
; A, B, Select, Start, Up, Down, Left, Right.

ReadA2: 
  LDA $4017       ; First we check button A
  AND #%00000001  ; We only check the first bit (0) since we need the most recent press
  BEQ ReadA2Done   ; if button wasn't pressed, branch to next scan 
                  ; Otherwise, execute instructions here
  LDA #$01
  STA player_hurt
  

skipReadA2done:
  jmp ReadB2
ReadA2Done:        ; Scan for this button is done, go to the next, repeat for every button
  LDA #$00
  STA player_hurt


ReadB2: 
  LDA $4017       
  AND #%00000001  
  BEQ ReadB2Done

  LDA #$01
  STA player_attack               

skipReadB2done:
  jmp ReadSelect2
ReadB2Done:        
  LDA #$00
  STA player_attack

ReadSelect2: 
  LDA $4017       
  AND #%00000001  
  BEQ ReadSelect2Done   
  
  ;Instruction for button would be here:

ReadSelect2Done:       

ReadStart2: 
  LDA $4017       
  AND #%00000001  
  BEQ ReadStart2Done   
  
  ;Instruction for button would be here:

ReadStart2Done:     

ReadUp2: 
  LDA player1_HP        ; Load player HP
  CMP #$00
  BEQ ReadUp2Done

  LDA $4017       
  AND #%00000001  
  BEQ ReadUp2Done  
  
  LDA height
  CMP #$30
  BEQ ReadUp2Done 

  INC height
  DEC y_pos_p1
  DEC y_pos_p1
ReadUp2Done: 

ReadDown2: 
  LDA player1_HP        ; Load player HP
  CMP #$00
  BEQ ReadDown2Done

  LDA $4017       
  AND #%00000001  
  BEQ ReadDown2Done

  
  LDA y_pos_p1
  CMP #$C7
  BEQ ReadDown2Done

  


  INC y_pos_p1
  

ReadDown2Done: 

ReadLeft2: 
  LDA player1_HP        ; Load player HP
  CMP #$00
  BEQ ReadLeft2Done

  LDA $4017       
  AND #%00000001  
  BEQ ReadLeft2Done 

  LDA x_pos_p1
  CMP #$00
  BEQ ReadLeft2Done

  DEC x_pos_p1
  DEC x_pos_p1
  INC clock
  lda #$01
  sta player_dir

ReadLeft2Done:
  jsr draw_standing_sprite1

ReadRight2: 
  LDA player1_HP        ; Load player HP
  CMP #$00
  BEQ ReadRight2Done

  LDA $4017       
  AND #%00000001  
  BEQ ReadRight2Done 

  LDA x_pos_p1
  CMP #$f0
  BEQ ReadRight2Done



  INC x_pos_p1
  INC x_pos_p1
  INC clock
  lda #$00
  sta player_dir

ReadRight2Done:
  jsr draw_standing_sprite1

exit_subroutin:
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

  LDA player1_HP        ; Load player HP
  CMP #$00
  BEQ dead_animation

  LDA player_hurt
  CMP #$01
  BEQ hurt_animation
  LDA player_attack
  CMP #$01
  BEQ attack_animation
  
  LDA y_pos_p1
  CMP #$ab
  BEQ donewalking

  LDA y_pos_p1
  CMP #$C7
  BNE jump_animation

donewalking:
  LDA x_temporary_p1
  CMP x_pos_p1
  BEQ standing_idle

  jsr walk_loop
  jmp checkFalling

standing_idle:
  jsr draw_standing_sprite1
  jmp checkFalling

attack_animation:
  jsr draw_attack_sprite1
  jmp finished
hurt_animation:
  jsr draw_hurt_sprite1

jump_animation:
  LDA player_hurt
  CMP #$00
  BNE hurt_animation

  jsr draw_jumping_sprite1
  jmp finished

dead_animation:
  jsr draw_killed_sprite1
  jsr draw_win_P2

finished:
  PLA
  TAY
  PLA
  TAX
  PLA
  PLP
  RTS
.endproc

.proc handle_player_hurt
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA

  LDA player1_HP        ; Load player HP
  CMP #$00              ; Compare with 0
  BEQ Done   ; If equal (dead), skip HP decrease

  LDA player_hurt       ; Load the current hurt status
  CMP #$00              ; Compare with 0
  BEQ NotHurt           ; If equal (not hurt), skip HP decrease

  LDA last_frame_hurt   ; Check if player was hurt in the last frame
  CMP #$01              ; Compare with 1
  BEQ AlreadyProcessed  ; If equal (already processed), skip HP decrease

  ; Decrease HP here
  DEC player1_HP
  LDA #$01
  STA last_frame_hurt   ; Set last_frame_hurt to true
  JMP Done

NotHurt:
  LDA #$00
  STA last_frame_hurt   ; Reset last_frame_hurt flag

AlreadyProcessed:
Done:
  PLA
  TAY
  PLA
  TAX
  PLA
  PLP
  RTS 
.endproc

.proc draw_HP
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA

  LDA player1_HP
  CMP #$00
  BEQ reduce3
  
  LDA #$10    ; Y position
  STA $0210   ; Assuming $0200 is the start of the next free OAM slot
  LDA #$20    ; Tile number for health
  STA $0211
  LDA #%00000000  ; Attributes (adjust as needed)
  STA $0212
  LDA #$10    ; X position
  STA $0213

  LDA player1_HP
  CMP #$01
  BEQ reduce2

  LDA #$10    ; Y position
  STA $0214   ; Assuming $0200 is the start of the next free OAM slot
  LDA #$20    ; Tile number for health
  STA $0215
  LDA #%00000000  ; Attributes (adjust as needed)
  STA $0216
  LDA #$20    ; X position
  STA $0217

  LDA player1_HP
  CMP #$02
  BEQ reduce1

  LDA #$10    ; Y position
  STA $0218   ; Assuming $0200 is the start of the next free OAM slot
  LDA #$20    ; Tile number for health
  STA $0219
  LDA #%00000000  ; Attributes (adjust as needed)
  STA $021a
  LDA #$30    ; X position
  STA $021b

  jmp leave

  reduce3:
    LDA #$30
    STA $0211
    jmp leave
  reduce2:
    LDA #$30
    STA $0215
    jmp leave
  reduce1:
    LDA #$30
    STA $0219
    jmp leave
leave:
  PLA
  TAY
  PLA
  TAX
  PLA
  PLP
  RTS 
.endproc

.proc draw_win_P2
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA

  LDA #$7d    ; Y position
  STA $0220   ; Assuming $0200 is the start of the next free OAM slot
  LDA #$28    ; Tile number for health
  STA $0221
  LDA #%00000001  ; Attributes (adjust as needed)
  STA $0222
  LDA #$50    ; X position
  STA $0223

  LDA #$7d    ; Y position
  STA $0224   ; Assuming $0200 is the start of the next free OAM slot
  LDA #$24    ; Tile number for health
  STA $0225
  LDA #%00000001  ; Attributes (adjust as needed)
  STA $0226
  LDA #$60    ; X position
  STA $0227

  LDA #$7d    ; Y position
  STA $0228   ; Assuming $0200 is the start of the next free OAM slot
  LDA #$25    ; Tile number for health
  STA $0229
  LDA #%00000001  ; Attributes (adjust as needed)
  STA $022a
  LDA #$80    ; X position
  STA $022b

  LDA #$7d    ; Y position
  STA $022c   ; Assuming $0200 is the start of the next free OAM slot
  LDA #$26    ; Tile number for health
  STA $022d
  LDA #%00000001  ; Attributes (adjust as needed)
  STA $022e
  LDA #$90    ; X position
  STA $022f

  LDA #$7d    ; Y position
  STA $0230   ; Assuming $0200 is the start of the next free OAM slot
  LDA #$27    ; Tile number for health
  STA $0231
  LDA #%00000001  ; Attributes (adjust as needed)
  STA $0232
  LDA #$A0    ; X position
  STA $0233

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
  LDA #$05
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

.proc draw_attack_sprite1
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA

  LDA #$0e  
  STA $0201
  LDA #$0f
  STA $0205
  LDA #$1e
  STA $0209
  LDA #$1f
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
  BEQ floor


  LDA x_pos_p1
  CMP #$68      
  BCC CheckPlattform 

  LDA x_pos_p1   
  CMP #$A0    
  BCS CheckPlattform 

  LDA y_pos_p1  
  CMP #$ab   
  BEQ floor 


CheckPlattform:
  INC y_pos_p1 
  jmp exit

floor:
  LDA #$00
  STA height

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
  CMP #$40
  bcc drawwalk2
  CMP #$50
  bcc drawwalk1
  CMP #$60
  bcc drawwalk2
  CMP #$70
  bcc drawwalk3
  CMP #$80
  bcc drawwalk2
  CMP #$90
  bcc drawwalk1
  CMP #$A0
  bcc drawwalk2
  CMP #$B0
  bcc drawwalk3
  CMP #$C0
  bcc drawwalk2
  CMP #$D0
  bcc drawwalk1
  CMP #$E0
  bcc drawwalk2
  CMP #$F0
  bcc drawwalk3
  CMP #$FE
  bcc drawwalk2

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

.proc jump_height
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA

  lda height
  CMP #$10
  bcc goingUp
  CMP #$20
  bcc goingUp
  CMP #$30
  
  
  jmp exitJump

  goingUp:
    INC height

exitJump:
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

  jsr handle_player_hurt

  lda player_dir
  CMP #$00
  BEQ draw_player_right
  jsr draw_playerL    ;Uses variables in zero page RAM to draw character on screen
  jmp drawplayerleftdone
  draw_player_right:
    jsr draw_playerR
drawplayerleftdone:
  jsr update_player  ;Jump to subroutine that scans button presses to change sprite coordinates in zero page RAM
  jsr update_player2
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
  .byte $0C, $31, $10, $38
  .byte $0C, $00, $00, $00
  .byte $0C, $06, $17, $28
  .byte $0C, $00, $00, $00

  ; Sprite Palettes
  .byte $0C, $07, $10, $37
  .byte $0C, $20, $2d, $2c
  .byte $0C, $2d, $21, $31
  .byte $0C, $00, $00, $00



hp1:
        ;Y   tile attribute   X
  .byte $10, $20, %00000000, $10 ;Attribute bits represent: VFlip, HFlip, 
  ;Front or behind background, unused, unused, unused, Pallete bit, Pallete bit

background:
	.byte $00,$00,$0a,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$00,$00,$00,$0a,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$0a,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$01,$00,$00,$02,$03,$00,$01,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$04,$05,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$06,$07,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$00,$01,$00,$00
	.byte $00,$00,$00,$00,$01,$00,$00,$08,$09,$00,$00,$00,$00,$00,$00,$01
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$12,$13,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$01,$00,$00,$14,$15,$00,$00,$00,$01,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01
	.byte $00,$00,$00,$00,$00,$0a,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$01,$00,$00,$00,$00,$00,$01,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0a,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$01,$00,$00,$00,$00,$01,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$01,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$0a,$00,$00,$00,$00,$01,$00
	.byte $00,$00,$00,$00,$01,$00,$00,$00,$00,$00,$00,$0a,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$16,$19,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$01,$00,$00,$00,$00,$00,$00,$00
	.byte $01,$00,$00,$00,$00,$16,$1a,$1a,$19,$00,$00,$00,$00,$00,$0b,$0c
	.byte $0c,$0c,$0c,$0c,$0d,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$16,$1a,$1a,$1a,$1a,$00,$00,$0a,$00,$00,$0e,$0f
	.byte $0f,$0f,$0f,$0f,$11,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$06,$1a,$1a,$1a,$1a,$1a,$07,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$00,$00
	.byte $19,$02,$03,$1a,$1a,$1a,$1a,$1a,$1a,$1a,$19,$16,$02,$03,$19,$00
	.byte $00,$00,$16,$17,$18,$19,$00,$16,$02,$03,$16,$19,$02,$03,$16,$17
	.byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
	.byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
	.byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
	.byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
	.byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
	.byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$a0,$20,$88,$aa,$22,$00,$00
	.byte $a8,$aa,$a2,$a8,$aa,$a2,$a0,$a0,$0a,$0a,$0a,$0a,$0a,$0a,$0a,$0a




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
  x_pos_p2: .res 1 ;Initializes player x position in Zero page RAM
  y_pos_p2: .res 1 ;Initializes player y position in Zero page RAM
  clock: .res 1
  player_dir: .res 1
  timer: .res 1
  seconds: .res 1
  x_temporary_p1: .res 1
  jump_status: .res 1
  height: .res 1
  player_hurt: .res 1
  player_dead: .res 1
  player1_HP: .res 1
  last_frame_hurt: .res 1 ; Flag to track if player was hurt last frame
  heart_x_pos: .res 1
  heart_y_pos: .res 1
  player_height: .res 1
  player_jump: .res 1

  player_attack: .res 1
  ; player2_HP: .res 1
  ; player2_dir: .res 1
  ; player2_fall: .res 1
  ; player2_jump: .res 1
  ; player2_hurt: .res 1
  ; player2_dead: .res 1
  ; player2_attack: .res 1

.segment "CHARS" ;Import Spritesheets
.incbin "wars.chr" ;Spritesheets generated by NEXXT


