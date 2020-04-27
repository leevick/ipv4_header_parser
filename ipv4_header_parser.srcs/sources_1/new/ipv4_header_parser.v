`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 宽带传输研究室
// Engineer: 李钊
// 
// Create Date: 04/25/2020 05:24:46 PM
// Design Name: IPv4包头解析模块 
// Module Name: ipv4_header_parser
// Project Name: 相控阵移动自组网系统
// Target Devices: N/A
// Tool Versions: 2019.1
// Description:
// This module extracts IPv4 source & destination address from a input AXIS
// input stream and outputs the payload in the form of AXI stream.
// 
// Dependencies: N/A
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module ipv4_header_parser(
    input axis_aclk,
    input axis_aresetn,

    input[63:0] s_tdata,
    input[7:0] s_tkeep,
    input s_tlast,
    input s_tvalid,
    output s_tready,

    output[63:0] m_tdata,
    output[7:0] m_tkeep,
    output m_tlast,
    output m_tvalid,
    input m_tready,

    output[7:0] proto,
    output[31:0] src,
    output[31:0] dst,
    output[15:0] src_port,
    output[15:0] dst_port,
    output completed

    );

    parameter IDLE = 0;
    parameter LOADING = 1;
    parameter PAUSE = 2;
    parameter TRANSFER = 3;

    (*KEEP = "TRUE"*)integer state = IDLE,state_prev = IDLE,state_next = IDLE;

    (*KEEP = "TRUE"*)reg[63:0] s_tdata_ibuf = 0;
    (*KEEP = "TRUE"*)reg[7:0] s_tkeep_ibuf = 0;

    (*KEEP = "TRUE"*)reg[7:0] proto_buf = 0;
    (*KEEP = "TRUE"*)reg[31:0] src_buf = 0;
    (*KEEP = "TRUE"*)reg[31:0] dst_buf = 0;
    (*KEEP = "TRUE"*)reg[15:0] src_port_buf = 0;
    (*KEEP = "TRUE"*)reg[15:0] dst_port_buf = 0;

    (*KEEP = "TRUE"*)reg proto_load = 0;
    (*KEEP = "TRUE"*)reg src_load = 0;
    (*KEEP = "TRUE"*)reg dst_load_0 = 0;
    (*KEEP = "TRUE"*)reg dst_load_1 = 0;
    (*KEEP = "TRUE"*)reg src_port_load = 0;
    (*KEEP = "TRUE"*)reg dst_port_load = 0;
    (*KEEP = "TRUE"*)reg completed_buf = 0;


    (*KEEP = "TRUE"*)reg[15:0] cnt = 0;
    (*KEEP = "TRUE"*)reg cnt_enb = 0;
    (*KEEP = "TRUE"*)reg cnt_clr = 0;


    assign proto = proto_buf;
    assign src = src_buf;
    assign dst = dst_buf;
    assign src_port = src_port_buf;
    assign dst_port = dst_port_buf;
    assign s_tready = 1;
    assign completed = completed_buf;


    always @(posedge axis_aclk) begin
        s_tdata_ibuf = s_tdata;
    end

    always @(posedge axis_aclk) begin
        if (axis_aresetn == 0 || cnt_clr ==1 ) begin
            cnt = 0;
        end else if (cnt_enb == 1) begin
            cnt = cnt + 1;
        end
    end

    always @(posedge axis_aclk) begin
        if (axis_aresetn == 0) begin
            state = IDLE;
        end else begin
            state = state_next;
        end
    end

    always @(posedge axis_aclk ) begin
        if (axis_aresetn == 0) begin
            proto_buf = 0;
            src_buf = 0;
            dst_buf = 0;
            src_port_buf = 0;
            dst_port_buf = 0;
        end else begin

            if (proto_load == 1) begin
                proto_buf[7:0] = s_tdata_ibuf[63:56];
            end

            if (src_load == 1) begin
                src_buf[31:0] = s_tdata_ibuf[47:16];
            end

            if (dst_load_0 == 1) begin
                dst_buf[15:0] = s_tdata_ibuf[63:48];
            end

            if (dst_load_1 == 1) begin
                dst_buf[31:16] = s_tdata_ibuf[15:0];
            end

            if (src_port_load == 1) begin
                src_port_buf[15:0] = s_tdata_ibuf[31:16];
            end

            if (dst_port_load == 1) begin
                dst_port_buf[15:0] = s_tdata_ibuf[47:32];
            end

        end
    end

    always @(state or s_tvalid or s_tlast or cnt) begin
        state_next = state;
        proto_load = 0;
        src_load = 0;
        dst_load_0 = 0;
        dst_load_1 = 0;
        src_port_load = 0;
        dst_port_load = 0;
        cnt_clr = 0;
        cnt_enb = 0;
        case(state)
            IDLE:
            begin
                if (s_tvalid == 1) begin
                    completed_buf = 0;
                    cnt_clr = 0;
                    cnt_enb = 1;
                    state_next = LOADING;
                    proto_load = 1;
                end
            end
            LOADING:
            begin
                cnt_enb = 1;
                if (s_tvalid == 1) begin
                    if (s_tlast == 1) begin
                        state_next = IDLE;
                    end else begin
                        case (cnt)
                            1:
                            begin
                                src_load = 1;
                                dst_load_0 = 1;   
                            end
                            2:
                            begin
                                dst_load_1 = 1;
                                src_port_load = 1;
                                dst_port_load = 1;
                            end
                            3:
                            begin
                                state_next = TRANSFER;
                                completed_buf = 1;
                            end
                        endcase
                    end
                end else begin
                    state_next = PAUSE;
                    state_prev = LOADING;
                end
            end
            TRANSFER:
            begin
                if (s_tvalid == 0) begin
                    state_next = PAUSE;
                    state_prev = TRANSFER;    
                end else begin
                    if (s_tlast == 1) begin
                        state_next = IDLE;
                        cnt_clr = 1;
                    end 
                end
            end
            PAUSE:
            begin
                if (s_tvalid == 1) begin
                   state_next = state_prev;
                end
            end
        endcase
    end

endmodule
