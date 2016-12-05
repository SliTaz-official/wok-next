;***************************************************************
;****** This file is distributed under GPL
;***************************************************************
                ideal
                %crefref
                %noincl
                %nomacs
                p386

        group   DGROUP  _TEXT,_DATA
        assume  cs:DGROUP,ds:DGROUP

        segment _DATA byte public use16 'DATA'
msg_badcpu      db      "I need 386+ CPU in real mode or under VCPI manager",0
msg_badmapping  db      "VCPI: low 640k: need 1:1 mapping",0
        ends    _DATA

        segment _TEXT byte public use16 'CODE'

;***************************************************************
;int _is_vm86();
;****** Return: AX=1 - it is a 386+ in virtual86 mode with vcpi
;******         AX=0 - it is a 386+ in real mode
;******         otherwise abort program
;****** Uses:   Flags
;***************************************************************
        global  _is_vm86:near
        proc    _is_vm86 near

; Check for oldies
		mov	ah, 0F0h
		pushf
		push	ax		; < 286 : flags[12..15] are forced 1
		popf			; = 286 : flags[12..15] are forced 0
		pushf			; > 286 : only flags[15] is forced 0
		pop	dx
		popf
		add	dh,ah		; NS=386+, NC=286
		ifndef	NO386
                js	@@no_vcpi   	;it is a 86/186/286, not a 386+
		else
		js	@@ret
		endif
; Check for vm
                smsw    ax      ;SMSW cannot be trapped! :-)
                and     ax,1	;MSW_PE
; We're in vm
                jnz     check_vcpi

; It's a 386 in real mode, chk for paging (crazy but possible)
                mov     edx,cr0
                shl     edx,1   ;CR0_PG to CF
		jc	@@no_vcpi
@@ret:
                ret

;***************************************************************
;****** Helper: checks for vcpi
;***************************************************************
label   check_vcpi near
                push    ds
; Check whether it is safe to call 67h (we trust only known EMM managers)
                push    0
                pop     ds
                mov     ds,[word 67h*4+2]
                cmp     [dword 10+4],'0XXX'
                jne     @@skip
                mov     eax,'XMME'
                xor     eax,[dword 10]
        ; QMME also works (as told by <J.S.Peatfield@damtp.cambridge.ac.uk>)
                shl     eax,8
@@skip:
                pop     ds
                jne     @@no_vcpi

; Check emm manager status and version
                mov     ah,40h          ; get status
                int     67h
                test    ah,ah
                jnz     @@no_vcpi
                mov     ah,46h          ; get version
                int     67h
                test    ah,ah
                jnz     @@no_vcpi
                cmp     al,40h          ; version must be >= 4.0
                jb      @@no_vcpi
; Check vcpi manager status
              ;;mov     ax,5A01h        ; ALLOCATE RAW PAGES
              ;;mov     bx,4
              ;;int     67h
              ;;test    ah,ah
              ;;jnz     @@no_vcpi
              ;;push    dx              ;$ save handle
                mov     ax,0DE00h       ; check for vcpi present
                int     67h
                mov     al,1
                test    ah,ah
                jz      @@386vcpi
              ;;pop     dx              ;$ handle
              ;;mov     ax,4500h        ; DEALLOCATE PAGES
              ;;int     67h
@@no_vcpi:
		mov	bx,offset msg_badcpu
                extrn   die:near
godie:
		jmp	near die
@@386vcpi:
		mov	[_vcpi],al
                extrn   prepare_vcpi:near
		call	prepare_vcpi
;    get_vcpi_interface() || die("VCPI: low 640k: need 1:1 mapping");
                ;extrn   _get_vcpi_interface:near
		;call	_get_vcpi_interface
		mov	bx,offset msg_badmapping
		jz	godie
		ret

        endp    _is_vm86


;***************************************************************
;void dos_shutdown()
;***************************************************************
        global  dos_shutdown:near
        proc    dos_shutdown near

