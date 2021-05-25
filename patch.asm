; DISCLAIMER: The new code is made to fit within the original ROM without expanding it (personal goal). Making it a bit less easy to read/port probably.

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

; CONFIG: ------------------------------------------------------------------------------------------

ORIGINAL_INTRO = 0

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

        ; play_music_track (50 bytes available)
        org     $6ac
play_music_track                                ; d0 = track id
        lea     MSU_COMM_CMD,a0
    if (ORIGINAL_INTRO)
        tst.b   d0
        bne.s   .play_cd_track
            bsr     pause_cd
            exg     d0,d7
            bra.s   alt_play_music_track
.play_cd_track
    endif
.msu_wait
            tst.b   $10(a0)
        bne.s   .msu_wait

        ; Load and send msu command
        lea     AUDIO_TBL.l,a1
        ext.w   d0
        add.w   d0,d0
        move.w  (a1,d0),d0
        move.w  d0,(a0)                         ; Send msu cmd
        addq.b  #1,$f(a0)                       ; Increment command clock

        ; Send stop command for original music
        moveq   #3,d0
        bra     original_music_driver_command_73c
        ; 50 bytes total

        org     $6de
alt_play_music_track                            ; d7 = track id

        ; music_driver_command (42 bytes available)
        ; 1 = ?
        ; 2 = start track (needs track id see play_music_track)
        ; 3 = stop play
        ; 4 = pause
        ; 5 = resume
        org     $73c
music_driver_command
        lea     MSU_COMM_CMD,a0
.msu_wait
            tst.b   $10(a0)
        bne.s   .msu_wait

        ; Stop/pause command
        btst    d0,#$18
        beq.s   .no_stop
            bsr     pause_cd
.no_stop
        ; Resume command
        cmpi.b  #5,d0
        bne.s   .no_resume
            bsr     resume_cd
.no_resume
        ; Run original code
        bra     original_music_driver_command_73c
        ; 36 bytes total

        ; Use the reserved/unused 68000 vector space (60 bytes available)
        org $0c
pause_cd
        move.w  #MSU_PAUSE,(a0)                 ; Send msu cmd
        addq.b  #1,$f(a0)                       ; Increment command clock
        rts

resume_cd
        move.w  #MSU_RESUME,(a0)                ; Send msu cmd
        addq.b  #1,$f(a0)                       ; Increment command clock
        rts

original_music_driver_command_73c
        ori     #$0700,sr
        move.w  #$0100,Z80_BUS_REQUEST
.z80_bus_req_wait
            btst    #0,Z80_BUS_REQUEST
        bne     .z80_bus_req_wait
        move.b  d0,$a00108
        clr.w   Z80_BUS_REQUEST
        andi    #~$0700,sr
        rts
    ; 60 bytes total

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

; MSU-MD DRIVER: -----------------------------------------------------------------------------------

        align 2
msu_driver
        incbin  "msu-drv.slz"
