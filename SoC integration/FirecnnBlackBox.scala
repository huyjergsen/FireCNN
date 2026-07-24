// =============================================================================
// File    : FirecnnBlackBox.scala
// Project : FireCNN – CNN Accelerator IP for Chipyard SoC
// Purpose : Chisel BlackBox wrapper around the SystemVerilog RTL top module
//           (model.sv).  The BlackBox exposes the RTL port list to Chisel and
//           registers all .sv source files so that the Chipyard build system
//           copies them into the elaboration working directory.
// =============================================================================

package firecnn

import chisel3._
import chisel3.util._

// ---------------------------------------------------------------------------
// FireCNNBlackBoxIO – Port bundle that mirrors model.sv's I/O exactly.
//
//  clk          : System clock (all RTL registers are synchronous rising-edge).
//  rst          : Synchronous active-high reset.
//  en           : Enable signal.  Pulled high once per inference run.
//                 The RTL starts consuming data_in on the cycle after en rises.
//  load_weight  : Weight-load mode strobe.  When asserted, weight_data/addr
//                 are written into the on-chip weight RAMs instead of running
//                 inference.
//  weight_data  : 64-bit packed weight data bus (8 x INT8 per beat).
//  weight_addr  : Address into the weight RAM for the current beat.
//  data_in      : Input pixel data bus, width = dataWidth × inputChannel bits
//                 (e.g. 24 bits for 8-bit RGB).
//  data_out     : Inference result output, width = outputWidth bits.
//  valid        : Asserted for one cycle when data_out holds a valid result.
//  done         : Asserted after the entire inference pipeline has drained.
// ---------------------------------------------------------------------------
class FireCNNBlackBoxIO(params: FireCNNParams) extends Bundle {
  val clk         = Input(Clock())
  val rst         = Input(Bool())
  val en          = Input(Bool())
  val load_weight = Input(Bool())
  val weight_data = Input(UInt(params.weightDataWidth.W))
  val weight_addr = Input(UInt(params.weightAddrWidth.W))
  val data_in     = Input(UInt((params.dataWidth * params.inputChannel).W))
  val data_out    = Output(UInt(params.outputWidth.W))
  val valid       = Output(Bool())
  val done        = Output(Bool())
}

