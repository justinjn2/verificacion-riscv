class darksocv_test extends uvm_test;

    `uvm_component_utils(darksocv_test)

    darksocv_env      env;
    darksocv_sequence seq;

    function new(string name = "darksocv_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        env = darksocv_env::type_id::create("env", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        string seq_mode_name;
        int plusarg_num_items;
        int configured_num_items;
        int configured_mode;

        super.run_phase(phase);

        `uvm_info("TEST", "Inicio de darksocv_test", UVM_MEDIUM)
        phase.raise_objection(this);

        seq = darksocv_sequence::type_id::create("seq");
        // Se escriben 401 palabras; el JALR dirigido omite una y quedan 400 ejecutadas.
        seq.num_items = 401;

        if ($value$plusargs("NUM_ITEMS=%0d", plusarg_num_items)) begin
            seq.num_items = plusarg_num_items;
        end

        if ($value$plusargs("SEQ_MODE=%s", seq_mode_name)) begin
            if (seq_mode_name == "R") begin
                seq.seq_mode = 1;
            end
            else if (seq_mode_name == "I") begin
                seq.seq_mode = 2;
            end
            else if (seq_mode_name == "U") begin
                seq.seq_mode = 3;
            end
            else if (seq_mode_name == "LOAD") begin
                seq.seq_mode = 4;
            end
            else if (seq_mode_name == "STORE") begin
                seq.seq_mode = 5;
            end
            else if (seq_mode_name == "BRANCH") begin
                seq.seq_mode = 6;
            end
            else if (seq_mode_name == "JUMP") begin
                seq.seq_mode = 7;
            end
            else begin
                seq.seq_mode = 0;
            end
        end

        configured_num_items = seq.num_items;
        configured_mode      = seq.seq_mode;

        `uvm_info(
            "TEST",
            $sformatf("Se generaran %0d instrucciones aleatorias con seq_mode=%0d", configured_num_items, configured_mode),
            UVM_MEDIUM
        )

        seq.start(env.agent.sequencer);

        repeat (6000) @(posedge env.agent.driver.vif.XCLK);

        `uvm_info("TEST", "Fin de darksocv_test", UVM_MEDIUM)
        phase.drop_objection(this);
    endtask

endclass
