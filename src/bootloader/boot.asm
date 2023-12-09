org 0x7C00
bits 16


%define ENDL 0x0D, 0x0A


;
; FAT12 Header
; 
jmp short start
nop

bdb_oem:					db 'MSWIN4.1'			; 8 Bytes
bdb_bytes_per_sector:		dw 512
bdb_sectors_per_cluster:	db 1
bdb_reserved_sectors:		dw 1
bdb_fat_count:				db 2
bdb_dir_entries_count:		dw 0E0h
bdb_total_sectors:			dw 2880					; 2880 * 512 = 1.44MB
bdb_media_descriptor_type:	db 0F0h					; F0 = 3.5" Floppy Disk
bdb_sectors_per_fat:		dw 9					; 9 Sectors/FAT
bdb_sectors_per_track:		dw 18
bdb_heads:					dw 2
bdb_hidden_sectors:			dd 0
bdb_large_sector_count:		dd 0

; Extended Boot Record
ebr_drive_number:			db 0					; 0x00 Floppy, 0x80 HDD, Useless
							db 0					; Reserved
ebr_signature:				db 29h
ebr_volume_id:				db 01h, 00h, 00h, 00h	; Serial Number, Value Doesn't Matter
ebr_volume_label:			db 'MICROBIT OS'		; 11 Bytes, Padded With Spaces
ebr_system_id:				db 'FAT12   '			; 8 Bytes

;
; Code Goes Here
;

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
	push bx

.loop:
	lodsb				; Loads Next Character in AL
	or al, al			; Verify If Next Character is Null?
	jz .done

	mov ah, 0x0E		; Call BIOS Interrupt
	mov bh, 0			; Set Page Number to 0
	int 0x10

	jmp .loop

.done:
	pop bx
	pop ax
	pop si
	ret


main:
	; Setup Data Segments
	mov ax, 0					; Can't Set DS/ES Directly
	mov ds, ax
	mov es, ax
	
	; Setup Stack
	mov ss, ax
	mov sp, 0x7C00				; Stack Grows Downwards From Where We Are Loaded In Memory

	; Read Something From Floppy Disk
	; BIOS Should Set DL to Drive Number
	mov [ebr_drive_number], dl

	mov ax, 1					; LBA = 1, Second Sector From Disk
	mov cl, 1					; 1 Sector to Read
	mov bx, 0x7E00				; Data Should Be After the Bootloader
	call disk_read

	; Print Hello World Message
	mov si, msg_hello
	call puts

	cli							; Disable Interrupts, This Way CPU Can't Get Out of "Halt" State
	hlt


;
; Error Handlers
;

floppy_error:
	mov si, msg_read_failed
	call puts
	jmp wait_key_and_reboot

wait_key_and_reboot:
	mov ah, 0
	int 16h						; Wait For Keypress
	jmp 0FFFFh:0				; Jump to Beginning of BIOS, Should Reboot

.halt:
	cli							; Disable Interrupts, This Way CPU Can't Get Out of "Halt" State
	hlt


;
; Disk Routines
;

;
; Converts an LBA Address to a CHS Address
; Parameters:
;	- AX: LBA Address
; Returns:
;	- CX [Bits 0-5]: Sector Number
;	- CX [Bits 6-15]: Cylinder
;	- DH: Head
;

lba_to_chs:

	push ax
	push dx

	xor dx, dx							; DX = 0
	div word [bdb_sectors_per_track]	; AX = LBA / SectorsPerTrack
										; DX = LBA % SectorsPerTrack

	inc dx								; DX = (LBA % SectorsPerTrack + 1) = Sector
	mov cx, dx							; CX = Sector

	xor dx, dx							; DX = 0
	div word [bdb_heads]				; AX = (LBA / SectorsPerTrack) / Heads = Cylinder
										; DX = (LBA / SectorsPerTrack) % Heads = Head
	mov dh, dl							; DH = Head
	mov ch, al							; CH = Cylinder (Lower 8 Bits)
	shl ah, 6
	or cl, ah							; Put Upper 2 Bits of Cylinder in CL

	pop ax
	mov dl, al							; Restore DL
	pop ax
	ret


;
; Reads Sectors From a Disk
; Parameters:
;	- AX: LBA address
;	- CL: Number of sectors to Read (Up to 128)
;	- DL: Drive Number
;	- ES:BX: Memory Address Where To Store Read Data
;
disk_read:

	push ax								; Save Registers We Will Modify
	push bx
	push cx
	push dx
	push di

	push cx								; Temporarily Save CL (Number of Sectors to Read)
	call lba_to_chs						; Compute CHS
	pop ax								; AL = Number of Sectors to Read
	
	mov ah, 02h
	mov di, 3							; Retry Count

.retry:
	pusha								; Save All Registers, We Don't Know What BIOS Modifies
	stc									; Set Carry Flag, Some BIOS'es Don't Set It
	int 13h								; Carry Flag Cleared = Success
	jnc .done							; Jump If Carry Not Set

	; Read Failed
	popa
	call disk_reset

	dec di
	test di, di
	jnz .retry

.fail:
	; All Attempts Are Exhausted
	jmp floppy_error

.done:
	popa

	pop di
	pop dx
	pop cx
	pop bx
	pop ax								; Restore Registers Modified
	ret


;
; Resets Disk Controller
; Parameters:
;	DL: Drive Number
;
disk_reset:
	pusha
	mov ah, 0
	stc
	int 13h
	jc floppy_error
	popa
	ret


msg_hello:              db 'Hello world!', ENDL, 0
msg_read_failed:        db 'Read from disk failed!', ENDL, 0

times 510-($-$$) db 0
dw 0AA55h