// ---------------------------------------------------------------------------
// FireCNNBlackBox – Chisel BlackBox that wraps model.sv.
//
// Parameters are forwarded to the RTL via Verilog parameter overrides (the Map
// argument to BlackBox).  The Chisel parameter names (left side) must match the
// `parameter` names declared in model.sv exactly.
//
// IMPORTANT – SystemVerilog source loading order:
//   The Chipyard/FIRRTL back-end processes addResource() calls in the order
//   listed here.  Dependencies must be loaded before the modules that use them:
//     1. Preprocessor defines  – must come first (shared macros/parameters)
//     2. Leaf arithmetic units – DSP multipliers, adder tree, max tree
//     3. Activation & quant    – pure combinational post-processing
//     4. Memory modules        – weight/kernel RAMs, FIFOs, line buffers
//     5. CNN datapath blocks   – buffers, controller
//     6. Convolution PE        – built from the above sub-modules
//     7. Pooling PE            – independent of conv PE
//     8. Linear/FC PE          – depends on weight RAMs
//     9. Top model             – must be loaded last
// ---------------------------------------------------------------------------
class FireCNNBlackBox(params: FireCNNParams) extends BlackBox(Map(
  "pINPUT_WIDTH"       -> params.inputWidth,
  "pINPUT_HEIGHT"      -> params.inputHeight,
  "pINPUT_CHANNEL"     -> params.inputChannel,
  "pDATA_WIDTH"        -> params.dataWidth,
  "pOUTPUT_WIDTH"      -> params.outputWidth,
  "pWEIGHT_DATA_WIDTH" -> params.weightDataWidth,
  "pWEIGHT_ADDR_WIDTH" -> params.weightAddrWidth,
  "pWEIGHT_BASE_ADDR"  -> params.weightBaseAddr.toInt
)) with HasBlackBoxResource {

  // The desiredName must match the SystemVerilog module name in model.sv.
  override def desiredName = "model"

  val io = IO(new FireCNNBlackBoxIO(params))

  // ==========================================================================
  // SystemVerilog source file registration
  // ==========================================================================
  // All RTL files must be placed in src/main/resources/vsrc/ so that
  // HasBlackBoxResource can locate them via the classpath.
  // ==========================================================================

  // --------------------------------------------------------------------------
  // Stage 1 – Preprocessor defines 
  // --------------------------------------------------------------------------
  // define.sv contains `define macros and shared localparams used by all
  // subsequent modules.  Loading it first ensures macros are visible globally.
  addResource("/vsrc/define.sv")

  // --------------------------------------------------------------------------
  // Stage 2 – DSP and arithmetic modules
  // --------------------------------------------------------------------------
  // These modules have no sub-module dependencies and form the compute core.
  addResource("/vsrc/dsp_single_mult.sv")   // Single-operand DSP multiplier
  addResource("/vsrc/dsp_dual_mult.sv")     // Dual-operand DSP multiplier
  addResource("/vsrc/adder_tree.sv")        // Pipelined reduction adder tree
  addResource("/vsrc/max_tree.sv")          // Pipelined max-value reduction tree

  // --------------------------------------------------------------------------
  // Stage 3 – Activation functions and quantization units
  // --------------------------------------------------------------------------
  addResource("/vsrc/quantize.sv")          // INT8 quantization (scale + clip)
  addResource("/vsrc/dequantize.sv")        // INT8 dequantization (to full-precision)
  addResource("/vsrc/relu.sv")              // ReLU activation (max(0, x))
  addResource("/vsrc/sigmoid.sv")           // Sigmoid activation (lookup-table)

  // --------------------------------------------------------------------------
  // Stage 4 – Memory modules
  // --------------------------------------------------------------------------
  addResource("/vsrc/kernel_ram.sv")        // Kernel (weight) RAM for conv layers
  addResource("/vsrc/weight_ram.sv")        // General weight storage RAM
  addResource("/vsrc/bias_ram.sv")          // Bias term storage RAM
  addResource("/vsrc/line_buffer.sv")       // Sliding-window line buffer for conv
  addResource("/vsrc/fifo.sv")              // Generic synchronous FIFO

  // --------------------------------------------------------------------------
  // Stage 5 – CNN buffer and global controller
  // --------------------------------------------------------------------------
  addResource("/vsrc/cnn_buffer.sv")        // Receptive-field buffer (kernel_size rows)
  addResource("/vsrc/cnn_controller.sv")    // Convolution scan-order FSM controller

  // --------------------------------------------------------------------------
  // Stage 6 – Convolution Processing Element (PE)
  // --------------------------------------------------------------------------
  addResource("/vsrc/pe_conv_mac_buffer_in.sv")   // Input staging buffer for conv PE
  addResource("/vsrc/pe_conv_mac_buffer_out.sv")  // Output reorder buffer for conv PE
  addResource("/vsrc/pe_conv_mac_datapath.sv")    // MAC datapath (multiply-accumulate)
  addResource("/vsrc/pe_conv_mac_controller.sv")  // Timing controller for conv PE pipeline
  addResource("/vsrc/pe_conv_mac.sv")             // Conv PE top (assembles the above)
  addResource("/vsrc/conv.sv")                    // Convolution layer top module

  // --------------------------------------------------------------------------
  // Stage 7 – Pooling Processing Element (PE)
  // --------------------------------------------------------------------------
  addResource("/vsrc/pe_pooling_datapath.sv")  // Max/avg pooling datapath
  addResource("/vsrc/pe_pooling.sv")           // Pooling PE top
  addResource("/vsrc/pooling.sv")              // Pooling layer top module

  // --------------------------------------------------------------------------
  // Stage 8 – Fully-Connected (Linear) Processing Element (PE)
  // --------------------------------------------------------------------------
  addResource("/vsrc/pe_linear_mac_datapath.sv")   // FC MAC datapath
  addResource("/vsrc/pe_linear_mac_controller.sv") // Timing controller for FC PE
  addResource("/vsrc/pe_linear_mac.sv")            // FC PE top
  addResource("/vsrc/linear_controller.sv")        // FC layer scan controller
  addResource("/vsrc/linear.sv")                   // Fully-connected layer top module

  // --------------------------------------------------------------------------
  // Stage 9 – Top module (loaded last)
  // --------------------------------------------------------------------------
  // model.sv instantiates all of the above modules and connects them in a
  // FIFO-chained pipeline: conv1→pool1→conv2→pool2→...→conv5→pool5→fc.
  addResource("/vsrc/model.sv")
}
