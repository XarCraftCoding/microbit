org 0x7C00
bits 16


%define ENDL 0x0D, 0x0A


start:
	jmp main


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
	

main:
	; Setup Data Segments
	mov ax, 0           ; Can't Set DS/ES Directly
	mov ds, ax
	mov es, ax
	
	; Setup Stack
	mov ss, ax
	mov sp, 0x7C00      ; Stack Grows Downwards From Where We Are Loaded In Memory

	; Print Hello World Message
	mov si, msg
	call puts

	hlt

.halt
	jmp .halt



msg: db 'Hello world!', ENDL, 0


times 510-($-$$) db 0
dw 0AA55h