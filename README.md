# Nixie Tube Clock

To implement this project locally, you'll need:

- Atmel Studio (>=6.2) (.atsln, .asm)
- Autodesk Eagle (.sch)
- LTSpice (.asc)

## Overview

This project contains both the schematics and software for creating a nixie tube alarm clock. The clock is driven by an Atmel Atmega16a as the main MCU, and two Attiny85's; one used as an external timer for the clock and the other used to generate the input signal for the boost converter.

The system is separated into two sections: the high voltage and low voltage sections. The high voltage side contains the nixie tubes and a boost converter, which takes in 5V as input and ramps up the voltage to ~180V, which is the minimum firing voltage of the IN-14 nixies used for display. The low voltage side contains the Atmega16a and Attiny85, which drive a piezoelectric buzzer for the alarm, and accept input from three pushbuttons: DEC, SET/RST, INC. These buttons are used for different functions depending on the state of the system, but are mostly for decrementing the time, setting/resetting the time, and incrementing the time, respectively.

The two sections are joined together with optocouplers and a K155ID1 BCD To Decimal High Voltage Driver and 6 LTV-852 optocouplers. The nixies are multiplexed using the optocouplers, and the BCD displays values are routed through the K155ID1. This was done since the K155ID1 chip has long since been discontinued and they're not all that cheap nowadays. You can generally buy them in a pack of 6, but it's always good to have extra parts when making something, so the multiplexed option means smoking one of these isn't catastrophic.

## Project Structure

The `src/` folder contains three Atmel studio projects:

- **BOOST_CONVERTER_CONTROLLER**: Code for the Attiny85 denoted `PWM` in the schematic, generates a pulse wave that controls the power transistor of the boost converter. The duty cycle of the pulse wave generated controls how high the boost converter's output voltage will be.
- **CLOCK_TIMER**: Code for the Attiny85 denoted `TMR` in the schematic, generates a pulse every second that's consumed by the Atmega16a to increment the current time. An LM555 as the timer (or even the Atmega16a's internal timer) could be substituted here. My intention is to make a future revision with a more elegant solution for the timer.
- **DIVERGENCE_CLOCK**: Code for the Atmega16a denoted `IC1` in the schematic, this is the main program that controls everything else on the clock. It accepts input from the buttons, controls the buzzer, and outputs the display values for the current time to the nixie tubes.

The `schematics/` folder contains two schematics:

- **BOOST_CONVERTER.asc**: This is an LTSpice schematic for the boost converter, which can be used to simulate the circuit with different configurations. It already contains the configuration I used.
- **nixie_clock.sch** This is the main schematic for this project, containing all the components (including the boost converter).

It also contains a `libraries/` folder which is explained in further detail in the next section.

## Included Eagle Libraries

The **nixie_clock.sch** schematic needs some custom libraries, which are included in the `schematics/libraries`. These are mostly for the nixie tubes, which aren't included in the Eagle standard library. These also include the pad spacing, so this schematic can (and has) been used to generate a PCB in Eagle.

To add them in Eagle, simply copy them into the `~/Eagle/libraries` folder, which gets created when you install Eagle.

**Disclaimer**: I _don't_ own these libraries, but I did have to make some modifications to them in order to get the spacing correct for the PCB, so I've included them here in this repository.
