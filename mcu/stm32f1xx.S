#include "../config.h"
#include "memmap.h"

#if (DFU_BOOTSTRAP_GPIO == GPIOA)
    #define BOOTSTRAP_RCC   0x004
#elif (DFU_BOOTSTRAP_GPIO == GPIOB)
    #define BOOTSTRAP_RCC   0x008
#elif (DFU_BOOTSTRAP_GPIO == GPIOC)
    #define BOOTSTRAP_RCC   0x010
#elif (DFU_BOOTSTRAP_GPIO == GPIOD)
    #define BOOTSTRAP_RCC   0x020
#elif (DFU_BOOTSTRAP_GPIO == GPIOE)
    #define BOOTSTRAP_RCC   0x040
#elif (DFU_BOOTSTRAP_GPIO == GPIOF)
    #define BOOTSTRAP_RCC   0x080
#elif (DFU_BOOTSTRAP_GPIO == GPIOE)
    #define BOOTSTRAP_RCC   0x100

#else
    #error "Bootstrap port undefined"
#endif


    .syntax unified
    .cpu cortex-m3
    .fpu softvfp
    .thumb

    .section .isr_vector
    .align 2
    .globl __isr_vector
__isr_vector:
    .long   __stack                     /* 0x000 Reset MSP value */
    .long   Reset_Handler               /* 0x004 Reset */
    .long   NMI_Handler                 /* 0x008 NMI */

    .word   HardFault_Handler           /* 0x00C All class of fault */
    .word   MemManage_Handler           /* 0x010 Memory management */
    .word   BusFault_Handler            /* 0x014 Pre-fetch fault, memory access fault */
    .word   UsageFault_Handler          /* 0x018 Undefined instruction or illegal state */
    .word   0                           /* 0x01C Reserved */
    .word   0                           /* 0x020 Reserved */
    .word   0                           /* 0x024 Reserved */
    .word   0                           /* 0x028 Reserved */
    .word   SVC_Handler                 /* 0x02C System service call via SWI instruction */
    .word   DebugMon_Handler            /* 0x030 Debug monitor */
    .word   0                           /* 0x034 Reserved */
    .word   PendSV_Handler
    .word   SysTick_Handler
#if !defined(DFU_NO_EXTINT)
/* STM32 Peripherals interrupts */
    .word WWDG_IRQHandler
    .word PVD_IRQHandler
    .word TAMPER_IRQHandler
    .word RTC_IRQHandler
    .word FLASH_IRQHandler
    .word RCC_IRQHandler
    .word EXTI0_IRQHandler
    .word EXTI1_IRQHandler
    .word EXTI2_IRQHandler
    .word EXTI3_IRQHandler
    .word EXTI4_IRQHandler
    .word DMA1_Channel1_IRQHandler
    .word DMA1_Channel2_IRQHandler
    .word DMA1_Channel3_IRQHandler
    .word DMA1_Channel4_IRQHandler
    .word DMA1_Channel5_IRQHandler
    .word DMA1_Channel6_IRQHandler
    .word DMA1_Channel7_IRQHandler
    .word ADC1_2_IRQHandler
    .word USB_HP_CAN1_TX_IRQHandler
    .word USB_LP_CAN1_RX0_IRQHandler
    .word CAN1_RX1_IRQHandler
    .word CAN1_SCE_IRQHandler
    .word EXTI9_5_IRQHandler
    .word TIM1_BRK_IRQHandler
    .word TIM1_UP_IRQHandler
    .word TIM1_TRG_COM_IRQHandler
    .word TIM1_CC_IRQHandler
    .word TIM2_IRQHandler
    .word TIM3_IRQHandler
    .word TIM4_IRQHandler
    .word I2C1_EV_IRQHandler
    .word I2C1_ER_IRQHandler
    .word I2C2_EV_IRQHandler
    .word I2C2_ER_IRQHandler
    .word SPI1_IRQHandler
    .word SPI2_IRQHandler
    .word USART1_IRQHandler
    .word USART2_IRQHandler
    .word USART3_IRQHandler
    .word EXTI15_10_IRQHandler
    .word RTC_Alarm_IRQHandler
    .word USBWakeUp_IRQHandler
    .word 0
    .word 0
    .word 0
    .word 0
    .word 0
    .word 0
    .word 0

#endif
    .size __isr_vector, . - __isr_vector



    .section .text
    .thumb_func
    .globl Reset_Handler
    .type Reset_Handler, %function
Reset_Handler:
    ldr     r1, =#DFU_BOOTKEY_ADDR
    ldr     r2, =#DFU_BOOTKEY
    movs    r3, #0x00
    ldr     r0, [r1]
    str     r3, [r1]
    cmp     r0, r2
    beq     .L_start_boot
