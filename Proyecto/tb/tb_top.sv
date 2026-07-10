import uvm_pkg::*;
`include "uvm_macros.svh"
import darksocv_pkg::*;

module tb_top;
  
    logic [31:0] reg_x0;
    logic [31:0] reg_x1;
    logic [31:0] reg_x2;
    logic [31:0] reg_x3;
    logic [31:0] reg_x4;
    logic [31:0] reg_x5;
    logic [31:0] reg_x6;
    logic [31:0] reg_x7;
    logic [31:0] reg_x8;
    logic [31:0] reg_x9;
    logic [31:0] reg_x10;
    logic [31:0] reg_x11;
    logic [31:0] reg_x12;
    logic [31:0] reg_x13;
    logic [31:0] reg_x14;
    logic [31:0] reg_x15;

    always_comb begin
        reg_x0  = dut.core0.REGS[0];
        reg_x1  = dut.core0.REGS[1];
        reg_x2  = dut.core0.REGS[2];
        reg_x3  = dut.core0.REGS[3];
        reg_x4  = dut.core0.REGS[4];
        reg_x5  = dut.core0.REGS[5];
        reg_x6  = dut.core0.REGS[6];
        reg_x7  = dut.core0.REGS[7];
        reg_x8  = dut.core0.REGS[8];
        reg_x9  = dut.core0.REGS[9];
        reg_x10 = dut.core0.REGS[10];
        reg_x11 = dut.core0.REGS[11];
        reg_x12 = dut.core0.REGS[12];
        reg_x13 = dut.core0.REGS[13];
        reg_x14 = dut.core0.REGS[14];
        reg_x15 = dut.core0.REGS[15];
    end

    // tb_top.sv es el puente entre el DUT y el ambiente UVM.
    // La verificacion sigue enfocada en darkriscv, aunque se instancia darksocv.
    logic XCLK;

    initial begin
        XCLK = 1'b0;
        forever #5 XCLK = ~XCLK;
    end

    ifc_darksocv ifc_darksocv_obj(XCLK);

    darksocv dut (
        .XCLK     (XCLK),
        .XRES     (ifc_darksocv_obj.XRES),
        .UART_RXD (ifc_darksocv_obj.UART_RXD),
        .UART_TXD (ifc_darksocv_obj.UART_TXD),
        .LED      (ifc_darksocv_obj.LED),
        .DEBUG    (ifc_darksocv_obj.DEBUG)
    );

    // Las senales internas se copian para mejorar observabilidad del core.
    always_comb begin
        ifc_darksocv_obj.CLK   = dut.CLK;
        ifc_darksocv_obj.RES   = dut.RES;
        ifc_darksocv_obj.HLT   = dut.HLT;
        ifc_darksocv_obj.IADDR = dut.IADDR;
        ifc_darksocv_obj.DADDR = dut.DADDR;
        ifc_darksocv_obj.IDATA = dut.IDATA;
        ifc_darksocv_obj.EXEC_PC    = dut.core0.PC;
        ifc_darksocv_obj.EXEC_INSTR = dut.core0.XIDATA;
        ifc_darksocv_obj.EXEC_VALID = (dut.core0.FLUSH == 0);
        ifc_darksocv_obj.DATAO = dut.DATAO;
        ifc_darksocv_obj.DATAI = dut.DATAI;
        ifc_darksocv_obj.WR    = dut.WR;
        ifc_darksocv_obj.RD    = dut.RD;
        ifc_darksocv_obj.BE    = dut.BE;

        for (int i = 0; i < 16; i++) begin
            ifc_darksocv_obj.REGS[i] = dut.core0.REGS[i];
        end

        for (int i = 0; i < 512; i++) begin
            ifc_darksocv_obj.MEM_WORD[i] = dut.MEM[i];
        end
    end

    initial begin
        ifc_darksocv_obj.XRES     = 1'b1;
        ifc_darksocv_obj.UART_RXD = 1'b1;

        $dumpfile("dump.vcd");
        $dumpvars(0, tb_top);

        // La interfaz se publica mediante uvm_config_db para driver y monitor.
        uvm_config_db #(virtual ifc_darksocv)::set(
            null,
            "*",
            "vif",
            ifc_darksocv_obj
        );

        run_test("darksocv_test");
    end

endmodule
