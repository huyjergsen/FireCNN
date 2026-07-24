// =============================================================================
// File   : firecnn_baremetal.c
// Project: FireCNN - Baremetal driver for the CNN hardware accelerator
// Description:
//   This bare-metal test driver exercises the FireCNN SoC by loading the
//   model weights once and then running inference for multiple images. Each
//   input image is copied into DRAM before the hardware pipeline is triggered,
//   and the prediction result is printed for every image.
// =============================================================================
#include <stdint.h>
#include <stdio.h>

// -----------------------------------------------------------------------------
// 1. Test data includes
//    To run N images, provide N header files containing:
//      - uint64_t image_data_X[]  (packed two pixels per 64-bit word)
//      - #define IMG_WIDTH_X 128
//      - #define IMG_HEIGHT_X 128
// -----------------------------------------------------------------------------
#include "image_data.h" // image_data_1[], image_data_2[], ... image_data_5[]
#include "weights.h"

// -----------------------------------------------------------------------------
// 2. Test configuration
// -----------------------------------------------------------------------------
#define NUM_TEST_IMAGES 5

// Pointer table for the test images. Each image buffer stores packed pixel
// data in uint64_t words, with two pixels per word.
static const uint64_t *const test_images[NUM_TEST_IMAGES] = {
    image_data_1,
    image_data_2,
    image_data_3,
    image_data_4,
    image_data_5,
};

// Human-readable labels used for logging and result reporting.
static const char *const test_labels[NUM_TEST_IMAGES] = {
    "FIRE   - Fire226.jpg",
    "NOFIRE - no-Fire330.jpg",
    "FIRE   - Fire381.jpg",
    "NOFIRE - no-Fire554.jpg",
    "FIRE   - Fire459.jpg",
};

// -----------------------------------------------------------------------------
// 3. Register map and memory layout
// -----------------------------------------------------------------------------
#define FIRECNN_BASE_ADDR 0x10040000

#define REG_CONTROL 0x00
#define REG_STATUS 0x04
#define REG_IMG_ADDR 0x10
#define REG_WGT_ADDR 0x18
#define REG_OUT_ADDR 0x20
#define REG_IMG_SIZE 0x28
#define REG_WGT_SIZE 0x2C
#define REG_PIXELS_READ 0x30
#define REG_PIXELS_FED 0x34
#define REG_WGT_LOADED 0x38
#define REG_PERF_CYCLES 0x3C

#define FIRECNN_REG(offset) (*(volatile uint64_t *)(FIRECNN_BASE_ADDR + offset))
#define FIRECNN_REG32(offset) \
  (*(volatile uint32_t *)(FIRECNN_BASE_ADDR + offset))

// Control register bit definitions.
#define CTRL_INFER 0x1u    // Bit[0]: start inference
#define CTRL_LOAD_WGT 0x3u // Bits[0:1]: load weights
#define CTRL_RESET 0x4u    // Bit[2]: reset the hardware pipeline
#define CTRL_IDLE 0x0u     // No operation

// DRAM layout used by the test harness.
#define DRAM_BASE_ADDR 0x80000000
#define IMG_OFFSET 0x01000000
#define WGT_OFFSET 0x02000000
#define RES_OFFSET 0x03000000

// -----------------------------------------------------------------------------
// 4. Low-level helper functions
// -----------------------------------------------------------------------------
static void print_separator(const char *title) {
  printf("\n--------------------------------------------\n");
  printf("%s\n", title);
  printf("--------------------------------------------\n");
}

static uint64_t read_cycles(void) {
  uint64_t cycles;
  asm volatile("rdcycle %0" : "=r"(cycles));
  return cycles;
}

static void flush_cache(uint64_t start_addr, uint64_t size_bytes) {
  asm volatile("fence");
  volatile uint64_t *ptr = (volatile uint64_t *)start_addr;
  uint64_t sum = 0;
  for (int i = 0; i < (int)(size_bytes / 8); i += 4) {
    sum += ptr[i];
  }
  asm volatile("" : : "r"(sum));
  asm volatile("fence");
}