/* checking bootstrap pin */
    ldr     r0, =#RCC_BASE
    ldr     r1, =#DFU_BOOTSTRAP_GPIO
    movs    r2, #BOOTSTRAP_RCC
    strh    r2, [r0, #RCC_APB2ENR]
    movs    r2, #0x08
    ldr     r3, [r1, #GPIO_CRL]
    bfi     r3, r2, #(DFU_BOOTSTRAP_PIN * 4), 4
    str     r3, [r1, #GPIO_CRL]
    movs    r2, #0x01
    lsls    r2, #DFU_BOOTSTRAP_PIN
    str     r2, [r1, #GPIO_BSRR]
    movs    r4, #0x08
.L_scan_bootstrap:
    ldr     r2, [r1, #GPIO_IDR]
    lsrs    r2, #(DFU_BOOTSTRAP_PIN + 1)    //Pin -> CF
    sbcs    r3, r3
    movs    r2, #0x01
    orrs    r2, r3
    adds    r4, r2
    beq     .L_reset_gpio
    cmp     r4, #0x10
    bne     .L_scan_bootstrap
.L_reset_gpio:
    movs    r2, #BOOTSTRAP_RCC
    strb    r2, [r0, #RCC_APB2RSTR]
    movs    r2, #0x00
    strh    r2, [r0, #RCC_APB2RSTR]
    strh    r2, [r0, #RCC_APB2ENR]
    cbz     r4, .L_start_boot

/* jump to user section */
    ldr     r0, =__app_start
    ldr     r1, [r0, #0x00]     //load new MSP
/* check if the application is erased */
    ldr     r2, =0xFFFFFFFF
    teq     r1, r2
    beq     .L_start_boot
    msr     MSP, r1             //set MSP
    ldr     r1, =#SCB
    str     r0, [r1, #SCB_VTOR] //set VTOR
    ldr     r3, [r0, #0x04]     //load reet vector
    bx      r3                  //jump to user_app

/* jump to main app */
.L_start_boot:
/* do copy data */
    ldr     r1, =__etext
    ldr     r2, =__data_start__
    ldr     r3, =__data_end__
.L_copy_data:
    cmp     r2, r3
    bcs     .L_clear_bss
    ldr     r0, [r1], #0x04
    str     r0, [r2], #0x04
    b       .L_copy_data
.L_clear_bss:
    movs    r0, #0x00
    ldr     r2, =__bss_start__
    ldr     r3, =__bss_end__
.L_clear_bss_loop:
    str     r0, [r2], #0x04
    cmp     r3, r2
    bcs     .L_clear_bss_loop

/* Setup clock 48MHz HSI PLL for USB use
 * All registers means their reset values
 */
/* Set latency 1 and enable prefetch */
    ldr     r0, =#FLASH_R_BASE
    movs    r1, #0x11
    str     r1, [r0, #FLASH_ACR]
/* set PLL 12/2 HSI */
    ldr     r3, =#RCC_BASE
    ldr     r2, =0x00680400
    str     r2, [r3, #RCC_CFGR]
/* enable PLL */
    movs    r1, #0x01
    strb    r1, [r3, #RCC_CR + 3]   //PLL ON
.L_wait_PLL:
    ldrb    r2, [r3, #RCC_CR + 3]
    lsrs    r2, #2                  //PLLRDYF -> CF
    bcc     .L_wait_PLL
/* set SW[1:0] to PLL */
    movs    r1, #0x02
    strb    r1, [r3, #RCC_CFGR + 0]

    bl      main
    .size Reset_Handler, .-Reset_Handler


    .thumb_func
    .type _default_handler, %function
_default_handler:
    b   .
    .size _default_handler, . - _default_handler


    .pool

    .macro def_irq_handler handler_name
    .weak \handler_name
    .thumb_set \handler_name, _default_handler
    .endm

    def_irq_handler NMI_Handler
    def_irq_handler HardFault_Handler
    def_irq_handler MemManage_Handler
    def_irq_handler BusFault_Handler
    def_irq_handler UsageFault_Handler
    def_irq_handler SVC_Handler
    def_irq_handler DebugMon_Handler
    def_irq_handler PendSV_Handler
    def_irq_handler SysTick_Handler
    def_irq_handler WWDG_IRQHandler
    def_irq_handler PVD_IRQHandler
    def_irq_handler TAMPER_IRQHandler
    def_irq_handler RTC_IRQHandler
    def_irq_handler FLASH_IRQHandler
    def_irq_handler RCC_IRQHandler
    def_irq_handler EXTI0_IRQHandler
    def_irq_handler EXTI1_IRQHandler
    def_irq_handler EXTI2_IRQHandler
    def_irq_handler EXTI3_IRQHandler
    def_irq_handler EXTI4_IRQHandler
    def_irq_handler DMA1_Channel1_IRQHandler
    def_irq_handler DMA1_Channel2_IRQHandler
    def_irq_handler DMA1_Channel3_IRQHandler
    def_irq_handler DMA1_Channel4_IRQHandler
    def_irq_handler DMA1_Channel5_IRQHandler
    def_irq_handler DMA1_Channel6_IRQHandler
    def_irq_handler DMA1_Channel7_IRQHandler
    def_irq_handler ADC1_2_IRQHandler
    def_irq_handler USB_HP_CAN1_TX_IRQHandler
    def_irq_handler USB_LP_CAN1_RX0_IRQHandler
    def_irq_handler CAN1_RX1_IRQHandler
    def_irq_handler CAN1_SCE_IRQHandler
    def_irq_handler EXTI9_5_IRQHandler
    def_irq_handler TIM1_BRK_IRQHandler
    def_irq_handler TIM1_UP_IRQHandler
    def_irq_handler TIM1_TRG_COM_IRQHandler
    def_irq_handler TIM1_CC_IRQHandler
    def_irq_handler TIM2_IRQHandler
    def_irq_handler TIM3_IRQHandler
    def_irq_handler TIM4_IRQHandler
    def_irq_handler I2C1_EV_IRQHandler
    def_irq_handler I2C1_ER_IRQHandler
    def_irq_handler I2C2_EV_IRQHandler
    def_irq_handler I2C2_ER_IRQHandler
    def_irq_handler SPI1_IRQHandler
    def_irq_handler SPI2_IRQHandler
    def_irq_handler USART1_IRQHandler
    def_irq_handler USART2_IRQHandler
    def_irq_handler USART3_IRQHandler
    def_irq_handler EXTI15_10_IRQHandler
    def_irq_handler RTC_Alarm_IRQHandler
    def_irq_handler USBWakeUp_IRQHandler
