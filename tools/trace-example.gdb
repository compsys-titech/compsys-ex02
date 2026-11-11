set pagination off
set confirm off
set remotetimeout 5
set history save off

define trace-fail
    printf "ERROR: %s\n", $arg0
    kill
    quit 1
end

# PCと全数値は実CPUから取得する．保存先は実際のswをデコードする．
define trace-row
    printf "%02d %-28s %08x %08x %08x %3d %3d %3d %08x\n", $row, $label, (unsigned int)$pc, (unsigned int)$sp, (unsigned int)$ra, $a0, $a1, $a2, (unsigned int)$s0
    x/i $pc
    if $have_ra
        printf "   saved ra [S%+d = 0x%08x] = 0x%08x\n", (int)($ra_slot - $S), $ra_slot, *(unsigned int*)$ra_slot
    end
    if $have_saved
        printf "   saved s%d [S%+d = 0x%08x] = 0x%08x\n", $saved_s_index, (int)($saved_slot - $S), $saved_slot, *(unsigned int*)$saved_slot
    end
    if $have_ra || $have_saved
        if (unsigned int)$sp == $S
            echo    frame released; the above addresses are fixed; bytes remain.\n
        end
    else
        echo    saved slots: not written yet.\n
    end
end

# 起動ROMから入口までを上限付きで実行する．
set $outer = (unsigned int)&add_then_sub
set $inner = (unsigned int)&add2
set $startup_steps = 0
while (unsigned int)$pc != $outer && $startup_steps < 64
    stepi
    set $startup_steps = $startup_steps + 1
end
if (unsigned int)$pc != $outer
    trace-fail "Did not reach add_then_sub within 64 instructions."
end

set $S = (unsigned int)$sp
set $R0 = (unsigned int)$ra
set $V = (unsigned int)$s0
set $x = (unsigned int)$a0
set $y = (unsigned int)$a1
set $z = (unsigned int)$a2
if $S % 16 != 0 || $R0 != (unsigned int)&example_return
    trace-fail "Invalid entry stack or return address."
end
set $F = 0
set $have_ra = 0
set $have_saved = 0
set $have_R1 = 0
set $R1 = 0
set $saved_reg = 0
set $inner_returned = 0
set $z_ready = 0
set $row = 0
set $label = "outer entry"
printf "\nEach row is BEFORE executing the displayed next instruction.\n"
printf "S=0x%08x R0=0x%08x V=0x%08x input=(%d,%d,%d)\n", $S, $R0, $V, $x, $y, $z
echo #  state                        PC       sp       ra        a0  a1  a2 s0\n
trace-row

while (unsigned int)$pc != $R0 && $row < 64
    set $bits = *(unsigned int*)$pc
    if ($bits & 3) != 3
        trace-fail "Unexpected non-32-bit instruction."
    end
    set $opcode = $bits & 127
    set $rd = ($bits >> 7) & 31
    set $funct3 = ($bits >> 12) & 7
    set $rs1 = ($bits >> 15) & 31
    set $rs2 = ($bits >> 20) & 31
    set $old_sp = (unsigned int)$sp
    set $is_store = $opcode == 0x23 && $funct3 == 2
    set $label = "after instruction"
    if $is_store
        set $offset = (int)((($bits >> 25) << 5) | (($bits >> 7) & 31))
        if $offset >= 2048
            set $offset = $offset - 4096
        end
        eval "set $base = (unsigned int)$x%d", $rs1
        eval "set $stored = (unsigned int)$x%d", $rs2
        set $slot = (unsigned int)($base + $offset)
        if $slot < $old_sp || $slot + 4 > $S
            trace-fail "Store outside the current frame."
        end
    end
    stepi
    if (unsigned int)$sp < $old_sp
        set $F = $S - (unsigned int)$sp
        set $label = "after frame allocation"
    end
    if (unsigned int)$sp > $old_sp
        set $label = "sp restored / before ret"
    end
    if $is_store
        if *(unsigned int*)$slot != $stored
            trace-fail "Saved memory differs from the CPU value."
        end
        if $rs2 == 1
            set $ra_slot = $slot
            set $saved_ra = $stored
            set $have_ra = 1
            set $label = "after save ra"
        else
            if ($rs2 >= 8 && $rs2 <= 9) || ($rs2 >= 18 && $rs2 <= 27)
                if $have_saved
                    trace-fail "Multiple callee-saved slots: review the trace."
                end
                set $saved_reg = $rs2
                set $saved_s_index = $rs2 < 10 ? $rs2 - 8 : $rs2 - 16
                set $saved_slot = $slot
                set $saved_value = $stored
                set $have_saved = 1
                set $label = "after saved-register store"
            else
                trace-fail "Unexpected saved register: review the trace."
            end
        end
    end
    if $opcode == 0x13 && $funct3 == 0 && $rs1 == 12 && ($bits >> 20) == 0 && $have_saved
        if $rd == $saved_reg
            eval "set $held_z = (unsigned int)$x%d", $saved_reg
            if $held_z != $z
                trace-fail "z was not copied to the saved register."
            end
            set $z_ready = 1
            set $label = "z ready / before call"
        end
    end
    if (unsigned int)$pc == $inner
        if $have_R1
            trace-fail "Unexpected repeated inner call."
        end
        set $R1 = (unsigned int)$ra
        set $have_R1 = 1
        set $label = "add2 entry"
        printf "R1=0x%08x (read from ra after the inner call)\n", $R1
    else
        if $have_R1 && $bits == 0x00008067 && (unsigned int)$pc == $R1
            set $inner_returned = 1
            eval "set $held_z = (unsigned int)$x%d", $saved_reg
            if !$z_ready || $held_z != $z
                trace-fail "z did not survive the inner call."
            end
            set $label = "inner return / before sub"
        else
            if $opcode == 0x33 && $rd == 10
                if $inner_returned
                    set $label = "after result operation"
                else
                    set $label = "after add / before ret"
                end
            end
        end
    end
    if $opcode == 0x03 && $funct3 == 2
        if $rd == 1
            set $label = "after restore ra"
        else
            set $label = "after saved-register load"
        end
    end
    if (unsigned int)$pc == $R0
        set $label = "outer return (R0)"
    end
    set $row = $row + 1
    trace-row
end

if !$have_R1 || !$inner_returned || !$have_ra || !$have_saved || !$z_ready
    trace-fail "Required call, saves, or z preservation was not observed."
end
if $F == 0 || $F % 16 != 0
    trace-fail "Invalid observed frame size."
end
if (unsigned int)$pc != $R0 || (unsigned int)$ra != $R0 || (unsigned int)$sp != $S || (unsigned int)$s0 != $V
    trace-fail "Outer return or register restoration failed."
end
eval "set $restored = (unsigned int)$x%d", $saved_reg
if $restored != $saved_value || $saved_ra != $R0
    trace-fail "Saved registers were not restored."
end
if *(unsigned int*)$ra_slot != $saved_ra || *(unsigned int*)$saved_slot != $saved_value
    trace-fail "Saved bytes unexpectedly changed."
end
if (unsigned int)$a0 != (unsigned int)($x + $y - $z)
    trace-fail "Incorrect calculated return value."
end
printf "Observed F=%d bytes; z held in s%d across the call.\n", $F, $saved_s_index
printf "Verified: PC=R0, ra=R0, sp=S, s0=V; return a0=%d.\n", $a0
kill
quit 0