static void decode_status(uint32_t status) {
  printf("  [Status=0x%02x] Start:%d Busy:%d DMADone:%d Err:%d ModelDone:%d\n",
         status, (status >> 0) & 1u, (status >> 1) & 1u, (status >> 2) & 1u,
         (status >> 3) & 1u, (status >> 4) & 1u);
}

// -----------------------------------------------------------------------------
// 5. Weight loading routine
//    This operation is performed once before the inference loop begins.
// -----------------------------------------------------------------------------
static void load_weights(uint64_t wgt_addr, int num_weights) {
  print_separator("PHASE 1: LOADING WEIGHTS");

  FIRECNN_REG(REG_WGT_ADDR) = wgt_addr;
  FIRECNN_REG32(REG_WGT_SIZE) = num_weights;

  uint64_t t1 = read_cycles();
  FIRECNN_REG32(REG_CONTROL) = CTRL_LOAD_WGT;

  volatile uint32_t status;
  int timeout = 0;
  while (1) {
    status = FIRECNN_REG32(REG_STATUS);
    if ((status & 0x04u) || (status & 0x40u)) {
      break;
    }
    if (++timeout > 10000000) {
      printf("  TIMEOUT: Load weights!\n");
      break;
    }
  }
  uint64_t t2 = read_cycles();
  FIRECNN_REG32(REG_CONTROL) = CTRL_IDLE;

  uint32_t loaded = FIRECNN_REG32(REG_WGT_LOADED);
  printf("  Loaded %u / %d weights in %lu cycles\n", loaded, num_weights,
         t2 - t1);
}

// -----------------------------------------------------------------------------
// 6. Single-image inference routine
// -----------------------------------------------------------------------------
static void run_inference(int img_idx, uint64_t img_addr, uint64_t res_addr,
                          const uint64_t *img_data, int num_img_u64) {
  printf("\n============================================\n");
  printf("  IMAGE %d / %d : %s\n", img_idx + 1, NUM_TEST_IMAGES,
         test_labels[img_idx]);
  printf("============================================\n");

  // Clear the previous result marker before starting a new inference.
  volatile uint64_t *res_ptr = (volatile uint64_t *)res_addr;
  *res_ptr = 0xDEADBEEFCAFEBABE;
  flush_cache(res_addr, 8);

  // Copy the new input image into DRAM.
  uint64_t *ram_img_ptr = (uint64_t *)img_addr;
  for (int i = 0; i < num_img_u64; i++) {
    ram_img_ptr[i] = img_data[i];
  }
  flush_cache(img_addr, (uint64_t)num_img_u64 * 8);

  // Configure the image base address, output base address, and image size.
  FIRECNN_REG(REG_IMG_ADDR) = img_addr;
  FIRECNN_REG(REG_OUT_ADDR) = res_addr;
  FIRECNN_REG32(REG_IMG_SIZE) = IMG_WIDTH * IMG_HEIGHT;

  // Reset the hardware pipeline before launching a new inference.
  // This clears FIFOs, the done latch, and internal counters in the model.
  // The hardware must return to IDLE before the next inference begins.
  FIRECNN_REG32(REG_CONTROL) = CTRL_RESET;
  for (volatile int d = 0; d < 100; d++) {
    ;
  }
  FIRECNN_REG32(REG_CONTROL) = CTRL_IDLE;
  for (volatile int d = 0; d < 100; d++) {
    ;
  }

  // Start inference and wait for completion or timeout.
  uint64_t t3 = read_cycles();
  FIRECNN_REG32(REG_CONTROL) = CTRL_INFER;

  volatile uint32_t status;
  int timeout = 0;
  while (1) {
    status = FIRECNN_REG32(REG_STATUS);
    if ((status & 0x04u) || (status & 0x40u)) {
      break;
    }
    if (++timeout > 50000000) {
      printf("  TIMEOUT: Inference!\n");
      break;
    }
  }
  uint64_t t4 = read_cycles();
  FIRECNN_REG32(REG_CONTROL) = CTRL_IDLE;

  // Read back the result from DRAM and decode the final class.
  flush_cache(res_addr, 8);
  uint64_t raw_val = *res_ptr;
  uint32_t final_cls = (uint32_t)(raw_val & 0xFFFFFFFF);

  uint32_t hw_cycles = FIRECNN_REG32(REG_PERF_CYCLES);
  uint32_t pixels_fed = FIRECNN_REG32(REG_PIXELS_FED);
  uint32_t thru = pixels_fed ? (hw_cycles * 100) / pixels_fed : 0;

  decode_status(status);
  printf("  HW Cycles  : %u\n", hw_cycles);
  printf("  Pixels Fed : %u / %u\n", pixels_fed, IMG_WIDTH * IMG_HEIGHT);
  printf("  Throughput : %u.%02u cycles/pixel\n", thru / 100, thru % 100);
  printf("  SW Time    : %lu cycles\n", t4 - t3);

  if (raw_val == 0xDEADBEEFCAFEBABE) {
    printf("  Result     : ERROR - DMA did not write result!\n");
  } else if (final_cls == 1) {
    printf("  >>> PREDICTION: FIRE DETECTED (CO LUA) !!!\n");
  } else if (final_cls == 2) {
    printf("  >>> PREDICTION: NO FIRE (AN TOAN).\n");
  } else {
    printf("  >>> PREDICTION: UNKNOWN (0x%08x)\n", final_cls);
  }
}

