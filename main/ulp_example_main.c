/* ULP Example

   This example code is in the Public Domain (or CC0 licensed, at your option.)

   Unless required by applicable law or agreed to in writing, this
   software is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
   CONDITIONS OF ANY KIND, either express or implied.
*/

#include <stdio.h>                      /*Standard Input output*/
#include <math.h>                       /*Maths*/
#include "esp_sleep.h"                  /*esp sleep control functions*/
#include "nvs.h"                        /*The non-volatile storage components save and load data from storage that is preserved between boots. */
#include "nvs_flash.h"
#include "soc/rtc_cntl_reg.h"           /*ULP source files are passed through C preprocessor before the assembler.
                                         This allows certain macros to be used to facilitate access to peripheral registers.
                                        Some existing macros are defined in soc/soc_ulp.h header file. 
                                        These macros allow access to the fields of peripheral registers by their names. 
                                        Peripheral registers names which can be used with these macros are the ones defined in 
                                        soc/rtc_cntl_reg.h, 
                                        soc/rtc_io_reg.h, 
                                        soc/sens_reg.h, and 
                                        soc/rtc_i2c_reg.h.*/
#include "soc/rtc_io_reg.h"
#include "soc/sens_reg.h"
#include "soc/soc.h"                    /*External Peripheral Interrupts*/
#include "driver/gpio.h"                
#include "driver/rtc_io.h"
#include "esp32/ulp.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "sdkconfig.h"

#include "ulp_main.h"

extern const uint8_t ulp_main_bin_start[] asm("_binary_ulp_main_bin_start");                     
extern const uint8_t ulp_main_bin_end[] asm("_binary_ulp_main_bin_end");

const gpio_num_t gpio_scl = GPIO_NUM_32;
const gpio_num_t gpio_sda = GPIO_NUM_33;
const gpio_num_t gpio_int= GPIO_NUM_26;


static void init_ulp_program()
{
    rtc_gpio_deinit(gpio_scl);                           /*Init a GPIO as RTC GPIO. */
                                               
    rtc_gpio_set_direction(gpio_scl, RTC_GPIO_MODE_INPUT_ONLY);         /*RTC GPIO set direction. 
                                                 Configure RTC GPIO direction, such as output only, input only, output and input.*/
    rtc_gpio_deinit(gpio_sda);
    rtc_gpio_set_direction(gpio_sda, RTC_GPIO_MODE_INPUT_ONLY);

    rtc_gpio_deinit(gpio_int);
    rtc_gpio_set_direction(gpio_int, RTC_GPIO_MODE_INPUT_ONLY);    


    esp_err_t err = ulp_load_binary(0, ulp_main_bin_start, (ulp_main_bin_end - ulp_main_bin_start) / sizeof(uint32_t));  /*Load ULP program binary into RTC memory. */
                /*(uint32_t load_addr, const uint8_t *program_binary, size_t program_size)*/
    ESP_ERROR_CHECK(err);                                /*ESP_ERROR_CHECK() macro serves similar purpose as assert, except that 
                                                        it checks esp_err_t value rather than a bool condition. If the argument of 
                                                        ESP_ERROR_CHECK() is not equal ESP_OK, then an error message is printed 
                                                        on the console, and abort() is called.*/


    ulp_set_wakeup_period(0, 1000000);                   /* Set ULP wake up period to 1s */

}
static void print_status()
{
printf("Anomaly in ULP, initiate wakeup for main processor");
}

void app_main()
{

    /*1. wakeup the ulp processor and load the binary
      2. send the main processor  in deep sleep
      3.  */
    esp_sleep_wakeup_cause_t cause = esp_sleep_get_wakeup_cause();      /*check which wakeup source has triggered wakeup from sleep mode.*/
    if (cause != ESP_SLEEP_WAKEUP_ULP) 
    {
        printf("Not ULP wakeup, initializing ULP\n");
        init_ulp_program();
    } 
    else 
    {
    	printf("wakeup by ULP\n");
        //print_status();
    }

    printf("Entering deep sleep\n\n");

    ESP_ERROR_CHECK( esp_sleep_enable_ulp_wakeup() );              /*ULP coprocessor can run while the chip is in sleep mode, and may be
 used to poll sensors, monitor ADC or touch sensor values, and wake up the chip when a specific event is detected. 
ULP coprocessor is part of RTC peripherals power domain, and it runs the program stored in RTC slow memory. 
RTC slow memory will be powered on during sleep if this wakeup mode is requested. RTC peripherals will be 
automatically powered on before ULP coprocessor starts running the program; 
once the program stops running, RTC peripherals are automatically powered down again.
Revisions 0 and 1 of the ESP32 only support this wakeup mode when RTC peripherals are not forced to be powered on 
(i.e. ESP_PD_DOMAIN_RTC_PERIPH should be set to ESP_PD_OPTION_AUTO).
esp_sleep_enable_ulp_wakeup() function can be used to enable this wakeup source.*/

    /* Start the program */
    esp_err_t err = ulp_run((&ulp_entry - RTC_SLOW_MEM) / sizeof(uint32_t)); /*Run the program loaded into RTC memory. */
    ESP_ERROR_CHECK(err);

    esp_deep_sleep_start();
}