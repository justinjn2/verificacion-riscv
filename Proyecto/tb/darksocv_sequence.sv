class darksocv_sequence extends uvm_sequence #(darksocv_item);

    `uvm_object_utils(darksocv_sequence)

    int num_items = 2;
    int seq_mode = 0;

    localparam int MODE_MIXED  = 0;
    localparam int MODE_R      = 1;
    localparam int MODE_I      = 2;
    localparam int MODE_U      = 3;
    localparam int MODE_LOAD   = 4;
    localparam int MODE_STORE  = 5;
    localparam int MODE_BRANCH = 6;
    localparam int MODE_JUMP   = 7;

    function new(string name = "darksocv_sequence");
        super.new(name);
    endfunction

    task body();
        darksocv_item item;
        bit enable_directed_jalr;

        enable_directed_jalr = ((seq_mode == MODE_MIXED) ||
                                (seq_mode == MODE_JUMP)) &&
                               (num_items >= 7);

        for (int i = 0; i < num_items; i++) begin
            item = darksocv_item::type_id::create($sformatf("item_%0d", i));

            start_item(item);

            if (i == 0) begin
                if (!item.randomize() with {
                    instr_type == INSTR_I;
                    op == OP_ADDI;
                    rd inside {[1:15]};
                    rs1 == 0;
                    imm inside {[1:15]};
                }) begin
                    `uvm_fatal("SEQ", "No se pudo randomizar darksocv_item")
                end
            end
            else if (enable_directed_jalr && i == 1) begin
                // AUIPC x15 obtiene PC=4; JALR usara x15 para formar un destino conocido.
                if (!item.randomize() with {
                    instr_type == INSTR_U;
                    op == OP_AUIPC;
                    rd == 15;
                    imm == 0;
                }) begin
                    `uvm_fatal("SEQ", "No se pudo generar la preparacion dirigida de JALR")
                end
            end
            else if (enable_directed_jalr && (i inside {2, 3, 5})) begin
                // Dos NOPs evitan dependencia inmediata; el tercero debe ser omitido por JALR.
                if (!item.randomize() with {
                    instr_type == INSTR_I;
                    op == OP_ADDI;
                    rd == 0;
                    rs1 == 0;
                    imm == 0;
                }) begin
                    `uvm_fatal("SEQ", "No se pudo generar NOP dirigido para JALR")
                end
            end
            else if (enable_directed_jalr && i == 4) begin
                // En PC=16: (x15 + 20) & ~1 = 24. Se omite la palabra en PC=20.
                if (!item.randomize() with {
                    instr_type == INSTR_JUMP;
                    op == OP_JALR;
                    rd == 14;
                    rs1 == 15;
                    imm == 20;
                }) begin
                    `uvm_fatal("SEQ", "No se pudo generar la instruccion JALR dirigida")
                end
            end
            else begin
                case (seq_mode)
                    MODE_R: begin
                        if (!item.randomize() with { instr_type == INSTR_R; }) begin
                            `uvm_fatal("SEQ", "No se pudo randomizar instruccion R")
                        end
                    end

                    MODE_I: begin
                        if (!item.randomize() with { instr_type == INSTR_I; }) begin
                            `uvm_fatal("SEQ", "No se pudo randomizar instruccion I")
                        end
                    end

                    MODE_U: begin
                        if (!item.randomize() with { instr_type == INSTR_U; }) begin
                            `uvm_fatal("SEQ", "No se pudo randomizar instruccion U")
                        end
                    end

                    MODE_LOAD: begin
                        if (!item.randomize() with { instr_type == INSTR_LOAD; }) begin
                            `uvm_fatal("SEQ", "No se pudo randomizar instruccion LOAD")
                        end
                    end

                    MODE_STORE: begin
                        if (!item.randomize() with { instr_type == INSTR_STORE; }) begin
                            `uvm_fatal("SEQ", "No se pudo randomizar instruccion STORE")
                        end
                    end

                    MODE_BRANCH: begin
                        if (!item.randomize() with { instr_type == INSTR_BRANCH; }) begin
                            `uvm_fatal("SEQ", "No se pudo randomizar instruccion BRANCH")
                        end
                    end

                    MODE_JUMP: begin
                        if (!item.randomize() with {
                            instr_type == INSTR_JUMP;
                            op == OP_JAL;
                        }) begin
                            `uvm_fatal("SEQ", "No se pudo randomizar instruccion JUMP")
                        end
                    end

                    default: begin
                        // Los JALR adicionales requeririan preparar individualmente su destino.
                        if (!item.randomize() with { op != OP_JALR; }) begin
                            `uvm_fatal("SEQ", "No se pudo randomizar darksocv_item")
                        end
                    end
                endcase
            end

            item.item_index = i;
            item.is_last    = (i == num_items - 1);

            finish_item(item);

            `uvm_info(
                "SEQ",
                $sformatf("Instruccion randomizada %0d: %s", i, item.convert2string()),
                UVM_MEDIUM
            )
        end
    endtask

endclass
