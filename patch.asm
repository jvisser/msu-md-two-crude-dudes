; Mega CD MMIO addresses used for communicating with msu-md driver on the mega cd (mode 1)
MSU_COMM_CMD        equ $a12010                 ; Comm command 0 (high byte)
MSU_COMM_ARG        equ $a12011                 ; Comm command 0 (low byte)
MSU_COMM_CMD_CK     equ $a1201f                 ; Comm command 7 (low byte)
MSU_COMM_STATUS     equ $a12020                 ; Comm status 0 (0-ready, 1-init, 2-cmd busy)

; msu-md commands
MSU_PLAY            equ $1100                   ; PLAY      decimal no. of track (1-99) playback will be stopped in the end of track
MSU_PLAY_LOOP       equ $1200                   ; PLAY LOOP decimal no. of track (1-99) playback will restart the track when end is reached
MSU_PAUSE           equ $1300                   ; PAUSE     vol fading time. 1/75 of sec. (75 equal to 1 sec) instant stop if 0 pause playback
MSU_RESUME          equ $1400                   ; RESUME    none. resume playback
MSU_VOL             equ $1500                   ; VOL       volume 0-255. set cdda volume
MSU_NOSEEK          equ $1600                   ; NOSEEK    0-on(default state), 1-off(no seek delays)  seek time emulation switch
MSU_PLAYOF          equ $1a00                   ; PLAYOF    #1 = decimal no. of track (1-99) #2 = offset in sectors from the start of the track to apply when looping play cdda track and loop from specified sector offset

Z80_BUS_REQUEST     equ $a11100

; Where to put the code
ROM_END             equ $ff814

; MACROS: ------------------------------------------------------------------------------------------

    macro MSU_WAIT
.\@
        tst.b   MSU_COMM_STATUS
        bne.s   .\@
    endm

    macro MSU_COMMAND cmd, param
        MSU_WAIT
        move.w  #(\1|\2),MSU_COMM_CMD           ; Send msu cmd
        addq.b  #1,MSU_COMM_CMD_CK              ; Increment command clock
    endm

; MEGA DRIVE OVERRIDES : ------------------------------------------------------------------------------------------

        ; M68000 Reset vector
        org     $4
        dc.l    ENTRY_POINT                     ; Custom entry point for redirecting

        org     $338                            ; Original ENTRY POINT
Game

        ; music_driver_play_track (50 bytes available)
        org     $6ac
music_driver_play_track                         ; d0 = track id
        MSU_WAIT
        lea     AUDIO_TBL.l,a1
        ext.w   d0
        add.w   d0,d0
        move.w  (a1,d0),d0
        move.w  d0,MSU_COMM_CMD                 ; Send msu cmd
        addq.b  #1,MSU_COMM_CMD_CK              ; Increment command clock
        rts
        ; 36 bytes total

        ; music_driver_command (42 bytes available)
        ; 1 = fade out
        ; 2 = start track (needs track id see music_driver_play_track)
        ; 3 = stop play
        ; 4 = pause
        ; 5 = resume
        org     $73c
music_driver_command                            ; d0 = command
        MSU_WAIT
        move.w  d0,d1
        ext.w   d1
        subq.w  #1,d1
        add.w   d1,d1
        lea     DRIVER_CMD_TBL,a1
        move.w  (a1,d1),d1
        move.w  d1,MSU_COMM_CMD                 ; Send msu cmd
        addq.b  #1,MSU_COMM_CMD_CK              ; Increment command clock
        rts
        ; 40 bytes total

; MSU-MD Init: -------------------------------------------------------------------------------------

        org     ROM_END
ENTRY_POINT
        bsr.s   audio_init
        jmp     Game.w

audio_init
        ; Decompress msu-md driver
        moveq   #-1,d0
        clr.w   d0                              ; $ffff0000
        movea.l d0,a5
        lea     msu_driver(pc),a6
        bsr.s   DecompressSlz

        ; Init msu-md driver (once initialized correctly the driver will be loaded into Mega CD PRG-RAM so we can discard the decompressed driver)
        movea.l d0,a5
        jsr     (a5)
        tst.b   d0                              ; if 1: no CD Hardware found
.audio_init_fail
        bne.s   .audio_init_fail                ; Loop forever

        MSU_COMMAND MSU_NOSEEK, 1
        MSU_COMMAND MSU_VOL,    255
        rts

    include "slz.asm"

; TABLES: ------------------------------------------------------------------------------------------

        align 2
AUDIO_TBL                                       ; #Track Name
        dc.w    MSU_PLAY|11                     ; 11 - Intro
        dc.w    MSU_PLAY_LOOP|01                ; 01 - Crude Buster - The Lifeline of New York - (BGM 1)
        dc.w    MSU_PLAY_LOOP|02                ; 02 - Funky Monsters (Boss 1)
        dc.w    MSU_PLAY|03                     ; 03 - Defeated Guys (Clear)
        dc.w    MSU_PLAY_LOOP|04                ; 04 - Take a Break (Beer)
        dc.w    MSU_PLAY_LOOP|05                ; 05 - Like a Hurricane (BGM 2)
        dc.w    MSU_PLAY_LOOP|06                ; 06 - Fallout of Christmas (BGM 3)
        dc.w    MSU_PLAY_LOOP|07                ; 07 - Kids in Battle (Boss 2)
        dc.w    MSU_PLAY_LOOP|08                ; 08 - The Wild Desire (BGM 4)
        dc.w    MSU_PLAY|09                     ; 09 - Justice has Won (Ending)
        dc.w    MSU_PLAY|10                     ; 10 - The Crude is Down (Game Over)

DRIVER_CMD_TBL
        dc.w    MSU_PAUSE|(75*2)
        dc.w    MSU_RESUME
        dc.w    MSU_PAUSE
        dc.w    MSU_PAUSE
        dc.w    MSU_RESUME

; MSU-MD DRIVER: -----------------------------------------------------------------------------------

        align 2
msu_driver
        incbin  "msu-drv.slz"
