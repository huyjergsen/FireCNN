package firecnn

import chisel3._
import chisel3.util._
import freechips.rocketchip.diplomacy._
import freechips.rocketchip.regmapper._
import freechips.rocketchip.tilelink._
import freechips.rocketchip.resources.SimpleDevice
import org.chipsalliance.cde.config._

// ==============================================================================
// MAIN MODULE
// ==============================================================================

class TLFireCNN(val params: FireCNNParams, beatBytes: Int)(implicit p: Parameters) 
  extends LazyModule {
  
  require(beatBytes >= 8, s"beatBytes must be >= 8 (64-bit), got $beatBytes")
  
  // Register Node (MMIO)
  val mmioNode = TLRegisterNode(
    address = Seq(AddressSet(params.address, 0xFFF)),
    device = new SimpleDevice("firecnn", Seq("ucbbar,firecnn")),
    beatBytes = beatBytes
  )
  
  // DMA Node (Memory Access)
  val dmaNode = TLClientNode(Seq(TLMasterPortParameters.v1(
    clients = Seq(TLMasterParameters.v1(
      name = "firecnn-dma",
      sourceId = IdRange(0, 16) 
    ))
  )))

  lazy val module = new LazyModuleImp(this) {
    withClockAndReset(clock, reset) {
      val (dma_tl, dma_edge) = dmaNode.out.head

      // --- CONSTANTS ---
      val WEIGHT_BURST_SIZE = 8    // 8 weights * 8 bytes = 64 bytes
      val PIXEL_BURST_SIZE  = 16   // 16 pixels * 4 bytes = 64 bytes
      val BURST_BYTES_VAL   = 64.U // Cả 2 đều dùng 64 bytes 

      // --- REGISTERS (MMIO) ---
      val control_reg     = RegInit(0.U(32.W))
      val image_addr_reg  = RegInit(0.U(64.W))
      val weight_addr_reg = RegInit(0.U(64.W))
      val output_addr_reg = RegInit(0.U(64.W))
      val image_size_reg  = RegInit(0.U(32.W))
      val weight_size_reg = RegInit(0.U(32.W))

      // --- DEBUG COUNTERS ---
      val pixels_read    = RegInit(0.U(32.W))
      val pixels_fed     = RegInit(0.U(32.W))
      val weights_loaded = RegInit(0.U(32.W))
      val perf_cycles    = RegInit(0.U(32.W))

      val start_bit       = control_reg(0)
      val load_weight_bit = control_reg(1)
      val reset_bit       = control_reg(2)

      // --- FSM ---
      val s_idle :: s_load_weights :: s_load_wait :: s_load_burst :: s_read_pixels :: s_read_wait :: s_read_burst :: s_feed :: s_compute :: s_write :: s_write_wait :: s_done :: s_error :: Nil = Enum(13)
      val dma_state = RegInit(s_idle)
      
      val busy      = dma_state =/= s_idle && dma_state =/= s_done && dma_state =/= s_error
      val done_flag = dma_state === s_done
      val has_error = dma_state === s_error

      // --- INSTANTIATION ---
      // call class FireCNNBlackBox 
      val firecnn = Module(new FireCNNBlackBox(params))
      
      firecnn.io.clk := clock
      firecnn.io.rst := reset.asBool || reset_bit

      firecnn.io.en           := false.B
      firecnn.io.load_weight  := false.B
      firecnn.io.weight_data  := 0.U
      firecnn.io.weight_addr  := 0.U
      firecnn.io.data_in      := 0.U

      // --- INTERNAL VARIABLES ---
      val current_weight_addr = RegInit(0.U(64.W))
      val current_pixel_addr  = RegInit(0.U(64.W))
      val weight_count        = RegInit(0.U(32.W))
      val pixel_count         = RegInit(0.U(32.W))
      val beats_received      = RegInit(0.U(8.W))

      // --- BUFFERS ---
      val pixel_fifo = Module(new Queue(UInt(24.W), 128))
      pixel_fifo.io.enq.valid := false.B
      pixel_fifo.io.enq.bits  := 0.U
      pixel_fifo.io.deq.ready := false.B

      val weight_buffer       = Reg(Vec(WEIGHT_BURST_SIZE, UInt(64.W)))
      val weight_buffer_idx   = RegInit(0.U(4.W)) 
      val weight_buffer_valid = RegInit(false.B)

      val pixel_beat_buffer = Reg(Vec(beatBytes / 4, UInt(24.W))) 
      val pixel_beat_valid  = RegInit(false.B)
      val pixel_beat_idx    = RegInit(0.U(log2Ceil(beatBytes / 4 + 1).W))
      val pixel_beat_count  = RegInit(0.U(log2Ceil(beatBytes / 4 + 1).W))

      // TileLink Default
      dma_tl.a.valid := false.B
      dma_tl.a.bits  := DontCare
      // Backpressure
      dma_tl.d.ready := (dma_state === s_read_wait) || (dma_state === s_load_wait) || (dma_state === s_write_wait)

      // Counter
      when(busy) { perf_cycles := perf_cycles + 1.U }

      // --- FSM LOGIC ---
      switch(dma_state) {
        // IDLE
        is(s_idle) {
          when(reset_bit) {
            pixels_read    := 0.U
            pixels_fed     := 0.U
            weights_loaded := 0.U
            perf_cycles    := 0.U
            control_reg    := 0.U
          }.elsewhen(start_bit) {
            when(load_weight_bit) {
              dma_state := s_load_weights
              current_weight_addr := weight_addr_reg
              weight_count := 0.U
              weight_buffer_valid := false.B
            }.otherwise {
              dma_state := s_read_pixels
              current_pixel_addr := image_addr_reg
              pixel_count := 0.U
            }
          }
        }
        
        // PHASE 1: LOAD WEIGHTS
        is(s_load_weights) {
          when(weight_count < weight_size_reg) {
            val (legal, get_bundle) = dma_edge.Get(0.U, current_weight_addr, 6.U) // Size 64B
            dma_tl.a.valid := true.B
            dma_tl.a.bits  := get_bundle
            
            when(dma_tl.a.fire) {
              beats_received := 0.U
              weight_buffer_idx := 0.U
              current_weight_addr := current_weight_addr + BURST_BYTES_VAL
              dma_state := s_load_wait
            }
          }.otherwise {
            dma_state := s_done
          }
        }
        
        is(s_load_wait) {
          when(dma_tl.d.fire) {
            val weights_in_beat = beatBytes / 8
            for (i <- 0 until weights_in_beat) {
               if (i < WEIGHT_BURST_SIZE) { 
                 val idx = weight_buffer_idx + i.U
                 when(idx < WEIGHT_BURST_SIZE.U) {
                   weight_buffer(idx) := dma_tl.d.bits.data(64*(i+1)-1, 64*i)
                 }
               }
            }
            weight_buffer_idx := weight_buffer_idx + weights_in_beat.U
            beats_received := beats_received + 1.U
            
            when(dma_edge.last(dma_tl.d)) {
              weight_buffer_valid := true.B
              dma_state := s_load_burst
            }
          }
        }
        
        is(s_load_burst) {
          when(weight_buffer_valid && weight_buffer_idx > 0.U) {
            when(weight_count < weight_size_reg) {
                firecnn.io.load_weight := true.B
                firecnn.io.weight_data := weight_buffer(0)
                firecnn.io.weight_addr := weight_count
                weight_count := weight_count + 1.U
                weights_loaded := weights_loaded + 1.U
            }
            for (i <- 0 until WEIGHT_BURST_SIZE - 1) {
              weight_buffer(i) := weight_buffer(i + 1)
            }
            weight_buffer_idx := weight_buffer_idx - 1.U
            when(weight_buffer_idx === 1.U) {
              weight_buffer_valid := false.B
              dma_state := s_load_weights
            }
          }
        }
        
        // PHASE 2: READ PIXELS (Burst 16 + Safe Check)
        is(s_read_pixels) {
          // Chỉ đọc khi FIFO < 64 để tránh tràn (FIFO Depth = 128)
          when(pixel_count < image_size_reg && pixel_fifo.io.count < 64.U && !pixel_beat_valid) {
            val (legal, get_bundle) = dma_edge.Get(1.U, current_pixel_addr, 6.U) // Size 64B
            dma_tl.a.valid := true.B
            dma_tl.a.bits  := get_bundle
            
            when(dma_tl.a.fire) {
              beats_received := 0.U
              current_pixel_addr := current_pixel_addr + BURST_BYTES_VAL
              dma_state := s_read_wait
            }
          }.elsewhen(pixel_beat_valid) {
            dma_state := s_read_burst
          }.elsewhen(pixel_fifo.io.count > 0.U) {
            dma_state := s_feed
          }.otherwise {
            dma_state := s_compute
          }
        }
        
        is(s_read_wait) {
          when(dma_tl.d.fire) {
            // Unpack 2 pixels from 64-bit beat
            val pixels_per_beat = beatBytes / 4
            for (i <- 0 until (beatBytes / 4)) {
              pixel_beat_buffer(i) := dma_tl.d.bits.data(32*(i+1)-1, 32*i)(23, 0)
            }
            
            val remaining_total = (PIXEL_BURST_SIZE.U) - (beats_received * pixels_per_beat.U)
            pixel_beat_count := Mux(remaining_total < pixels_per_beat.U, remaining_total, pixels_per_beat.U)
            
            pixel_beat_idx := 0.U
            pixel_beat_valid := true.B
            beats_received := beats_received + 1.U
            
            dma_state := s_read_burst
          }
        }
        
        is(s_read_burst) {
          when(pixel_beat_valid && pixel_beat_idx < pixel_beat_count) {
            when(pixel_fifo.io.enq.ready) {
              when(pixel_count < image_size_reg) {
                  pixel_fifo.io.enq.valid := true.B
                  pixel_fifo.io.enq.bits  := pixel_beat_buffer(pixel_beat_idx)
                  pixel_count := pixel_count + 1.U
                  pixels_read := pixels_read + 1.U
              }.otherwise {
                  pixel_fifo.io.enq.valid := false.B
              }
              pixel_beat_idx := pixel_beat_idx + 1.U
            }
          }.otherwise {
            pixel_beat_valid := false.B
            val beats_expected = BURST_BYTES_VAL / beatBytes.U
            
            when(beats_received >= beats_expected) {
               // Xong burst -> Quay lại xin tiếp hoặc Feed
               when(pixel_count < image_size_reg && pixel_fifo.io.count < 64.U) {
                 dma_state := s_read_pixels
               }.otherwise {
                 dma_state := s_feed
               }
            }.otherwise {
               dma_state := s_read_wait
            }
          }
        }
        
        // FEED RTL
        is(s_feed) {
          when(pixel_fifo.io.count > 0.U && pixels_fed < image_size_reg && firecnn.io.ready) {
            pixel_fifo.io.deq.ready := true.B
            when(pixel_fifo.io.deq.fire) {
              firecnn.io.en := true.B
              firecnn.io.data_in := pixel_fifo.io.deq.bits
              pixels_fed := pixels_fed + 1.U
              
              when(pixels_fed + 1.U >= image_size_reg) {
                dma_state := s_compute
              }.elsewhen(pixel_fifo.io.count === 1.U && pixel_count < image_size_reg) {
                dma_state := s_read_pixels
              }
            }
          }.elsewhen(pixel_count < image_size_reg) {
            dma_state := s_read_pixels
          }.otherwise {
            dma_state := s_compute
          }
        }
        
        // COMPUTE & WRITE
        is(s_compute) {
          when(firecnn.io.valid) { // Chờ valid từ RTL
            dma_state := s_write
          }
        }
        
        is(s_write) {
          val (legal, put_bundle) = dma_edge.Put(
            0.U,
            output_addr_reg,
            3.U, // Size 8B
            Cat(0.U(32.W), firecnn.io.data_out)
          )
          dma_tl.a.valid := true.B
          dma_tl.a.bits  := put_bundle
          
          when(dma_tl.a.fire) { dma_state := s_write_wait }
        }
        
        is(s_write_wait) {
          when(dma_tl.d.fire) { dma_state := s_done }
        }
        
        // DONE HANDSHAKE
        is(s_done) {
          when(!start_bit || reset_bit) {
            dma_state := s_idle
            control_reg := 0.U
          }
        }
        
        is(s_error) {
          when(reset_bit) { dma_state := s_idle; control_reg := 0.U }
        }
      }

      val status_val = Cat(0.U(24.W), false.B, false.B, firecnn.io.valid, firecnn.io.done, has_error, done_flag, busy, start_bit)

      mmioNode.regmap(
        0x00 -> Seq(RegField(32, control_reg)),
        0x04 -> Seq(RegField.r(32, status_val)),
        0x10 -> Seq(RegField(64, image_addr_reg)),
        0x18 -> Seq(RegField(64, weight_addr_reg)),
        0x20 -> Seq(RegField(64, output_addr_reg)),
        0x28 -> Seq(RegField(32, image_size_reg)),
        0x2C -> Seq(RegField(32, weight_size_reg)),
        0x30 -> Seq(RegField.r(32, pixels_read)),
        0x34 -> Seq(RegField.r(32, pixels_fed)),
        0x38 -> Seq(RegField.r(32, weights_loaded)),
        0x3C -> Seq(RegField.r(32, perf_cycles))
      )
    } 
  } 
}