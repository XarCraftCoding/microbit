org 0x0
bits 16


%define ENDL 0x0D, 0x0A


start:
    ; Print Hello World Message
    mov si, msg_hello
    call puts

.halt:
    cli
    hlt

;
; Prints a String to the Screen
; Params:
;   - DS:SI Points to String
;
puts:
    ; Save Registers We Will Modify
    push si
    push ax
    push bx

.loop:
    lodsb               ; Loads Next Character in AL
    or al, al           ; Verify If Next Character is Null?
    jz .done

    mov ah, 0x0E        ; Call BIOS Interrupt
    mov bh, 0           ; Set Page Number to 0
    int 0x10

    jmp .loop

.done:
    pop bx
    pop ax
    pop si
    ret

msg_hello: db 'Hello world!', ENDL, 0