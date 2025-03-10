\m4_TLV_version 1d: tl-x.org
\SV
   // This code can be found in: https://github.com/stevehoover/RISC-V_MYTH_Workshop
   
   m4_include_lib(['https://raw.githubusercontent.com/BalaDhinesh/RISC-V_MYTH_Workshop/master/tlv_lib/risc-v_shell_lib.tlv'])

\SV
   m4_makerchip_module   // (Expanded in Nav-TLV pane.)
\TLV

   // /====================\
   // | Sum 1 to 9 Program |
   // \====================/
   //
   // Program for MYTH Workshop to test RV32I
   // Add 1,2,3,...,9 (in that order).
   //
   // Regs:
   //  r10 (a0): In: 0, Out: final sum
   //  r12 (a2): 10
   //  r13 (a3): 1..10
   //  r14 (a4): Sum
   // 
   // External to function:
   m4_asm(ADD, r10, r0, r0)   //0          // Initialize r10 (a0) to 0.
   // Function:
   m4_asm(ADD, r14, r10, r0)     //1       // Initialize sum register a4 with 0x0
   m4_asm(ADDI, r12, r10, 1010)    //2     // Store count of 10 in register a2.
   m4_asm(ADD, r13, r10, r0)    //3        // Initialize intermediate sum register a3 with 0
   // Loop:
   m4_asm(ADD, r14, r13, r14)      //4     // Incremental addition
   m4_asm(ADDI, r13, r13, 1)        //5    // Increment intermediate register by 1
   m4_asm(BLT, r13, r12, 1111111111000) //6 // If a3 is less than a2, branch to label named <loop>
   m4_asm(ADD, r10, r14, r0)   //7         // Store final result to register a0 so that it can be read by main program
   m4_asm(SW, r0, r10, 100) //8
   m4_asm(LW, r15, r0, 100) // 9
   
   //
   
   // Optional:
   m4_asm(JAL, r7, 00000000000000000000) // Done. Jump to itself (infinite loop). (Up to 20-bit signed immediate plus implicit 0 bit (unlike JALR) provides byte address; last immediate bit should also be 0)
   m4_define_hier(['M4_IMEM'], M4_NUM_INSTRS)
   //m4_define_hier(['M4_IMEM'], 16)

   |cpu
      @0
         $reset = *reset;

      // YOUR CODE HERE
      // ...
      // ++++++++++++++++++++++++++++++++++++++++++++++++++++++
      // FETCH
      //+++++++++++++++++++++++++++++++++++++++++++++++++++++++
      @0
         // PC MUX
         $pc[31:0] = (>>1$reset || $reset) ? 0              :
                     >>3$taken_br          ? >>3$br_tgt_pc  :
                     >>3$is_jal            ? >>3$br_tgt_pc  :
                     >>3$is_jalr           ? >>3$jalr_tgt_pc:
                     >>3$valid_load        ? >>3$inc_pc     :
                                             >>1$inc_pc     ;
         // IMEM READ                 
         $imem_rd_en = !$reset;
         $imem_rd_addr[M4_IMEM_INDEX_CNT-1:0] = $pc[M4_IMEM_INDEX_CNT+2-1:2];
         
         // VALID LOGIC
         //$start = (>>1$reset && !$reset);
         //$valid = !$reset && ($start || >>3$valid);
      
      @1
         $inc_pc[31:0] = $pc + 4;
         
         // DECODE
         $instr[31:0] = $imem_rd_data;
         $is_i_instr = $instr[6:2] ==? 5'b0000x ||
                       $instr[6:2] ==? 5'b001x0 ||
                       $instr[6:2] ==? 5'b11001   ;
         $is_u_instr = $instr[6:2] ==? 5'b0x101   ;
         $is_s_instr = $instr[6:2] ==? 5'b0100x   ;
         $is_r_instr = $instr[6:2] ==? 5'b01011 ||
                       $instr[6:2] ==? 5'b01100 ||
                       $instr[6:2] ==? 5'b01110 ||
                       $instr[6:2] ==? 5'b10100   ;
         $is_b_instr = $instr[6:2] ==? 5'b11000   ;
         $is_j_instr = $instr[6:2] ==? 5'b11011   ;
         
         $imm[31:0] = $is_i_instr ? { {21{$instr[31]}} , $instr[30:20]                                     } :
                      $is_s_instr ? { {21{$instr[31]}} , $instr[30:25], $instr[11:7]                       } :
                      $is_b_instr ? { {20{$instr[31]}} , $instr[7]    , $instr[30:25], $instr[11:8] , 1'b0 } :
                      $is_u_instr ? { $instr[31]       , $instr[30:12], 12'b0                              } :
                                    // default $is_j_instr ? 
                                    { {12{$instr[31]}} , $instr[19:12], $instr[20]   , $instr[30:21], 1'b0 } ;
         
         $rs1_valid    = $is_r_instr || $is_i_instr || $is_s_instr || $is_b_instr;
         $rs2_valid    = $is_r_instr || $is_s_instr || $is_b_instr;
         $rd_valid     = $is_r_instr || $is_i_instr || $is_u_instr || $is_j_instr;
         $funct3_valid = $rs1_valid;
         $funct7_valid = $is_r_instr;
         
         $opcode[6:0] = $instr[ 6: 0];
         
         ?$rs1_valid
            $rs1[4:0]    = $instr[19:15];
         ?$rs2_valid
            $rs2[4:0]    = $instr[24:20];
         ?$rd_valid
            $rd[3:0]     = $instr[11: 7];
         ?$funct3_valid
            $funct3[2:0] = $instr[14:12];
         ?$funct7_valid
            $funct7[5:0] = $instr[31:25];
         
         // individual instructions
         $dec_bits[10:0] = {$funct7[5], $funct3, $opcode};
         
         $is_beq   = $dec_bits ==? 11'bx_000_1100011;
         $is_bne   = $dec_bits ==? 11'bx_001_1100011;
         $is_blt   = $dec_bits ==? 11'bx_100_1100011;
         $is_bge   = $dec_bits ==? 11'bx_101_1100011;
         $is_bltu  = $dec_bits ==? 11'bx_110_1100011;
         $is_bgeu  = $dec_bits ==? 11'bx_111_1100011;
         
         $is_sltiu = $dec_bits ==? 11'bx_011_0010011;
         $is_xori  = $dec_bits ==? 11'bx_100_0010011;
         $is_ori   = $dec_bits ==? 11'bx_110_0010011;
         $is_andi  = $dec_bits ==? 11'bx_111_0010011;
         $is_slli  = $dec_bits ==? 11'b0_001_0010011;
         $is_srli  = $dec_bits ==? 11'b0_101_0010011;
         $is_srai  = $dec_bits ==? 11'b1_101_0010011;
         
         $is_add   = $dec_bits ==? 11'b0_000_0110011;
         $is_sub   = $dec_bits ==? 11'b1_000_0110011;
         $is_sll   = $dec_bits ==? 11'b0_001_0110011;
         $is_slt   = $dec_bits ==? 11'b0_010_0110011;
         $is_sltu  = $dec_bits ==? 11'b0_011_0110011;
         $is_xor   = $dec_bits ==? 11'b0_100_0110011;
         $is_srl   = $dec_bits ==? 11'b0_101_0110011;
         $is_sra   = $dec_bits ==? 11'b1_101_0110011;
         $is_or    = $dec_bits ==? 11'b0_110_0110011;
         $is_and   = $dec_bits ==? 11'b0_111_0110011;
         
         $is_lui   = $dec_bits ==? 11'bx_xxx_0110111;
         $is_auipc = $dec_bits ==? 11'bx_xxx_0010111;
         $is_jal   = $dec_bits ==? 11'bx_xxx_1101111;
         $is_jalr  = $dec_bits ==? 11'bx_000_1100111;
         // all load treated the same for now
         $is_load  = $opcode ==  7'b0000011;

         $is_addi  = $dec_bits ==? 11'bx_000_0010011;
         $is_slti = $dec_bits ==?  11'bx_010_0010011;
         
         $is_jump = $is_jal || $is_jalr;
         // end decode
      
      @2
         // REGISTER READ
         /rf$reset = $reset;
         $rf_rd_en1 = $rs1_valid;
         $rf_rd_en2 = $rs2_valid;
         $rf_rd_index1[4:0] = $rs1;
         $rf_rd_index2[4:0] = $rs2;
         
         // bypass logic
         $bypass_rs1 = ($rs1==>>1$rd) && >>1$rf_wr_en;
         $bypass_rs2 = ($rs2==>>1$rd) && >>1$rf_wr_en;
         
         $src1_value[31:0] = $bypass_rs1 ? >>1$result : $rf_rd_data1;
         $src2_value[31:0] = $bypass_rs2 ? >>1$result : $rf_rd_data2;
         
         // BRANCH TARGET 
         $br_tgt_pc[31:0] = $pc + $imm;
      
      @3
         $DEBUG_AT3_imem_rd_addr[3:0] = $imem_rd_addr;
         $DEBUG_AT3_rd_valid = $rd_valid;
         
         $sltu_rslt  = $src1_value < $src2_value;
         $sltiu_rslt = $src1_value < $imm       ;
         // BEGIN ALU
         $result[31:0] =
            $is_andi   ? $src1_value & $imm              :
            $is_ori    ? $src1_value | $imm              :
            $is_xori   ? $src1_value ^ $imm              :
            $is_addi   ? $src1_value + $imm              :
            $is_slli   ? $src1_value << $imm[5:0]        :
            $is_srli   ? $src1_value >> $imm[5:0]        :
            $is_and    ? $src1_value & $src2_value       :
            $is_or     ? $src1_value | $src2_value       :
            $is_xor    ? $src1_value ^ $src2_value       :
            $is_srai   ? { {32{$src1_value[31]}}, $src1_value} >> $imm[4:0] :
            $is_slt    ? ($src1_value[31] == $src2_value[31]) ? $sltu_rslt  : {31'b0, $src1_value[31]} :
            $is_slti   ? ($src1_value[31] == $imm[31]       ) ? $sltiu_rslt : {31'b0, $src1_value[31]} :
            $is_sra    ? { {32{$src1_value[31]}}, $src1_value} >> $src2_value[4:0] :
            $is_add    ? $src1_value + $src2_value       :
            $is_sub    ? $src1_value - $src2_value       :
            $is_sll    ? $src1_value << $src2_value[4:0] :
            $is_srl    ? $src1_value >> $src2_value[4:0] :
            $is_sltu   ? $sltu_rslt                      :
            $is_sltiu  ? $sltiu_rslt                     :
            $is_lui    ? {$imm[31:12] , 12'b0}           :
            $is_auipc  ? $pc + $imm                      :
            $is_jal    ? $pc + 4                         :
            $is_jalr   ? $pc + 4                         :
            // load store addres
            $valid_load ? $src1_value + $imm             :
            $is_s_instr ? $src1_value + $imm             :
            
            // default
                       32'bx                             ;
         // END ALU
         
         $jalr_tgt_pc = $src1_value + $imm;
         
         // BRANCHING
         $taken_br = ($is_beq  && ( $src1_value==$src2_value)) ||
                     ($is_bne  && ( $src1_value!=$src2_value)) ||
                     ($is_blt  && (($src1_value< $src2_value) ^ ($src1_value[31] != $src2_value[31]))) ||
                     ($is_bge  && (($src1_value>=$src2_value) ^ ($src1_value[31] != $src2_value[31]))) ||
                     ($is_bltu && ( $src1_value< $src2_value)) ||
                     ($is_bgeu && ( $src1_value>=$src2_value));
         
         $valid_load = $valid && $is_load;
         // Branch and load shadow
         $valid = !(>>1$taken_br   || >>2$taken_br  ) &&
                  !(>>1$valid_load || >>2$valid_load) &&
                  !(>>1$is_jump    || >>2$is_jump   );

         // REGISTER WRITE
         $rf_wr_en = ($valid && $rd_valid && ($rd !== 0) && !$valid_load) || // regular reg write
                     >>2$valid_load;                         // load data
   
         //$rf_wr_index[4:0] = $rd;
         $rf_wr_index[4:0] = >>2$valid_load ? >>2$rd : $rd;
         $rf_wr_data[31:0] = !$valid ? >>2$ld_data : $result; // load result appears after 2cc 
                                                           // and $valid will be 0
         
         
      @4
         /dmem$reset = $reset;
         $dmem_wr_en = $valid && $is_s_instr;
         $dmem_addr[3:0]  = $result[5:2];
         $dmem_wr_data[31:0] = $src2_value;
         $dmem_rd_en = $valid_load;
      @5
         $ld_data[31:0] = $dmem_rd_data;

         //$dmem_rd_index[5:0] 
         //`BOGUS_USE($is_load);

      // Note: Because of the magic we are using for visualisation, if visualisation is enabled below,
      //       be sure to avoid having unassigned signals (which you might be using for random inputs)
      //       other than those specifically expected in the labs. You'll get strange errors for these.

   
   // Assert these to end simulation (before Makerchip cycle limit).
   *passed = *cyc_cnt > 200; 
   //*passed = |cpu/xreg[10]>>10$value == (1+2+3+4+5+6+7+8+9);
   *failed = 1'b0;
   
   // Macro instantiations for:
   //  o instruction memory
   //  o register file
   //  o data memory
   //  o CPU visualization
   |cpu
      m4+imem(@1)    // Args: (read stage)
      m4+rf(@2, @3)  // Args: (read stage, write stage) - if equal, no register bypass is required
      m4+dmem(@4)    // Args: (read/write stage)

   //m4+cpu_viz(@4)    // For visualisation, argument should be at least equal to the last stage of CPU logic. @4 would work for all labs.
\SV
   endmodule