dos_shutdown:
		ifndef	NO386
		;pusha
		else
		;push	bp si di
		endif
		xor	bx,bx
		mov	ds,bx
		ifndef	NO386
		push	[dword bx+4]		; save step
		mov	ax,sp
		push	ss
		push	ax
		pop	[dword cs:sssp]
		else
		push	[word bx+6]	
		push	[word bx+4]		; save step
		mov	[word cs:sssp],sp
		mov	[word cs:sssp+2],ss
		endif
		;cmp	[byte bx+7],0F0h
		;jnc	notdos
		mov	[word bx+4],offset step19
		mov	[bx+6],cs
		pushf
		pop	ax
		inc	ah			; set TF
		push	ax
		popf
		jmp	small [dword bx+4*19h]
doiret:
		iret
sssp:
		dd	0
step19:
		push	bx
		push	ds
		mov	bx,sp
		lds	bx,[dword ss:bx+4]	; read cs:ip
		cmp	[word bx],19CDh		; int 19h ?
		pop	ds
		pop	bx
		jne	doiret
notdos:
		ifndef	NO386
		lss	sp,[dword cs:sssp]
		else
		lds	bx,[dword cs:sssp]
		push	ds
		pop	ss
		mov	sp,bx
		endif
		xor	bx,bx
		mov	ds,bx
		ifndef	NO386
		pop	[dword bx+4]		; restore step
		;popa
		else
		pop	[word bx+4]		; restore step
		pop	[word bx+6]
		;pop	di si bp
		endif
		push	cs
		pop	ds
		ret

        endp    dos_shutdown


;***************************************************************
;void memcpy32(u32 dstofs,u16 srcseg,u32 srcofs,u32 size);
;***************************************************************
;****** Uses:   Flags
;***************************************************************
        global  _memcpy32:near
        proc    _memcpy32 near

; rm32,imm16 helper
macro   addzx_e rm,i
        db      66h
        add     rm,i
        dw      0
endm
                arg     dstofs  :dword, \
                        srcseg  :word,  \
                        srcofs  :dword, \
                        sz      :dword  = PARAM_SIZE

                local   GDTR    :pword, \
                        oldGDTR :pword  = TEMP_SIZE

;****** Init ***************************************************
		push	bp
		mov	bp,sp
		sub	sp,TEMP_SIZE
                pushf
		cld
                push    ds es

			ifndef	NO386

                pushad
                movzx   esi,[srcseg]
                shl     esi,4
                add     [srcofs],esi
                mov     esi,[srcofs]
                mov     edi,[dstofs]

	ifndef	pm_only
		mov	eax,esi
		or	eax,edi
		shr	eax,20			; >1mb ?
                jnz     pmcopy
		mov	eax,esi
		shr	eax,4
		mov	edx,edi
		shr	edx,4
@@movlp:
		mov	ds,ax
		mov	es,dx
		inc	ax
		inc	dx
		xor	ecx,ecx
		mov	cl,0Fh
		and	si,cx
		and	di,cx
		inc	cx
                sub     [sz],ecx
            rep movsb
                ja	@@movlp
		jmp	done
	endif
pmcopy:
			else

		push	si
		xor	bx,bx
		xor	dx,dx
		xor	si,si
		mov	ax,[bp+si+8]		; srcseg
		call	near N_LXLSH@4
		add	[bp+si+10],ax		; srcofs lo
		adc	[bp+si+10+2],dx		; srcofs hi
@@2flat:
		mov	ax,[bp+si+10]		; srcofs, dstofs lo
		mov	dx,[bp+si+10+2]		; srcofs, dstofs hi
		call	near N_LXURSH@4
		or	bx,dx			; >=1mb flag
		push	ax			; srcseg, dstseg
		xor	si,-6
		jnz	@@2flat
		pop	dx			; dstseg
		pop	ax			; srcseg
		or	bx,bx			; <1mb ?
                jnz     pmcopy
		push	di
