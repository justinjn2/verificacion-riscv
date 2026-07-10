`uvm_analysis_imp_decl(_mon)

class darksocv_scoreboard extends uvm_scoreboard;

    `uvm_component_utils(darksocv_scoreboard)

    uvm_analysis_imp_mon #(darksocv_item, darksocv_scoreboard) mon_imp;

    logic [31:0] ref_regs [0:15];
    logic [31:0] ref_mem [0:511];

    int instr_count;
    int instr_checks_executed;
    int instr_checks_passed;
    int instr_checks_failed;
    int checks_executed;
    int checks_passed;
    int checks_failed;
    logic [31:0] expected_next_pc;
    int pc_checks_executed;
    int pc_checks_passed;
    int pc_checks_failed;

    function new(string name = "darksocv_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        mon_imp = new("mon_imp", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        reset_model();
    endfunction

    function void reset_model();
        for (int i = 0; i < 16; i++) begin
            ref_regs[i] = 32'h00000000;
        end

        for (int i = 0; i < 512; i++) begin
            ref_mem[i] = 32'h00000013;
        end

        instr_count            = 0;
        instr_checks_executed  = 0;
        instr_checks_passed    = 0;
        instr_checks_failed    = 0;
        checks_executed        = 0;
        checks_passed          = 0;
        checks_failed          = 0;
        expected_next_pc       = 32'h00000000;
        pc_checks_executed     = 0;
        pc_checks_passed       = 0;
        pc_checks_failed       = 0;
    endfunction

    function logic [31:0] calc_next_pc(darksocv_item item);
        bit branch_taken;

        case (item.op)
            OP_JAL: begin
                return item.pc + item.imm;
            end

            OP_JALR: begin
                return (ref_regs[item.rs1] + item.imm) & 32'hffff_fffe;
            end

            OP_BEQ:  branch_taken = (ref_regs[item.rs1] == ref_regs[item.rs2]);
            OP_BNE:  branch_taken = (ref_regs[item.rs1] != ref_regs[item.rs2]);
            OP_BLT:  branch_taken = ($signed(ref_regs[item.rs1]) < $signed(ref_regs[item.rs2]));
            OP_BGE:  branch_taken = ($signed(ref_regs[item.rs1]) >= $signed(ref_regs[item.rs2]));
            OP_BLTU: branch_taken = (ref_regs[item.rs1] < ref_regs[item.rs2]);
            OP_BGEU: branch_taken = (ref_regs[item.rs1] >= ref_regs[item.rs2]);

            default: begin
                return item.pc + 32'd4;
            end
        endcase

        return branch_taken ? (item.pc + item.imm) : (item.pc + 32'd4);
    endfunction

    function void compare_pc(darksocv_item item);
        pc_checks_executed++;

        if (item.pc === expected_next_pc) begin
            pc_checks_passed++;
            `uvm_info(
                "SCB_PC",
                $sformatf("PASS PC instr[%0d]: esperado=0x%08h observado=0x%08h", item.item_index, expected_next_pc, item.pc),
                UVM_MEDIUM
            )
        end
        else begin
            pc_checks_failed++;
            `uvm_error(
                "SCB_PC",
                $sformatf("FAIL PC instr[%0d] %s: esperado=0x%08h observado=0x%08h", item.item_index, item.asm_text, expected_next_pc, item.pc)
            )
        end
    endfunction

    function logic [31:0] calc_result(darksocv_item item);
        logic [31:0] addr;

        case (item.op)
            OP_ADD: begin
                return ref_regs[item.rs1] + ref_regs[item.rs2];
            end

            OP_SUB: begin
                return ref_regs[item.rs1] - ref_regs[item.rs2];
            end

            OP_SLL: begin
                return ref_regs[item.rs1] << ref_regs[item.rs2][4:0];
            end

            OP_SLT: begin
                return ($signed(ref_regs[item.rs1]) < $signed(ref_regs[item.rs2])) ? 32'd1 : 32'd0;
            end

            OP_SLTU: begin
                return (ref_regs[item.rs1] < ref_regs[item.rs2]) ? 32'd1 : 32'd0;
            end

            OP_AND: begin
                return ref_regs[item.rs1] & ref_regs[item.rs2];
            end

            OP_OR: begin
                return ref_regs[item.rs1] | ref_regs[item.rs2];
            end

            OP_XOR: begin
                return ref_regs[item.rs1] ^ ref_regs[item.rs2];
            end

            OP_SRL: begin
                return ref_regs[item.rs1] >> ref_regs[item.rs2][4:0];
            end

            OP_SRA: begin
                return $signed(ref_regs[item.rs1]) >>> ref_regs[item.rs2][4:0];
            end

            OP_ADDI: begin
                return ref_regs[item.rs1] + item.imm;
            end

            OP_SLTI: begin
                return ($signed(ref_regs[item.rs1]) < $signed(item.imm)) ? 32'd1 : 32'd0;
            end

            OP_SLTIU: begin
                return (ref_regs[item.rs1] < item.imm) ? 32'd1 : 32'd0;
            end

            OP_XORI: begin
                return ref_regs[item.rs1] ^ item.imm;
            end

            OP_ORI: begin
                return ref_regs[item.rs1] | item.imm;
            end

            OP_ANDI: begin
                return ref_regs[item.rs1] & item.imm;
            end

            OP_SLLI: begin
                return ref_regs[item.rs1] << item.imm[4:0];
            end

            OP_SRLI: begin
                return ref_regs[item.rs1] >> item.imm[4:0];
            end

            OP_SRAI: begin
                return $signed(ref_regs[item.rs1]) >>> item.imm[4:0];
            end

            OP_LUI: begin
                return {item.imm[19:0], 12'h000};
            end

            OP_AUIPC: begin
                return item.pc + {item.imm[19:0], 12'h000};
            end

            OP_LW: begin
                addr = ref_regs[item.rs1] + item.imm;
                return ref_mem[addr[10:2]];
            end

            OP_SW: begin
                return 32'h00000000;
            end

            OP_BEQ, OP_BNE, OP_BLT, OP_BGE, OP_BLTU, OP_BGEU: begin
                return 32'h00000000;
            end

            OP_JAL, OP_JALR: begin
                return item.pc + 32'd4;
            end

            default: begin
                return 32'h00000000;
            end
        endcase
    endfunction

    function void write_mon(darksocv_item item);
        logic [31:0] expected;
        logic [31:0] expected_observed;
        logic [31:0] addr;

        `uvm_info("SCB", $sformatf("Instruccion recibida: %s", item.convert2string()), UVM_MEDIUM)

        compare_pc(item);
        expected = calc_result(item);
        item.expected_value = expected;
        expected_observed = (!item.writes_rd() || item.rd == 0) ? 32'h00000000 : expected;

        `uvm_info(
            "SCB",
            $sformatf(
                "Valor teorico calculado: instr=%s rd=x%0d expected=0x%08h",
                item.asm_text,
                item.rd,
                expected
            ),
            UVM_MEDIUM
        )

        compare_instruction(item, expected_observed);
        expected_next_pc = calc_next_pc(item);

        if (item.op == OP_SW) begin
            addr = ref_regs[item.rs1] + item.imm;
            ref_mem[addr[10:2]] = ref_regs[item.rs2];
        end

        if (item.writes_rd() && item.rd != 0) begin
            ref_regs[item.rd] = expected;
        end

        ref_regs[0] = 32'h00000000;
        instr_count++;

        if (item.has_final_snapshot) begin
            compare_final_snapshot(item);
            print_summary();
        end
    endfunction

    function void compare_instruction(darksocv_item item, logic [31:0] expected_observed);
        instr_checks_executed++;

        if (expected_observed === item.observed_value) begin
            instr_checks_passed++;

            `uvm_info(
                "SCB",
                $sformatf(
                    "PASS instr[%0d] %s: teorico=0x%08h experimental=0x%08h",
                    item.item_index,
                    item.asm_text,
                    expected_observed,
                    item.observed_value
                ),
                UVM_MEDIUM
            )
        end
        else begin
            instr_checks_failed++;

            `uvm_error(
                "SCB",
                $sformatf(
                    "FAIL instr[%0d] %s: teorico=0x%08h experimental=0x%08h",
                    item.item_index,
                    item.asm_text,
                    expected_observed,
                    item.observed_value
                )
            )
        end
    endfunction

    function void compare_final_snapshot(darksocv_item item);
        for (int r = 0; r < 16; r++) begin
            checks_executed++;

            if (ref_regs[r] === item.final_regs[r]) begin
                checks_passed++;

                `uvm_info(
                    "SCB",
                    $sformatf(
                        "PASS x%0d: teorico=0x%08h experimental=0x%08h",
                        r,
                        ref_regs[r],
                        item.final_regs[r]
                    ),
                    UVM_MEDIUM
                )
            end
            else begin
                checks_failed++;

                `uvm_error(
                    "SCB",
                    $sformatf(
                        "FAIL x%0d: teorico=0x%08h experimental=0x%08h",
                        r,
                        ref_regs[r],
                        item.final_regs[r]
                    )
                )
            end
        end
    endfunction

    function void print_summary();
        `uvm_info(
            "SCB",
            $sformatf(
                "Resumen: instrucciones=%0d instr_checks=%0d instr_correctos=%0d instr_fallidos=%0d pc_checks=%0d pc_correctos=%0d pc_fallidos=%0d checks_finales=%0d finales_correctos=%0d finales_fallidos=%0d",
                instr_count,
                instr_checks_executed,
                instr_checks_passed,
                instr_checks_failed,
                pc_checks_executed,
                pc_checks_passed,
                pc_checks_failed,
                checks_executed,
                checks_passed,
                checks_failed
            ),
            UVM_MEDIUM
        )

        if ((instr_checks_executed == instr_count) &&
            (instr_checks_failed == 0) &&
            (pc_checks_executed == instr_count) &&
            (pc_checks_failed == 0) &&
            (checks_executed == 16) &&
            (checks_failed == 0)) begin
            `uvm_info("SCB", "Resultado final: PASS", UVM_MEDIUM)
        end
        else begin
            `uvm_error("SCB", "Resultado final: FAIL")
        end
    endfunction

endclass
