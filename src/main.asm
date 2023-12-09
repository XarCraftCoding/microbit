org 0x7C00
bits 16

%define ENDL 0x0D, 0x0A


start:
	jmp main


;
; Prints a String to the Screen
; Params:
;	- DS:SI Points to String
;
puts:
	; Save Registers We Will Modify
	push si
	push ax

.loop:
	lodsb				; Loads Next Character in AL
	or al, al			; Verify if Next Character is Null?
	jz .done

	mov ah, 0x0e		; Call BIOS Interrupt
	mov bh, 0
	int 0x10		
	
	jmp .loop

.done:
	pop ax
	pop si
	ret


main:

	; Setup Data Segments
	mov ax, 0 			; Can't Write to DS/ES Directly
	mov ds, ax
	mov es, ax

	; Setup Stack
	mov ss, ax
	mov sp, 0x7C00		; Stack Grows Downwards From Where We Are Loaded In Memory

	; Print Message
	mov si, msg
	call puts
	
	hlt

.halt:
	jmp .halt

msg: db 'Hello, World!', ENDL, 0


times 510-($-$$) db 0
dw 0AA55h
