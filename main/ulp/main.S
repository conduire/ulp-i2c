#include "soc/rtc_cntl_reg.h"
#include "soc/rtc_io_reg.h"
#include "soc/soc_ulp.h"
#include "soc/rtc_i2c_reg.h"

.set MPU6050_RA_GYRO_CONFIG,             0x1B
.set MPU6050_ACCEL_CONFIG   ,            0x1C

.set MPU6050_ACCEL_XOUT_H,               0x3B
.set MPU6050_ACCEL_XOUT_L ,              0x3C
.set MPU6050_ACCEL_YOUT_H  ,             0x3D
.set MPU6050_ACCEL_YOUT_L   ,            0x3E
.set MPU6050_ACCEL_ZOUT_H    ,           0x3F
.set MPU6050_ACCEL_ZOUT_L     ,          0x40

.set MPU6050_RA_INT_STATUS     ,  0x3A
.set MPU6050_RA_INT_ENABLE         ,   0x38
.set MPU6050_RA_SIGNAL_PATH_RESET   , 0x68
.set MPU6050_RA_PWR_MGMT_1             , 0x6B
.set MPU6050_RA_PWR_MGMT_2         ,     0x6C
.set MPU6050_RA_ACCEL_CONFIG       ,     0x1C
.set MPU6050_RA_INT_PIN_CFG        ,     0x37
.set MPU6050_RA_MOT_THR          ,       0x1F
.set MPU6050_RA_MOT_DUR           ,      0x20
.set sleep_reg, 0    /*sleep_reg – 0..4, selects one of SENS_ULP_CP_SLEEP_CYCx_REG registers*/

    

    .text
    .global entry

    entry: /*1. configure to use I2C_RD and I2C_WR*/
            //.macro RTC_I2C_CONFIG
            /*1. Set the low and high SCL half-periods by using RTC_I2C_SCL_LOW_PERIOD_REG and RTC_I2C_SCL_HIGH_PERIOD_REG in RTC_FAST_CLK cycles 
            (e.g. RTC_I2C_SCL_LOW_PERIOD=40, RTC_I2C_SCL_HIGH_PERIOD=40 for 100 kHz frequency).*/
            WRITE_RTC_REG(RTC_I2C_SCL_LOW_PERIOD_REG,RTC_I2C_SCL_LOW_PERIOD_S,8,0x28)
            WRITE_RTC_REG(RTC_I2C_SCL_HIGH_PERIOD_REG,RTC_I2C_SCL_HIGH_PERIOD_S,8,0x28)

            /*2. Set the number of cycles between the SDA switch and the falling edge of SCL by using RTC_I2C_SDA_DUTY_REG in RTC_FAST_CLK (e.g. RTC_I2C_SDA_DUTY=16).*/
            WRITE_RTC_REG(RTC_I2C_SDA_DUTY_REG,RTC_I2C_SCL_HIGH_PERIOD_S,8,0x10)

            /*3. Set the waiting time after the START condition by using RTC_I2C_SCL_START_PERIOD_REG (e.g. RTC_I2C_SCL_START_PERIOD=30).*/
            WRITE_RTC_REG(RTC_I2C_SCL_START_PERIOD_REG,RTC_I2C_SCL_START_PERIOD_S,8,0x1E)

            /*4. Set the waiting time before the END condition by using RTC_I2C_SCL_STOP_PERIOD_REG (e.g. RTC_I2C_SCL_STOP_PERIOD=44).*/
            WRITE_RTC_REG(RTC_I2C_SCL_STOP_PERIOD_REG,RTC_I2C_SCL_STOP_PERIOD_S,8,0x2C)

            /*5. Set the transaction timeout by using RTC_I2C_TIMEOUT_REG (e.g. RTC_I2C_TIMEOUT=200).*/
            WRITE_RTC_REG(RTC_I2C_TIMEOUT_REG,RTC_I2C_TIMEOUT_S,8,0xC8)

            /*6. Enable the master mode (set the RTC_I2C_MS_MODE bit in RTC_I2C_CTRL_REG).*/
            WRITE_RTC_REG(RTC_I2C_CTRL_REG,RTC_I2C_MS_MODE,1,1)

            /*7. Write the address(es) of external slave(s) to SENS_I2C_SLAVE_ADDRn (n: 0-7). 
            Up to eight slave addresses can be pre-programmed this way. One of these addresses 
            can then be selected for each transaction as part of the ULP I²C instruction.*/
            WRITE_RTC_REG(SENS_I2C_SLAVE_ADDR0,RTC_I2C_SLAVE_ADDR_S,8,0x68)
            Jump mpu_config