// -----------------------------------------------------------------------------
// 7. Main 
// -----------------------------------------------------------------------------
int main(void) {
  uint64_t img_addr = DRAM_BASE_ADDR + IMG_OFFSET;
  uint64_t wgt_addr = DRAM_BASE_ADDR + WGT_OFFSET;
  uint64_t res_addr = DRAM_BASE_ADDR + RES_OFFSET;

  uint64_t *ram_wgt_ptr = (uint64_t *)wgt_addr;
  int num_img_u64 = (IMG_WIDTH * IMG_HEIGHT) / 2;
  int num_wgt_u64 = NUM_WEIGHTS;

  printf("\n============================================\n");
  printf("  FireCNN SoC - Multi-Image Inference Test  \n");
  printf("  Images: %d  |  %dx%d pixels each\n", NUM_TEST_IMAGES, IMG_WIDTH,
         IMG_HEIGHT);
  printf("============================================\n");
  printf("  Image  RAM : 0x%lx\n", img_addr);
  printf("  Weight RAM : 0x%lx\n", wgt_addr);
  printf("  Result RAM : 0x%lx\n", res_addr);

  // Copy weights into DRAM once before the first inference run.
  for (int i = 0; i < num_wgt_u64; i++) {
    ram_wgt_ptr[i] = weights[i];
  }
  flush_cache(wgt_addr, (uint64_t)num_wgt_u64 * 8);

  // Load the weights into the hardware accelerator once.
  load_weights(wgt_addr, num_wgt_u64);

  // Run inference across the configured test image set.
  int fire_count = 0;
  int nofire_count = 0;

  for (int i = 0; i < NUM_TEST_IMAGES; i++) {
    run_inference(i, img_addr, res_addr, test_images[i], num_img_u64);

    // Read back the latest result to update the summary counters.
    flush_cache(res_addr, 8);
    volatile uint64_t *res_ptr = (volatile uint64_t *)res_addr;
    uint32_t cls = (uint32_t)(*res_ptr & 0xFFFFFFFF);
    if (cls == 1) {
      fire_count++;
    } else if (cls == 2) {
      nofire_count++;
    }
  }

  // Print the final summary.
  printf("\n============================================\n");
  printf("  SUMMARY: %d images tested\n", NUM_TEST_IMAGES);
  printf("  FIRE   : %d\n", fire_count);
  printf("  NO FIRE: %d\n", nofire_count);
  printf("  UNKNOWN: %d\n", NUM_TEST_IMAGES - fire_count - nofire_count);
  printf("============================================\n");

  return 0;
}
