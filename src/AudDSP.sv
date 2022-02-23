
module AudDSP(
    input           i_rst_n,
    input           i_clk,
    input           i_start,		 
    input           i_pause,		
    input           i_stop,			
    input [2:0]     i_speed,		
    input           i_fast,			
    input           i_slow_0,
    input           i_slow_1,
    input           i_daclrck,		
    input signed [15:0] i_sram_data,
	output [15:0]	o_dac_data,		
	output [19:0]	o_sram_addr,
    input  [19:0]   i_sram_stop,//
    input           i_reverse,//	
    output          o_finish,//
    output          o_player_en		
);

localparam IDLE    = 0;
localparam CALC    = 1;// lrc = 1
localparam OUTPUT  = 2;// lrc = 1
localparam WAIT    = 3;// lrc = 1
localparam WAIT2   = 4;



logic [2:0] state,next_state;
logic linear,fast;
logic [2:0]speed;
logic [19:0] sram_addr,next_sram_addr;
logic signed [15:0] pre_data,next_pre_data;
logic signed[15:0] output_data,next_output_data;
logic player_en;
logic [2:0] counter,next_counter;
logic buff,next_buff;

assign o_player_en=player_en;
assign o_sram_addr=sram_addr;
assign o_dac_data=output_data;
assign o_finish=(i_reverse)?((o_sram_addr<=20'd10)&&(o_sram_addr!=0)):(o_sram_addr==i_sram_stop);/////////////////////////////////////////////////


//player_en
always_comb begin
    player_en=(state==OUTPUT)?1:0;
end
//next_state
always_comb begin
    if ( i_pause || i_stop ) next_state = IDLE;
    else begin
        case(state)
        IDLE:begin
            if(i_start)begin
                next_state=(i_daclrck)?CALC:WAIT;
            end
            else next_state=IDLE;
        end
        CALC:begin
            next_state=OUTPUT;
        end
        OUTPUT:begin
            next_state=(o_finish)?IDLE:WAIT2;
        end
        WAIT:begin
            if(i_daclrck)begin
                next_state=CALC;
            end
            else next_state=WAIT;
        end
        WAIT2:begin
            next_state=(!i_daclrck)?WAIT:WAIT2;
        end
        default: begin
            next_state = state;
        end
        endcase
    end
end 
always_comb begin
    if ( i_stop ) next_sram_addr = 0;
    else if(i_pause)begin
        next_sram_addr=sram_addr;
    end
    else begin
        if(state==CALC)begin
            if(fast)begin
                next_sram_addr=(i_reverse)?sram_addr-speed-1:sram_addr+speed+1;
            end
            else begin
                if(counter<speed)begin
                    next_sram_addr=sram_addr;
                end
                else begin
                    next_sram_addr=(i_reverse)?sram_addr-1:sram_addr+1;
                end
            end
        end
        else if(state==IDLE)begin
            if(i_start)begin
                next_sram_addr=(i_reverse)?i_sram_stop:0;
            end
            else next_sram_addr=sram_addr;
        end
        else begin
            next_sram_addr=sram_addr;
        end  
    end
end
always_comb begin
    next_pre_data=pre_data;
    next_counter=counter;
    if ( i_stop ) begin
        
    end
    else begin
        if(state==CALC)begin
            if(fast)begin

            end
            else begin
                if(counter<speed)begin
                    next_counter=counter+1;
                end
                else begin
                    next_counter=0;
                    next_pre_data=i_sram_data;
                end
            end
        end
        else begin

        end  
    end
end
//next_pre_data
// always_comb begin
//     if((state==CALC)&&(fast==1)) next_pre_data=i_sram_data;
//     else begin
//         next_pre_data=(counter<speed)?pre_data:i_sram_data;
//     end
// end
//next_output_data
always_comb begin
    if(state==CALC)begin
        if(fast) begin
            next_output_data=i_sram_data;
        end
        else begin
            next_output_data=(linear)?pre_data + $signed(i_sram_data - pre_data) * (counter+1) / (speed+1):pre_data;
        end
    end
    
    else begin
       next_output_data=output_data;        
    end
end

always_ff @(posedge i_clk or negedge i_rst_n ) begin
    if(!i_rst_n) begin
      state<=0;
      linear<=0;
      speed<=0;
      fast<=0;
      sram_addr<=0;
      pre_data<=0;
      output_data<=0;
      counter<=0;
      buff<=0;
    end 
    else begin
      state<=next_state;
      linear<=(i_start)?i_slow_1:linear;
      speed<=(i_start)?i_speed:speed;
      fast<=(i_start)?i_fast:fast;
      sram_addr<=next_sram_addr;
      pre_data<=next_pre_data;
      output_data<=next_output_data;
      counter<=next_counter;
      buff<=next_buff;
    end
end

endmodule
