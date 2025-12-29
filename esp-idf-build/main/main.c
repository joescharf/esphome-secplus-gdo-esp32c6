/*
 * ESP32-C6 GDO Library Build Verification
 *
 * This is a minimal test application to verify the gdolib
 * compiles correctly for the ESP32-C6 RISC-V architecture.
 */

#include <stdio.h>
#include "gdo.h"
#include "esp_log.h"

static const char *TAG = "gdo_test";

void app_main(void) {
    ESP_LOGI(TAG, "ESP32-C6 GDO Library - Build verification only");
    ESP_LOGI(TAG, "This application is for library compilation testing");
}
