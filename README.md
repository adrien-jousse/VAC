# ISW Promela model for SPIN

## Files description
- isw.pml: the model for the Intelligent Steering Wheel, composed of two buttons, a light indicator, a mainboard, an access control monitor and an auto drive
- ltl.pml: LTL formulae used for the verification ($\phi$, $\psi$, $\xi$)
- utility.pml: moderately useful functions used accross the model

## Usage
This model has been used with the GUI (ispin) for SPIN. Both can be found [here](https://github.com/nimble-code/Spin).

To get started, go to:
```
cd Spin-Master/optionnal_gui 
```
and run 
```
wish ispin.tcl
```

From the ispin window, open the model (_isw.pml_) then go to the _verification_ tab, and _run_ the verification (both _acceptance cycles_ and _safety_ are fine for our needs).

To specify a LTL formula to verify, check _use claim_ and write the name (_phi_, _psi_, _xi_ or _all_) of a formula to verify it.

Under _Show Error Trapping Options_ please select _**don't stop at errors**_ (for acceptance cycle detection) to continue the model exploration.

If a LTL formula is violated, SPIN's output contains
```
pan:1: assertion violated  <assertion> (at depth <number>)
```
at the beginning of the output log.

For a clearer output, uncheck _report unreachable code_ under _Search mode_.