// =============================================================================
// File    : FireCNNConfigs.scala
// Project : FireCNN – CNN Accelerator IP for Chipyard SoC
// Purpose : Chipyard configuration fragments (Config mixins) that wire the
//           FireCNN accelerator into a specific SoC configuration.
//           Configurations here are composed using Chipyard's CDE library and
//           stacked with the standard RocketConfig.
// =============================================================================

package chipyard

import org.chipsalliance.cde.config.{Config}
import firecnn.{FireCNNKey, FireCNNParams}

// ---------------------------------------------------------------------------
// WithFireCNN – Config fragment that instantiates the FireCNN accelerator.
//
// This mixin injects a FireCNNParams instance into the CDE key-value store.
// All child parameters must match the synthesized RTL in model.sv exactly;
// mismatches will cause incorrect DMA addressing or wrong inference results.
//
// Parameter overview (see FirecnnParams.scala for full documentation):
//
//   address         : MMIO base for CPU-side control registers.
//                     0x10040000 falls in Chipyard's peripheral address window.
//
//   inputWidth /
//   inputHeight     : Must equal the image dimensions expected by model.sv.
//                     Both set to 128 → 128×128 pixel input.
//
//   inputChannel    : 3 = RGB image; must match pINPUT_CHANNEL in model.sv.
//
//   dataWidth       : 8-bit quantized activations throughout the network.
//
//   outputWidth     : 32-bit output register holding the final class scores.
//
//   weightDataWidth : 64 bits = one DMA beat = 8 packed INT8 weight bytes.
//
//   weightAddrWidth : 32 bits → supports up to 4 billion weight addresses.
//
//   weightBaseAddr  : 0 → weights start at the very beginning of weight memory.
// ---------------------------------------------------------------------------
class WithFireCNN extends Config((site, here, up) => {
  case FireCNNKey => Some(FireCNNParams(
    address         = 0x10040000L, // MMIO base address (PBUS peripheral window)
    inputWidth      = 128,         // Image width  in pixels
    inputHeight     = 128,         // Image height in pixels
    inputChannel    = 3,           // RGB: 3 channels
    dataWidth       = 8,           // INT8 quantization
    outputWidth     = 32,          // 32-bit classification result
    weightDataWidth = 64,          // 64-bit weight DMA bus (8 x INT8)
    weightAddrWidth = 32,          // 32-bit weight address bus
    weightBaseAddr  = 0            // Weights start at address 0
  ))
})

// ---------------------------------------------------------------------------
// FireCNNRocketConfig – Complete SoC configuration: Rocket core + FireCNN IP.
//
// Config stack (applied bottom-to-top, i.e. right-to-left):
//
//   1. chipyard.RocketConfig
//         Base Rocket in-order CPU configuration with default Chipyard settings:
//         - L1 I-Cache : 16 KB, 4-way set-associative
//         - L1 D-Cache : 16 KB, 4-way set-associative
//         - L2 Cache   : 512 KB, 8-way, 1 bank (Inclusive)
//         - DRAM       : 256 MB (Chipyard default AXI4 memory model)
//
//   2. WithFireCNN
//         Enables the FireCNN accelerator as a TileLink peripheral.
//         Attaches MMIO registers to PBUS and DMA master port to SBUS.
//
//   3. freechips.rocketchip.subsystem.WithoutTLMonitors
//         Disables TileLink assertion monitors to speed up simulation and
//         reduce elaboration time in large designs.
// ---------------------------------------------------------------------------
class FireCNNRocketConfig extends Config(
  new freechips.rocketchip.subsystem.WithoutTLMonitors ++
  new WithFireCNN                                       ++
  new chipyard.RocketConfig
)