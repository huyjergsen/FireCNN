// =============================================================================
// File    : FirecnnConfig.scala
// Project : FireCNN accelerator integration for Chipyard
// Purpose : Attach the FireCNN accelerator to the SoC interconnect through
//           MMIO on PBUS and DMA on SBUS.
// =============================================================================

package firecnn

import chisel3._
import freechips.rocketchip.diplomacy._
import freechips.rocketchip.tilelink._
import freechips.rocketchip.subsystem.{BaseSubsystem, PBUS, SBUS}
import freechips.rocketchip.prci.{ClockSinkDomain, ClockSinkParameters}
import org.chipsalliance.cde.config.Parameters

// ---------------------------------------------------------------------------
// CanHavePeripheryFireCNN
//
// Instantiates FireCNN when FireCNNKey is present. The accelerator is
// connected to PBUS for control registers and to SBUS for DMA traffic.
// ---------------------------------------------------------------------------
trait CanHavePeripheryFireCNN { this: BaseSubsystem =>

  private val portName = "firecnn"

  // PBUS is used for MMIO register access from the CPU.
  private val pbus = locateTLBusWrapper(PBUS)

  // SBUS is used for DMA reads/writes to memory.
  private val sbus = locateTLBusWrapper(SBUS)

  val firecnn = p(FireCNNKey) match {
    case Some(params) => {
      // Create an isolated clock domain for the accelerator.
      val domain = LazyModule(new ClockSinkDomain(ClockSinkParameters(take = None)))

      // Instantiate the FireCNN TileLink module inside that domain.
      val f = domain { LazyModule(new TLFireCNN(params, sbus.beatBytes)(p)) }

      // Drive the accelerator domain from the PBUS clock.
      domain.clockNode := pbus.fixedClockNode

      // -----------------------------------------------------------------------
      // MMIO connection: CPU access to control/status registers
      // -----------------------------------------------------------------------
      pbus.coupleTo(s"${portName}_mmio") {
        f.mmioNode :=
          TLBuffer() :=
          TLWidthWidget(pbus.beatBytes) :=
          TLFragmenter(pbus.beatBytes, pbus.blockBytes) := _
      }

      // -----------------------------------------------------------------------
      // DMA connection: accelerator accesses memory through SBUS
      // -----------------------------------------------------------------------
      sbus.coupleFrom(s"${portName}_dma") {
        _ :=
          TLBuffer() :=
          TLWidthWidget(sbus.beatBytes) :=
          f.dmaNode
      }

      Some(f)
    }
    case None => None
  }
}
