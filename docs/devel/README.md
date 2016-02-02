Developer FAQ
========

## How is back compatibility handled?

### What about supporting a span of versions?

Ans:  Spanning more than one version of a component will means a proliferation of test cases, so the recommendation is to be a point in time and not 'this latest version and that slightly older version'.

This will reduce the code test sets to a single configuration (tested in many ways anyways).


### How are features and functionality removed or depreceated?

Ans: When a specific technique or function is removed one should:
#### create a ticket describing the change to be performed
#### depending on how invasive the change is, remove the elements or
#### if desiring a 'sunset' of the feature comment out the dependant lines with:
##### #Deprecated:YYYY-MM-DD:TODO: [remove next release|short phrase of action here]

# Style Guide

## How are file paths as variables referred to -- trailing slash or no trailing slash?
### No trailing slash. /this/is/the/way  /not/this/way/  
