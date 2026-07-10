interface ifc_darksocv(input logic XCLK);

    // La interfaz agrupa senales externas e internas observadas del DUT.
    // El driver controla senales externas como XRES y UART_RXD.
    logic XRES;
    logic UART_RXD;
    logic UART_TXD;
    logic [3:0] LED;
    logic [3:0] DEBUG;

    // El monitor observa bus de fetch, etapa de ejecucion, registros y memoria.
    logic CLK;
    logic RES;
    logic HLT;
    logic [31:0] IADDR;
    logic [31:0] DADDR;
    logic [31:0] IDATA;
    logic [31:0] EXEC_PC;
    logic [31:0] EXEC_INSTR;
    logic EXEC_VALID;
    logic [31:0] DATAO;
    logic [31:0] DATAI;
    logic WR;
    logic RD;
    logic [3:0] BE;

    logic [31:0] REGS [0:15];

    // Programas aleatorios de hasta 512 instrucciones/palabras.
    logic [31:0] MEM_WORD [0:511];

    // Las aserciones revisan propiedades basicas del core durante la simulacion.
    property p_x0_constante;
        @(posedge XCLK) disable iff (XRES || RES || $isunknown(REGS[0]))
            REGS[0] == 32'h00000000;
    endproperty

    property p_iaddr_alineado;
        @(posedge XCLK) disable iff (XRES || RES || $isunknown(IADDR))
            IADDR[1:0] == 2'b00;
    endproperty

    property p_no_rd_wr_simultaneo;
        @(posedge XCLK) disable iff (XRES || RES || $isunknown(RD) || $isunknown(WR))
            !(RD && WR);
    endproperty

    property p_xres_conocido;
        @(posedge XCLK) !$isunknown(XRES);
    endproperty

    property p_uart_rxd_conocido;
        @(posedge XCLK) !$isunknown(UART_RXD);
    endproperty

    property p_clk_interno_conocido;
        @(posedge XCLK) disable iff (XRES)
            !$isunknown(CLK);
    endproperty

    property p_res_interno_conocido;
        @(posedge XCLK) disable iff (XRES)
            !$isunknown(RES);
    endproperty

    property p_iaddr_conocido;
        @(posedge XCLK) disable iff (XRES || RES)
            !$isunknown(IADDR);
    endproperty

    property p_idata_conocido;
        @(posedge XCLK) disable iff (XRES || RES)
            !$isunknown(IDATA);
    endproperty

    property p_daddr_conocido_en_mem;
        @(posedge XCLK) disable iff (XRES || RES || $isunknown(RD) || $isunknown(WR))
            (RD || WR) |-> !$isunknown(DADDR);
    endproperty

    property p_be_conocido_en_write;
        @(posedge XCLK) disable iff (XRES || RES || $isunknown(WR))
            WR |-> !$isunknown(BE);
    endproperty

    property p_be_no_cero_en_write;
        @(posedge XCLK) disable iff (XRES || RES || $isunknown(WR) || $isunknown(BE))
            WR |-> (BE != 4'b0000);
    endproperty

    a_x0_constante: assert property (p_x0_constante)
        else $error("ASSERTION FAILED: x0 cambio de cero fuera de reset");

    a_iaddr_alineado: assert property (p_iaddr_alineado)
        else $error("ASSERTION FAILED: IADDR no esta alineado a 4 bytes fuera de reset");

    a_no_rd_wr_simultaneo: assert property (p_no_rd_wr_simultaneo)
        else $error("ASSERTION FAILED: RD y WR activos simultaneamente fuera de reset");

    a_xres_conocido: assert property (p_xres_conocido)
        else $error("ASSERTION FAILED: XRES desconocido");

    a_uart_rxd_conocido: assert property (p_uart_rxd_conocido)
        else $error("ASSERTION FAILED: UART_RXD desconocido");

    a_clk_interno_conocido: assert property (p_clk_interno_conocido)
        else $error("ASSERTION FAILED: CLK interno desconocido fuera de reset externo");

    a_res_interno_conocido: assert property (p_res_interno_conocido)
        else $error("ASSERTION FAILED: RES interno desconocido fuera de reset externo");

    a_iaddr_conocido: assert property (p_iaddr_conocido)
        else $error("ASSERTION FAILED: IADDR desconocido fuera de reset");

    a_idata_conocido: assert property (p_idata_conocido)
        else $error("ASSERTION FAILED: IDATA desconocido fuera de reset");

    a_daddr_conocido_en_mem: assert property (p_daddr_conocido_en_mem)
        else $error("ASSERTION FAILED: DADDR desconocido durante acceso de datos");

    a_be_conocido_en_write: assert property (p_be_conocido_en_write)
        else $error("ASSERTION FAILED: BE desconocido durante escritura");

    a_be_no_cero_en_write: assert property (p_be_no_cero_en_write)
        else $error("ASSERTION FAILED: BE cero durante escritura");

endinterface
