; ============================================================================
; boot.asm - lukOS boot sector (the only part of lukOS that is NOT written in
; acts; the BIOS needs raw machine code in the first 512 bytes of the disk).
;
; Job: the BIOS loads these 512 bytes to 0000:7C00 and jumps here.  We read
; the kernel (compiled from acts) from the following sectors into 0000:7E00
; and jump to it.
;
; Build:  nasm -f bin boot.asm -DKSECTORS=<kernel size in sectors> -o boot.bin
; (build.py computes KSECTORS for you.)
; ============================================================================
bits 16
org 0x7C00

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00          ; stack just below us, grows downward
    sti
    cld
    mov [drive], dl         ; BIOS tells us which drive we booted from

    mov bx, 0x7E00          ; ES:BX = where the next sector goes
    mov di, KSECTORS        ; sectors still to read
    mov word [lba], 1       ; kernel starts at disk sector 1 (0 = this one)

.next_sector:
    ; Floppy geometry: 18 sectors per track, 2 heads.  Convert the linear
    ; sector number (LBA) into the cylinder/head/sector the BIOS wants:
    ;   sector   = lba mod 18 + 1
    ;   head     = (lba / 18) mod 2
    ;   cylinder = (lba / 18) / 2
    mov ax, [lba]
    xor dx, dx
    mov si, 18
    div si                  ; ax = lba / 18, dx = lba mod 18
    inc dl
    mov cl, dl              ; CL = sector number (1..18)
    xor dx, dx
    mov si, 2
    div si                  ; ax = cylinder, dx = head
    mov ch, al              ; CH = cylinder
    mov dh, dl              ; DH = head
    mov dl, [drive]         ; DL = drive

    mov byte [tries], 3
.retry:
    mov ax, 0x0201          ; int 13h function 2: read 1 sector
    int 0x13
    jnc .ok
    xor ax, ax              ; error: reset the disk controller and try again
    int 0x13
    dec byte [tries]
    jnz .retry
    mov si, err_msg         ; gave up
    call print
.hang:
    hlt
    jmp .hang

.ok:
    add bx, 512
    inc word [lba]
    dec di
    jnz .next_sector

    mov dl, [drive]
    jmp 0x0000:0x7E00       ; run the kernel

print:                      ; print the 0-terminated string at DS:SI
    lodsb
    test al, al
    jz .done
    mov ah, 0x0E
    xor bh, bh
    int 0x10
    jmp print
.done:
    ret

drive:   db 0
tries:   db 0
lba:     dw 0
err_msg: db 'lukOS: disk read error', 0

times 510 - ($ - $$) db 0
dw 0xAA55                   ; boot signature: the BIOS only boots sectors with this
