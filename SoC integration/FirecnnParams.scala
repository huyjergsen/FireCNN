// =============================================================================
// File    : FirecnnParams.scala
// Project : FireCNN – CNN Accelerator IP for Chipyard SoC
// Purpose : Hardware parameter bundle for the FireCNN accelerator module.
//           These parameters are passed through Chisel diplomacy and Chipyard's
//           CDE (Configuration-based Design Environment) key-value system.
// =============================================================================

package firecnn

import org.chipsalliance.cde.config.{Field, Parameters}

// ---------------------------------------------------------------------------
// FireCNNParams – runtime-configurable hardware parameters
//
//  address          : MMIO base address on the TileLink Peripheral Bus (PBUS).
//                     Must be unique across all peripherals in the SoC address map.
//                     Default 0x1004_0000 matches the Chipyard example address space.
//
//  inputWidth       : Width  of the input image in pixels.
//  inputHeight      : Height of the input image in pixels.
//  inputChannel     : Number of input color channels (e.g. 3 for RGB).
//
//  dataWidth        : Bit-width of each pixel sample (e.g. 8-bit quantized).
//
//  outputWidth      : Bit-width of the final classification output word.
//                     Typically 32-bit to carry softmax scores or class index.
//
//  weightDataWidth  : Bit-width of a single DMA weight transfer beat (64-bit
//                     packed weights – 8 x INT8 weights per 64-bit word).
//
//  weightAddrWidth  : Bit-width of the weight RAM address bus.
//                     Must be wide enough to address all weight locations:
//                     addr bits = ceil(log2(total_weight_words)).
//
//  weightBaseAddr   : Starting offset (in units of weightDataWidth beats)
//                     inside the weight memory where layer-0 kernels begin.
//                     Usually 0 when weights are loaded fresh from DRAM.
// ---------------------------------------------------------------------------
case class FireCNNParams(
  // ---- TileLink MMIO mapping ------------------------------------------------
  address         : BigInt = 0x10040000L,  // PBUS peripheral address

  // ---- Input image geometry ------------------------------------------------
  inputWidth      : Int    = 128,          // Image width  (pixels)
  inputHeight     : Int    = 128,          // Image height (pixels)
  inputChannel    : Int    = 3,            // Number of channels (RGB = 3)

  // ---- Data representation -------------------------------------------------
  dataWidth       : Int    = 8,            // Per-pixel quantized bit-width
  outputWidth     : Int    = 32,           // Classification result word width

  // ---- Weight DMA interface ------------------------------------------------
  weightDataWidth : Int    = 64,           // Bits per DMA weight beat (8 x INT8)
  weightAddrWidth : Int    = 16,           // Weight RAM address width (bits)
  weightBaseAddr  : BigInt = 0             // Starting weight address offset
)

// ---------------------------------------------------------------------------
// FireCNNKey – CDE configuration key used to enable/disable the FireCNN IP.
//
// Set to Some(FireCNNParams(...)) in a Config fragment to instantiate the IP.
// Defaults to None so the IP is not present unless explicitly enabled.
// ---------------------------------------------------------------------------
case object FireCNNKey extends Field[Option[FireCNNParams]](None)
