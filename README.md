# Advent of FPGA Submission

This is my submission for Advent of FGPA 2025. This year I have only completed Day 1.

My solution is modified from the [Hardcaml Template Project](https://github.com/janestreet/hardcaml_template_project) so the dependencies and steps to run are effectively the same.

## Steps to run

* checkout the "solution" branch
* open `test/input.txt`
* copy and paste the entire [Day 1 puzzle input](https://adventofcode.com/2025/day/1/input) into `test/input.txt` and save (necessary because the Advent of Code creator does not want puzzle inputs uploaded elsewhere)
* run `dune build bin/generate.exe @runtest` from the root directory of the repo

## Testing

As in the steps to run I have written a test that will feed the inputs, run the required amount of cycles and then check the result. The test can be run by executing `dune build bin/generate.exe @runtest` from the root directory of the repo. When `input.txt` is updated it checks against the correct answers from the Day 1 challenge.

## The Design

The design is very straightforward. It is a very simple state machine that moves between reading inputs and then updating the combo the indicated number of steps. When it recives an input it parses it into a direction and number of ticks. Then it ticks once per cycle, updating the combo and checking for the "crossed zero while ticking" and "landed on zero when finished ticking" conditions, until there are no more ticks left. The two major components are the input reader and the ticker.

### Input Processor

The input is of a fixed form. `L` or `R` followed by between 1 and 3 numbers. This made it possible to design a very basic string processor.

First we read the first character either `L` or `R`. This determines whether or not we tick left (combo goes down) or tick right (combo goes up). We store this in a register for later use by the ticker.

Then we check if the next input within the ASCII range of the numbers. If it is we convert the ASCII code to an integer by subtracting `0x30` which is the start of the ASCII number range. Then we multiply the existing value of our tick register by 10 then add the number. We repeat this until we find a newline indicating there are no more numbers. This preserves the place value of each digit as they are read in.

Finally when we encounter a newline we convert our ticks to negative if going in the `L` direction or keep it positive if going in the 'R' direction. Then we set the state machine to move onto the ticker.

### Ticker

The ticker starts with a `ticks` value. This can positive or negative. It then moves towards 0, incrementing or decrementing the ticks as appropraite once per clock cycle, until `ticks` becomes zero. While doing this it increments or decrements the combo as approprate once per clock cycle. It checks when the combo is zero during ticking and when the ticks are zero and handles wrapping logic as necessary for the puzzle.

## Reflections

I don't have much experience in hardware so I wasn't able to come up with anything amazing. That said it was very interesting to try out FGPA programming for the first time.

I also found Hardcaml very interesting. The `Always.State_machine` made creating the state machine extremely straight forward and I liked the idea of trying to translate functional patterns to hardware (though I didn't manage to fully take advantage of the expressiveness it provides). It's definitely easier to work with than what I had initially imagined I would need to for FGPAs.

I hope Advent of FPGA runs again next year!