@@movlp:
		mov	ds,ax
		mov	es,dx
		inc	ax
		inc	dx
		mov	cl,0Fh
		mov	si,cx
		mov	di,cx
		and	si,[word srcofs]
		and	di,[word dstofs]
		inc	cx
                sub     [word sz],cx
            rep movsb
		jae	@@movlp
		dec	[word sz+2]
                jns	@@movlp			; mov 1-16 more bytes...
		pop	di si
		jmp	done16
pmcopy:
		pop	si
                pushad
                mov     esi,[srcofs]
                mov     edi,[dstofs]

			endif

                mov     ecx,[sz]
                jecxz   done

		smsw	ax
		test	al,1
		jz	@@real_mode
; Note: bp points to std stack frame now. bp will be passed to
; pm routine. This allows params to be passed on stack
		extrn	do_memcpy_vcpi:near
                push    offset do_memcpy_vcpi
		extrn	call_pm_routine:near
                call    near call_pm_routine ; Call pm copy routine via vcpi pm
                pop     ax
		jmp	done
@@real_mode:
		mov	dx,-1

with_movsw:
                cmp     esi,edi
                jae     @@do_copy
                add     esi,ecx         ;src<dst: we must do
                dec     esi             ;  copy backwards to avoid
                add     edi,ecx         ;  overwrite bug
                dec     edi             ;
                std                     ;
@@do_copy:
                cli
                sgdt    [oldGDTR]

;****** Load gdtr **********************************************
                mov     eax,cs
                shl     eax,4
                addzx_e ax,<offset GDT>
                mov     [word GDTR],dx          ;GDT limit = 0FFFFh
                mov     [dword GDTR+2],eax      ;GDT base
                lgdt    [GDTR]

;****** Go into pm *********************************************
                mov     eax,cr0
                or      al,01h          ;CR0_PE on
                mov     cr0,eax
                jmp     short $+2       ;*Required*!
                                        ;3+ NOPs also work fine (chkd on 386)
;****** Move data **********************************************
                push    0008h
                pop     ds              ;base=0, lim = 4gb
                push    ds              ;
                pop     es              ;
                db      66h     ;operand width override for ecx
                db      67h     ;address width override for esi/edi
            rep movsb

;****** Return to rm *******************************************
                dec     ax              ;CR0_PE off
                mov     cr0,eax         ;ds/es limits are *not* reset to 64kb
                                        ;  but who cares :-)
                jmp     short $+2

;****** Return *************************************************
                lgdt    [oldGDTR]
done:
                popad
done16:
                pop     es ds
                popf
		mov	sp,bp
		pop	bp
                ret

;****** Const data *********************************************
                org     $-8     ;save 8 bytes - they are unused anyway
;0000: unused
GDT             dd      ?,?
;0008: Data seg [0,FFFFFFFF]
                ;       lim_lo              base_lo
                dw      1111111111111111b,  0000000000000000b
                db      00000000b,10010010b,10001111b,00000000b
                ;       base_med  P  S D A  G ??l_hi  base_hi
                ;                  Pl E W    D

        global  _vcpi:byte
_vcpi		db	0

        endp    _memcpy32

		ifdef	NO386
        global  N_LXURSH@:near
        global  N_LXURSH@4:near
        proc    N_LXURSH@4 near

		mov	cl,4
N_LXURSH@:
		mov	ch,0
@@loop:
		shr	dx,1
		rcr	ax,1
		loop	@@loop
		ret

        endp    N_LXURSH@4

        global  N_LXLSH@:near
        global  N_LXLSH@4:near
        proc    N_LXLSH@4 near

		mov	cl,4
N_LXLSH@:
		mov	ch,0
@@loop:
		shl	ax,1
		rcl	dx,1
		loop	@@loop
		ret

        endp    N_LXLSH@4

		endif

        ends    _TEXT

        end

;###### END OF FILE ############################################