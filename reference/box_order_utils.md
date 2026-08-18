# Box-family emission order

Which end of a horizontal box or violin chart a reader starts at is not
something the input schema states, so the two MAIDR bindings disagreed
about it: r-maidr emitted its categories bottom to top and py-maidr top
to bottom, and the same chart was navigated from opposite ends depending
on which one drew it (#187).
