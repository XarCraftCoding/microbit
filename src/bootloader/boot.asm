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
	; Setup Data Segments
	mov ax, 0					; Can't Set DS/ES Directly
	mov ds, ax
	mov es, ax
	
	; Setup Stack
	mov ss, ax
	mov sp, 0x7C00
	
	; Some BIOS'es Might Start Us At 07C0:0000 Instead of 0000:7C00, Make Sure We Are In the
	; Expected Location
	push es				; Stack Grows Downwards From Where We Are Loaded In Memory
	push word .after
	retf

.after:

	; Read Something From Floppy Disk
	; BIOS Should Set DL to Drive Number
	mov [ebr_drive_number], dl

	; Show Loading Message
	mov si, msg_loading
	call puts

	; Read Drive Parameters (Sectors Per Track and Head Count),
	; Instead of Relaying on Data on Formatted Disk
	push es
	mov ah, 08h
	int 13h
	jc floppy_error
	pop es

	and cl, 0x3F						; Remove Top 2 Bits
	xor ch, ch
	mov [bdb_sectors_per_track], cx		; Sector Count

	inc dh
	mov [bdb_heads], dh					; Head Count

	; Compute LBA of Root Directory = Reserved + Fats * SectorsPerFat
	; * NOTE: This Section Can Be Hardcoded
	mov ax, [bdb_sectors_per_fat]
	mov bl, [bdb_fat_count]
	xor bh, bh
	mul bx								; DX:AX = (Fats * SectorsPerFat)
	add ax, [bdb_reserved_sectors]		; AX = LBA of Root Directory
	push ax

	; Compute Size of Root Directory = (32 * NumberOfEntries) / Bytes Per Sector
	mov ax, [bdb_sectors_per_fat]
	shl ax, 5							; AX *= 32
	xor dx, dx							; DX = 0
	div word [bdb_bytes_per_sector]		; Number of Sectors We Need to Read

	test dx, dx							; If DX != 0, Add 1
	jz .root_dir_after
	inc ax								; * Division Remainder != 0, Add 1
										; This Means We Have a Sector Only Partially Filled With Entries
.root_dir_after:

	; Read Root Directory
	mov cl, al							; CL = Number of Sectors to Read = Size of Root Directory
	pop ax								; AX = LBA of Root Directory
	mov dl, [ebr_drive_number]			; DL = Drive Number (We Saved It Previously)
	mov bx, buffer						; ES:BX = Buffer
	call disk_read

	; Search for kernel.bin
	xor bx, bx
	mov di, buffer

.search_kernel:
	mov si, file_kernel_bin
	mov cx, 11							; Compare Up to 11 Characters
	push di
	repe cmpsb
	pop di
	je .found_kernel

	add di, 32
	inc bx
	cmp bx, [bdb_dir_entries_count]
	jl .search_kernel

	; Kernel Not Found
	jmp kernel_not_found_error

.found_kernel:

	; DI Should Have the Address to the Entry
	mov ax, [di + 26]					; First Logical Cluster Field (Offset 26)
	mov [kernel_cluster], ax

	; Load FAT From Disk Into Memory
	mov ax, [bdb_reserved_sectors]
	mov bx, buffer
	mov cl, [bdb_sectors_per_fat]
	mov dl, [ebr_drive_number]
	call disk_read

	; Read Kernel and Process FAT Chain
	mov bx, KERNEL_LOAD_SEGMENT
	mov es, bx
	mov bx, KERNEL_LOAD_OFFSET

.load_kernel_loop:

	; Read Next Cluster
	mov ax, [kernel_cluster]

	; TODO: Make This Value Softcoded
	add ax, 31							; First Cluster = (Kernel_Cluster - 2) * SectorsPerCluster + StartSector
										; Start Sector = Reserved + FATS + Root Directory Size = 1 + 18 + 134 = 33
	mov cl, 1
	mov dl, [ebr_drive_number]
	call disk_read

	add bx, [bdb_bytes_per_sector]

	; Compute Location of Next Cluster
	mov ax, [kernel_cluster]
	mov cx, 3
	mul cx
	mov cx, 2
	div cx								; AX = Index of Entry In FAT, DX = Cluster Mod 2

	 mov si, buffer
	 add si, ax
	 mov ax, [ds:si]					; Read Entry From DAT Table at Index AX

	 or dx, dx
	 jz .even

.odd:
	shr ax, 4
	jmp .next_cluster_after

.even:
	and ax, 0x0FFF

.next_cluster_after:
	cmp ax, 0x0FF8						; End of Chain
	jae .read_finish

	mov [kernel_cluster], ax
	jmp .load_kernel_loop

.read_finish:

	; Jump tp Our Kernel
	mov dl, [ebr_drive_number]			; Boot Device In DL

	mov ax, KERNEL_LOAD_SEGMENT			; Set Segment Registers
	mov ds, ax
	mov es, ax

	jmp KERNEL_LOAD_SEGMENT:KERNEL_LOAD_OFFSET

	jmp wait_key_and_reboot				; Should Never Happen

	cli									; Disable Interrupts, This Way CPU Can't Get Out of "Halt" State
	hlt


;
; Error Handlers
;

floppy_error:
	mov si, msg_read_failed
	call puts
	jmp wait_key_and_reboot

kernel_not_found_error:
	mov si, msg_kernel_not_found
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
	mov dl, al
								; Restore DL
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


msg_loading:			db 'Loading...', ENDL, 0
msg_read_failed:		db 'Read from disk failed!', ENDL, 0
msg_kernel_not_found:	db 'KERNEL.BIN file not found!', ENDL, 0
file_kernel_bin:		db 'KERNEL  BIN'
kernel_cluster:			dw 0

KERNEL_LOAD_SEGMENT		equ 0x2000
KERNEL_LOAD_OFFSET		equ 0


times 510-($-$$) db 0
dw 0AA55h

buffer: