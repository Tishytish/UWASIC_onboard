<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works
The spi peripheral receives commands and data and stores them in some register values. These register values pass them as input to PWM peripheral which generates PWM signals. The PWNM signals are passed as output to be used for tiny tapeout

## How to test
The project can be developed and tested using VS Code. Push changes to GitHub to have the CI system automatically run the Cocotb tests. Alternatively, the tests can be run locally using the appropriate development environment and Cocotb.

## External hardware
No external hardware is required for testing the project. The design is simulated using Cocotb and the Tiny Tapeout environment.



