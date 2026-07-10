typedef enum {
    INSTR_R,
    INSTR_I,
    INSTR_U,
    INSTR_LOAD,
    INSTR_STORE,
    INSTR_BRANCH,
    INSTR_JUMP
} instr_type_e;

typedef enum {
    OP_ADD, OP_SUB, OP_SLL, OP_SLT, OP_SLTU, OP_XOR, OP_SRL, OP_SRA, OP_OR, OP_AND,
    OP_ADDI, OP_SLTI, OP_SLTIU, OP_XORI, OP_ORI, OP_ANDI, OP_SLLI, OP_SRLI, OP_SRAI,
    OP_LUI, OP_AUIPC,
    OP_LW, OP_SW,
    OP_BEQ, OP_BNE, OP_BLT, OP_BGE, OP_BLTU, OP_BGEU,
    OP_JAL, OP_JALR
} alu_op_e;

class darksocv_item extends uvm_sequence_item;

    rand instr_type_e instr_type;
    rand alu_op_e     op;
    rand logic [3:0]  rd;
    rand logic [3:0]  rs1;
    rand logic [3:0]  rs2;
    rand logic [31:0] imm;

    logic [31:0] instr_word;
    logic [31:0] pc;
    logic [31:0] mem_addr;
    logic [31:0] store_value;
    logic [31:0] observed_mem_value;
    string       asm_text;
    logic [31:0] observed_value;
    logic [31:0] expected_value;
    int          item_index;
    bit          is_last;
    bit          has_final_snapshot;
    logic [31:0] final_regs [0:15];

    `uvm_object_utils_begin(darksocv_item)
        `uvm_field_enum(instr_type_e, instr_type, UVM_ALL_ON)
        `uvm_field_enum(alu_op_e, op, UVM_ALL_ON)
        `uvm_field_int(rd, UVM_ALL_ON)
        `uvm_field_int(rs1, UVM_ALL_ON)
        `uvm_field_int(rs2, UVM_ALL_ON)
        `uvm_field_int(imm, UVM_ALL_ON)
        `uvm_field_int(instr_word, UVM_ALL_ON)
        `uvm_field_int(pc, UVM_ALL_ON)
        `uvm_field_int(mem_addr, UVM_ALL_ON)
        `uvm_field_int(store_value, UVM_ALL_ON)
        `uvm_field_int(observed_mem_value, UVM_ALL_ON)
        `uvm_field_string(asm_text, UVM_ALL_ON)
        `uvm_field_int(observed_value, UVM_ALL_ON)
        `uvm_field_int(expected_value, UVM_ALL_ON)
        `uvm_field_int(item_index, UVM_ALL_ON)
        `uvm_field_int(is_last, UVM_ALL_ON)
        `uvm_field_int(has_final_snapshot, UVM_ALL_ON)
    `uvm_object_utils_end

    constraint c_instr_type_dist {
        instr_type dist {
            INSTR_R      := 35,
            INSTR_I      := 35,
            INSTR_U      := 10,
            INSTR_LOAD   := 6,
            INSTR_STORE  := 6,
            INSTR_BRANCH := 6,
            INSTR_JUMP   := 2
        };
    }

    constraint c_op_by_type {
        (instr_type == INSTR_R)      -> (op inside {OP_ADD, OP_SUB, OP_SLL, OP_SLT, OP_SLTU, OP_XOR, OP_SRL, OP_SRA, OP_OR, OP_AND});
        (instr_type == INSTR_I)      -> (op inside {OP_ADDI, OP_SLTI, OP_SLTIU, OP_XORI, OP_ORI, OP_ANDI, OP_SLLI, OP_SRLI, OP_SRAI});
        (instr_type == INSTR_U)      -> (op inside {OP_LUI, OP_AUIPC});
        (instr_type == INSTR_LOAD)   -> (op == OP_LW);
        (instr_type == INSTR_STORE)  -> (op == OP_SW);
        (instr_type == INSTR_BRANCH) -> (op inside {OP_BEQ, OP_BNE, OP_BLT, OP_BGE, OP_BLTU, OP_BGEU});
        (instr_type == INSTR_JUMP)   -> (op inside {OP_JAL, OP_JALR});
    }

    constraint c_reg_range {
        rd  inside {[0:15]};
        rs1 inside {[0:15]};
        rs2 inside {[0:15]};
        (op inside {OP_LW, OP_SW}) -> (rs1 == 0);
    }

    constraint c_imm_range {
        (op inside {OP_ADDI, OP_SLTI, OP_SLTIU, OP_XORI, OP_ORI, OP_ANDI}) -> (imm inside {[0:15]});
        (op inside {OP_SLLI, OP_SRLI, OP_SRAI}) -> (imm inside {[0:15]});
        (op inside {OP_LUI, OP_AUIPC}) -> (imm inside {[0:255]});
        (op == OP_LW) -> (imm inside {[32'd1792:32'd1900]} && imm[1:0] == 2'b00);
        (op == OP_SW) -> (imm inside {[32'd1792:32'd1900]} && imm[1:0] == 2'b00);
        (instr_type == INSTR_BRANCH) -> (imm == 32'd4);
        (op == OP_JAL) -> (imm == 32'd4);
        (op == OP_JALR) -> (imm inside {[0:2047]} && imm[0] == 1'b0);
        (instr_type == INSTR_R) -> (imm == 0);
    }

    function new(string name = "darksocv_item");
        super.new(name);
        instr_word           = 32'h00000013;
        pc                   = 32'h00000000;
        mem_addr             = 32'h00000000;
        store_value          = 32'h00000000;
        observed_mem_value   = 32'h00000000;
        observed_value       = 32'h00000000;
        expected_value       = 32'h00000000;
        item_index           = 0;
        is_last              = 1'b0;
        has_final_snapshot   = 1'b0;
    endfunction

    function void post_randomize();
        encode();
        update_asm();
    endfunction

    function logic [31:0] sext12(input logic [11:0] value);
        return {{20{value[11]}}, value};
    endfunction

    function void encode();
        logic [4:0] rd5;
        logic [4:0] rs1_5;
        logic [4:0] rs2_5;
        logic [11:0] imm12;
        logic [12:0] bimm;
        logic [20:0] jimm;

        rd5   = {1'b0, rd};
        rs1_5 = {1'b0, rs1};
        rs2_5 = {1'b0, rs2};
        imm12 = imm[11:0];
        bimm  = imm[12:0];
        jimm  = imm[20:0];

        instr_word = 32'h00000013;

        case (op)
            OP_ADD:  instr_word = {7'b0000000, rs2_5, rs1_5, 3'b000, rd5, 7'b0110011};
            OP_SUB:  instr_word = {7'b0100000, rs2_5, rs1_5, 3'b000, rd5, 7'b0110011};
            OP_SLL:  instr_word = {7'b0000000, rs2_5, rs1_5, 3'b001, rd5, 7'b0110011};
            OP_SLT:  instr_word = {7'b0000000, rs2_5, rs1_5, 3'b010, rd5, 7'b0110011};
            OP_SLTU: instr_word = {7'b0000000, rs2_5, rs1_5, 3'b011, rd5, 7'b0110011};
            OP_XOR:  instr_word = {7'b0000000, rs2_5, rs1_5, 3'b100, rd5, 7'b0110011};
            OP_SRL:  instr_word = {7'b0000000, rs2_5, rs1_5, 3'b101, rd5, 7'b0110011};
            OP_SRA:  instr_word = {7'b0100000, rs2_5, rs1_5, 3'b101, rd5, 7'b0110011};
            OP_OR:   instr_word = {7'b0000000, rs2_5, rs1_5, 3'b110, rd5, 7'b0110011};
            OP_AND:  instr_word = {7'b0000000, rs2_5, rs1_5, 3'b111, rd5, 7'b0110011};

            OP_ADDI:  instr_word = {imm12, rs1_5, 3'b000, rd5, 7'b0010011};
            OP_SLTI:  instr_word = {imm12, rs1_5, 3'b010, rd5, 7'b0010011};
            OP_SLTIU: instr_word = {imm12, rs1_5, 3'b011, rd5, 7'b0010011};
            OP_XORI:  instr_word = {imm12, rs1_5, 3'b100, rd5, 7'b0010011};
            OP_ORI:   instr_word = {imm12, rs1_5, 3'b110, rd5, 7'b0010011};
            OP_ANDI:  instr_word = {imm12, rs1_5, 3'b111, rd5, 7'b0010011};
            OP_SLLI:  instr_word = {7'b0000000, imm[4:0], rs1_5, 3'b001, rd5, 7'b0010011};
            OP_SRLI:  instr_word = {7'b0000000, imm[4:0], rs1_5, 3'b101, rd5, 7'b0010011};
            OP_SRAI:  instr_word = {7'b0100000, imm[4:0], rs1_5, 3'b101, rd5, 7'b0010011};

            OP_LUI:   instr_word = {imm[19:0], rd5, 7'b0110111};
            OP_AUIPC: instr_word = {imm[19:0], rd5, 7'b0010111};

            OP_LW: instr_word = {imm12, rs1_5, 3'b010, rd5, 7'b0000011};
            OP_SW: instr_word = {imm12[11:5], rs2_5, rs1_5, 3'b010, imm12[4:0], 7'b0100011};

            OP_BEQ:  instr_word = {bimm[12], bimm[10:5], rs2_5, rs1_5, 3'b000, bimm[4:1], bimm[11], 7'b1100011};
            OP_BNE:  instr_word = {bimm[12], bimm[10:5], rs2_5, rs1_5, 3'b001, bimm[4:1], bimm[11], 7'b1100011};
            OP_BLT:  instr_word = {bimm[12], bimm[10:5], rs2_5, rs1_5, 3'b100, bimm[4:1], bimm[11], 7'b1100011};
            OP_BGE:  instr_word = {bimm[12], bimm[10:5], rs2_5, rs1_5, 3'b101, bimm[4:1], bimm[11], 7'b1100011};
            OP_BLTU: instr_word = {bimm[12], bimm[10:5], rs2_5, rs1_5, 3'b110, bimm[4:1], bimm[11], 7'b1100011};
            OP_BGEU: instr_word = {bimm[12], bimm[10:5], rs2_5, rs1_5, 3'b111, bimm[4:1], bimm[11], 7'b1100011};

            OP_JAL:  instr_word = {jimm[20], jimm[10:1], jimm[11], jimm[19:12], rd5, 7'b1101111};
            OP_JALR: instr_word = {imm12, rs1_5, 3'b000, rd5, 7'b1100111};

            default: instr_word = 32'h00000013;
        endcase
    endfunction

    function void update_asm();
        case (op)
            OP_ADD:   asm_text = $sformatf("add x%0d, x%0d, x%0d", rd, rs1, rs2);
            OP_SUB:   asm_text = $sformatf("sub x%0d, x%0d, x%0d", rd, rs1, rs2);
            OP_SLL:   asm_text = $sformatf("sll x%0d, x%0d, x%0d", rd, rs1, rs2);
            OP_SLT:   asm_text = $sformatf("slt x%0d, x%0d, x%0d", rd, rs1, rs2);
            OP_SLTU:  asm_text = $sformatf("sltu x%0d, x%0d, x%0d", rd, rs1, rs2);
            OP_XOR:   asm_text = $sformatf("xor x%0d, x%0d, x%0d", rd, rs1, rs2);
            OP_SRL:   asm_text = $sformatf("srl x%0d, x%0d, x%0d", rd, rs1, rs2);
            OP_SRA:   asm_text = $sformatf("sra x%0d, x%0d, x%0d", rd, rs1, rs2);
            OP_OR:    asm_text = $sformatf("or x%0d, x%0d, x%0d", rd, rs1, rs2);
            OP_AND:   asm_text = $sformatf("and x%0d, x%0d, x%0d", rd, rs1, rs2);
            OP_ADDI:  asm_text = $sformatf("addi x%0d, x%0d, %0d", rd, rs1, $signed(sext12(imm[11:0])));
            OP_SLTI:  asm_text = $sformatf("slti x%0d, x%0d, %0d", rd, rs1, $signed(sext12(imm[11:0])));
            OP_SLTIU: asm_text = $sformatf("sltiu x%0d, x%0d, %0d", rd, rs1, imm[11:0]);
            OP_XORI:  asm_text = $sformatf("xori x%0d, x%0d, %0d", rd, rs1, $signed(sext12(imm[11:0])));
            OP_ORI:   asm_text = $sformatf("ori x%0d, x%0d, %0d", rd, rs1, $signed(sext12(imm[11:0])));
            OP_ANDI:  asm_text = $sformatf("andi x%0d, x%0d, %0d", rd, rs1, $signed(sext12(imm[11:0])));
            OP_SLLI:  asm_text = $sformatf("slli x%0d, x%0d, %0d", rd, rs1, imm[4:0]);
            OP_SRLI:  asm_text = $sformatf("srli x%0d, x%0d, %0d", rd, rs1, imm[4:0]);
            OP_SRAI:  asm_text = $sformatf("srai x%0d, x%0d, %0d", rd, rs1, imm[4:0]);
            OP_LUI:   asm_text = $sformatf("lui x%0d, 0x%0h", rd, imm[19:0]);
            OP_AUIPC: asm_text = $sformatf("auipc x%0d, 0x%0h", rd, imm[19:0]);
            OP_LW:    asm_text = $sformatf("lw x%0d, %0d(x%0d)", rd, $signed(sext12(imm[11:0])), rs1);
            OP_SW:    asm_text = $sformatf("sw x%0d, %0d(x%0d)", rs2, $signed(sext12(imm[11:0])), rs1);
            OP_BEQ:   asm_text = $sformatf("beq x%0d, x%0d, %0d", rs1, rs2, $signed(imm));
            OP_BNE:   asm_text = $sformatf("bne x%0d, x%0d, %0d", rs1, rs2, $signed(imm));
            OP_BLT:   asm_text = $sformatf("blt x%0d, x%0d, %0d", rs1, rs2, $signed(imm));
            OP_BGE:   asm_text = $sformatf("bge x%0d, x%0d, %0d", rs1, rs2, $signed(imm));
            OP_BLTU:  asm_text = $sformatf("bltu x%0d, x%0d, %0d", rs1, rs2, $signed(imm));
            OP_BGEU:  asm_text = $sformatf("bgeu x%0d, x%0d, %0d", rs1, rs2, $signed(imm));
            OP_JAL:   asm_text = $sformatf("jal x%0d, %0d", rd, $signed(imm));
            OP_JALR:  asm_text = $sformatf("jalr x%0d, %0d(x%0d)", rd, $signed(sext12(imm[11:0])), rs1);
            default:  asm_text = "unknown";
        endcase
    endfunction

    function string instr_type_to_string();
        case (instr_type)
            INSTR_R:      return "INSTR_R";
            INSTR_I:      return "INSTR_I";
            INSTR_U:      return "INSTR_U";
            INSTR_LOAD:   return "INSTR_LOAD";
            INSTR_STORE:  return "INSTR_STORE";
            INSTR_BRANCH: return "INSTR_BRANCH";
            INSTR_JUMP:   return "INSTR_JUMP";
            default:      return "INSTR_UNKNOWN";
        endcase
    endfunction

    function string op_to_string();
        case (op)
            OP_ADD: return "OP_ADD"; OP_SUB: return "OP_SUB"; OP_SLL: return "OP_SLL";
            OP_SLT: return "OP_SLT"; OP_SLTU: return "OP_SLTU"; OP_XOR: return "OP_XOR";
            OP_SRL: return "OP_SRL"; OP_SRA: return "OP_SRA"; OP_OR: return "OP_OR"; OP_AND: return "OP_AND";
            OP_ADDI: return "OP_ADDI"; OP_SLTI: return "OP_SLTI"; OP_SLTIU: return "OP_SLTIU";
            OP_XORI: return "OP_XORI"; OP_ORI: return "OP_ORI"; OP_ANDI: return "OP_ANDI";
            OP_SLLI: return "OP_SLLI"; OP_SRLI: return "OP_SRLI"; OP_SRAI: return "OP_SRAI";
            OP_LUI: return "OP_LUI"; OP_AUIPC: return "OP_AUIPC";
            OP_LW: return "OP_LW"; OP_SW: return "OP_SW";
            OP_BEQ: return "OP_BEQ"; OP_BNE: return "OP_BNE"; OP_BLT: return "OP_BLT";
            OP_BGE: return "OP_BGE"; OP_BLTU: return "OP_BLTU"; OP_BGEU: return "OP_BGEU";
            OP_JAL: return "OP_JAL"; OP_JALR: return "OP_JALR";
            default: return "OP_UNKNOWN";
        endcase
    endfunction

    function bit writes_rd();
        return !(instr_type inside {INSTR_STORE, INSTR_BRANCH});
    endfunction

    function string convert2string();
        return $sformatf(
            "tipo=%s operacion=%s rd=x%0d rs1=x%0d rs2=x%0d imm=0x%0h pc=0x%08h item_index=%0d is_last=%0d has_final_snapshot=%0d instr_word=0x%08h asm_text=\"%s\"",
            instr_type_to_string(), op_to_string(), rd, rs1, rs2, imm, pc,
            item_index, is_last, has_final_snapshot, instr_word, asm_text
        );
    endfunction

endclass
