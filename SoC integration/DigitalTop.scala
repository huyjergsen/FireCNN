// =============================================================================
// File        : DigitalTop.scala
// Project     : FireCNN – CNN Accelerator IP for Chipyard SoC
// Purpose     : Chipyard DigitalTop – top-level SoC "digital" module that
//               mixes in all optional peripherals (UART, SPI, GPIO, etc.) and
//               the FireCNN CNN accelerator.
//
//               DigitalTop sits below the ChipTop (pad ring) and above the
//               individual CPU tile / L2 cache hierarchy.  Every peripheral
//               enables itself if and only if the corresponding Config fragment
//               is present (CDE optional instantiation pattern).
//
// FireCNN integration:
//   The `with firecnn.CanHavePeripheryFireCNN` mixin wires the accelerator to:
//     - PBUS: MMIO control registers (CPU reads/writes via AXI4→TL bridge)
//     - SBUS: DMA master port (accelerator fetches image/weight data from DRAM)
//   The accelerator is instantiated only when `FireCNNKey` is set in the Config.
// =============================================================================

package chipyard

import chisel3._

import freechips.rocketchip.subsystem._
import freechips.rocketchip.system._
import freechips.rocketchip.trace._
import org.chipsalliance.cde.config.Parameters
import freechips.rocketchip.devices.tilelink._
import firecnn.CanHavePeripheryFireCNN

// ---------------------------------------------------------------------------
// DigitalTop – SoC top-level (digital domain; no pad ring)
//
// Trait composition order matters: each trait with lazy module bodies is
// evaluated in the order listed.  Hardware with ordering dependencies should
// be placed such that producers come before consumers.
// ---------------------------------------------------------------------------

// DOC include start: DigitalTop
class DigitalTop(implicit p: Parameters) extends ChipyardSystem
  // ---- testchipip peripherals ----
  with testchipip.tsi.CanHavePeripheryUARTTSI            // Optional UART-based TSI transport
  with testchipip.boot.CanHavePeripheryCustomBootPin      // Optional custom boot pin
  with testchipip.cosim.CanHaveTraceIO                   // Optional co-simulation trace IO
  with testchipip.soc.CanHaveSubsystemInjectors           // Subsystem injector API
  with testchipip.soc.CanHaveSwitchableOffchipBus         // Switchable off-chip bus interface
  with testchipip.iceblk.CanHavePeripheryBlockDevice      // Optional block device (IceBlk)
  with testchipip.serdes.CanHavePeripheryTLSerial         // Optional TL-serial interface
  with testchipip.serdes.old.CanHavePeripheryTLSerial     // DEPRECATED TL-serial (legacy compat)
  with testchipip.soc.CanHavePeripheryChipIdPin           // Optional chip-ID pin (multi-chip)
  // ---- SiFive block peripherals ----
  with sifive.blocks.devices.i2c.HasPeripheryI2C          // Optional SiFive I2C controller
  with sifive.blocks.devices.timer.HasPeripheryTimer      // Optional timer device
  with sifive.blocks.devices.pwm.HasPeripheryPWM          // Optional PWM controller
  with sifive.blocks.devices.uart.HasPeripheryUART        // Optional SiFive UART
  with sifive.blocks.devices.gpio.HasPeripheryGPIO        // Optional GPIO bank
  with sifive.blocks.devices.spi.HasPeripherySPIFlash     // Optional SPI flash controller
  with sifive.blocks.devices.spi.HasPeripherySPI          // Optional SPI port
  // ---- Network-on-chip / accelerator support ----
  with icenet.CanHavePeripheryIceNIC                      // IceNIC (FireSim network card)
  with chipyard.example.CanHavePeripheryGCD               // GCD example accelerator widget
  // ---- FireCNN CNN Accelerator ----
  with firecnn.CanHavePeripheryFireCNN                    // FireCNN IP (enabled by WithFireCNN config)
  // ---- Clock / reset ----
  with chipyard.clocking.HasChipyardPRCI                  // Chipyard clock/reset distribution
  with chipyard.clocking.CanHaveClockTap                  // Optional clock tap output port
  // ---- Global NoC ----
  with constellation.soc.CanHaveGlobalNoC                 // Optional global Network-on-Chip
  with rerocc.CanHaveReRoCCTiles                          // ReRoCC-attached accelerator tiles
{
  override lazy val module = new DigitalTopModule(this)
}

// ---------------------------------------------------------------------------
// DigitalTopModule – concrete hardware implementation of DigitalTop.
//
// DontTouch annotation prevents Firrtl from optimizing away top-level ports
// during aggressive dead-code elimination, which is important for simulation
// harnesses that reference internal nets by name.
// ---------------------------------------------------------------------------
class DigitalTopModule(l: DigitalTop) extends ChipyardSystemModule(l)
  with freechips.rocketchip.util.DontTouch
// DOC include end: DigitalTop