/*** 
 * @Author: Liuyuezhong 15179445336@163.com
 * @Date: 2022-08-04 15:06:41
 * @LastEditTime: 2022-08-04 17:10:53
 * @LastEditors: Liuyuezhong 15179445336@163.com
 * @Description: APB3协议的APB Bridge
 * @FilePath: \src\apb3_master.v
 */
module apb3_master
#(
    parameter RD_FLAG = 8'd0,   //读标志
    parameter WR_FLAG = 8'd1,   //写标志
    parameter CMD_RW_FLAG_WIDTH = 8,    //上游命令中表示读写标志信号的位宽
    parameter CMD_ADDR_WIDTH = 16,      //上游命令中的地址位宽
    parameter CMD_DATA_WIDTH = 32,      //上游命令中的数据位宽
    parameter CMD_WIDTH = CMD_RW_FLAG_WIDTH + CMD_ADDR_WIDTH
    + CMD_DATA_WIDTH    //上游命令总位宽
)
(
    input wire pclk,    //系统时钟
    input wire prst_n,  //系统复位信号，异步低电平有效
    input wire [CMD_WIDTH-1:0] cmd, //上游命令信号
    input wire cmd_valid,   //上游命令有效标志
    input wire prdata,  //外围设备中读出的数据
    input wire pready,  //外围设备发出的ready信号
    input wire pslverr, //外围设备发出的错误标志信号
    output reg [CMD_DATA_WIDTH-1:0] cmd_rdata,  //APB总线发送给上游的读数据
    output reg pwrite,  //APB总线发送给外围设备的读写标志信号
    output reg psel,    //APB总线发送给外围设备的选中信号
    output reg penable, //APB总线发送给外围设备的使能信号
    output reg [CMD_ADDR_WIDTH-1:0] paddr,  //APB总线发送给外围设备的地址
    output reg [CMD_DATA_WIDTH-1:0] pwdata //APB总线发送给外围设备的写入数据
);
//////////////////////////////////////////////////////////////////////////////////
////参数定义
//////////////////////////////////////////////////////////////////////////////////
localparam IDLE = 2'd0;
localparam SETUP = 2'd1;
localparam ACCESS = 2'd3;

//////////////////////////////////////////////////////////////////////////////////
////中间变量定义
//////////////////////////////////////////////////////////////////////////////////
reg [1:0] state, next_state;
reg start_flag; //传输开始的标志
reg [CMD_WIDTH-1:0] cmd_reg;    //输入命令的寄存
reg [CMD_DATA_WIDTH-1:0] prdata_reg;    //外围设备读出数据的寄存

//////////////////////////////////////////////////////////////////////////////////
////Main Code
//////////////////////////////////////////////////////////////////////////////////

//传输开始标志
always @(posedge pclk or negedge prst_n) begin
    if(!prst_n)
        start_flag <= 1'b0;
    else if(cmd_valid && pready)    
        start_flag <= 1'b1;
    else
        start_flag <= 1'b0;
end

//对上游输入命令的寄存
//这是由于start_flag标志带来的一个周期延迟导致需要数据寄存
always @(posedge pclk or negedge prst_n) begin
    if(!prst_n)
        cmd_reg <= {CMD_WIDTH{1'b0}};
    else if(cmd_valid && pready)
        cmd_reg <= cmd;
    else
        cmd_reg <= cmd_reg;
end

//对外围读出数据的寄存
always @(posedge pclk or negedge prst_n) begin
    if(!prst_n)
        prdata_reg <= {CMD_DATA_WIDTH{1'b0}};
    else if(psel && penable && pready)
        prdata_reg <= prdata;
    else
        prdata_reg <= prdata_reg;
end

//状态转换
always @(posedge pclk or negedge prst_n) begin
    if(prst_n == 1'b0)
        state <= IDLE;
    else
        state <= next_state; 
end

//下一状态定义
always @(*) begin
    case (state)
        IDLE: if(start_flag) next_state = SETUP;
        else next_state = IDLE;
        SETUP: next_state = ACCESS;
        ACCESS: if(!pready) next_state = ACCESS;
        else if(start_flag) next_state = SETUP;
        else next_state = IDLE;
        default: next_state = IDLE;
    endcase
end

//给外围设备的输出
always @(posedge pclk or negedge prst_n) begin
    if(!prst_n) begin
      psel <= 1'b0;
      pwrite <= 1'b0;
      penable <= 1'b0;
      paddr <= {CMD_ADDR_WIDTH{1'b0}};
      pwdata <= {CMD_DATA_WIDTH{1'b0}};
    end 
    else if(next_state == IDLE) begin
        pwrite <= 1'b0;
        penable <= 1'b0;
    end
    else if(next_state == SETUP) begin
        psel <= 1'b1;
        paddr <= cmd_reg[CMD_WIDTH-CMD_RW_FLAG_WIDTH-1 -:CMD_ADDR_WIDTH];
        //读
        if(cmd_reg[CMD_WIDTH-1 -:CMD_RW_FLAG_WIDTH] == RD_FLAG)
            pwrite <= 1'b0;
        else begin
            pwrite <= 1'b1;
            pwdata <= cmd_reg[CMD_WIDTH-CMD_RW_FLAG_WIDTH-CMD_ADDR_WIDTH-1 -:CMD_DATA_WIDTH];
        end
    end
    else if(next_state == ACCESS) begin
      penable <= 1'b1;
    end
end

//对上游的输出
always @(posedge pclk or negedge prst_n) begin
    if(!prst_n)
        cmd_rdata <= {CMD_DATA_WIDTH{1'b0}};
    else
        cmd_rdata <= prdata_reg;
end
endmodule