mpu_config: /*1.When bit1 is set to 1, it resets the accelerometer analog and digital signal paths. 
               write 00000010 i.e. 0x02 to the I2C address*/
            I2C_WR MPU6050_RA_SIGNAL_PATH_RESET,0x02,7,0,0
            /*2. Initialize
                xxxxx001 for PLL with X axis gyroscope reference
                x0xxxxxx for disabling the sleep mode    
                00000001 i.e. 0x01*/
            I2C_WR MPU6050_RA_PWR_MGMT_1,0x01,7,0,0
                /*gyro config*/
            I2C_WR MPU6050_RA_GYRO_CONFIG,0x00,7,0,0
                /*accel config*/
            I2C_WR MPU6050_ACCEL_CONFIG,0x00,7,0,0

            /*3. Enable interrupt generation*/
            I2C_WR MPU6050_RA_INT_ENABLE,0x40,7,0,0
            
            /*4. xxxx0xxx Interuppts are cleared only by reading INT_STATUS
                 0xxxxxxx interrupt mode on active high level
                 x0xxxxxx interrupt is configured as PUSH PULL
                 xx0xxxxx interrupt latch mode is set to 50us pulse*/
            I2C_WR MPU6050_RA_INT_PIN_CFG,0x00,7,0,0

            /*5. Set motion detection event acceleration threshold 00000010 i.e. 0x02
                the threshold to detect motion above 0.5m/s2 = 51.02mg ~=64mg = 2 changes in LSB (LSB = 32mg)*/
            I2C_WR MPU6050_RA_MOT_THR,0x02,7,0,0

            /*6. Set the motion detection duration threshold value*/
            I2C_WR MPU6050_RA_MOT_DUR,0xff,7,0,0

            /*7. set sleep mode status  x0xxxxxx
                 set cycle to 1 when sleep is disabled xx1xxxxx
                 temperature sensor disabled xxxx0xxx*/
            I2C_WR MPU6050_RA_PWR_MGMT_1,0x20

            /*8. x,y,z gyro is disabled by setting to 1  == xxxxx111
                Set wake frequency in Accel-Only Low Power Mode. ==00xxxxxx 
                00000111*/
            I2C_WR MPU6050_RA_PWR_MGMT_2,0x07,7,0,0
            Jump chk_int

chk_int:   I2C_RD MPU6050_RA_INT_STATUS,7,0,0   //read whether an interrupt has been raised or not
           JUMPR Wake_main,1,GE
           Jump ULP_sleep



              
    //.global ulp_sleep
ULP_sleep:  sleep sleep_reg
                Halt
    //.global Wake_main
Wake_main:  /*RTC control can only wakeup main processor if 
                    RTC_CNTL_RDY_FOR_WAKEUP bit =1 (set) of RTC_CNTL_LOW_POWER_ST_REG register*/
                READ_RTC_FIELD(RTC_CNTL_LOW_POWER_ST_REG, RTC_CNTL_RDY_FOR_WAKEUP)
                Jump Wake_main, eq      /*Jump to Wake_main until the RTC_CNTL_RDY_FOR_WAKEUP bit is set*/
                Wake         /*interrupt from ULP to RTC controller to wake up main processor if SoC is in deep sleep mode*/
                
                WRITE_RTC_FIELD(RTC_CNTL_STATE0_REG, RTC_CNTL_ULP_CP_SLP_TIMER_EN, 0)     /* Set RTC_CNTL_ULP_CP_SLP_TIMER_EN field of RTC_CNTL_STATE0_REG to 0  
                   REG_WR 0x006, 24, 24, 0                    Stop ULP timer (clear RTC_CNTL_ULP_CP_SLP_TIMER_EN )*/
                Halt     /*ULP will not run again until started by the main program.*/



                
                        
                