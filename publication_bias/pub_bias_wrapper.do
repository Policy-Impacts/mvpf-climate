**** runs the code that estimates publication bias: 
* one note is that this is designed for a PC -- modification for unix shouldn't be too hard tho; happy to chat about that

global here "${github}/publication_bias"

do "${here}/prep_and_run_matlab.do" .98 5 /Applications R2024b

* make the CDF 
do "${here}/cdf_plot.do" 4.9 .98

*make the heuristic visualization 
do "${here}/heuristic_graphs.do" 5 10 4.9 .98

*correct the estimates for input into wrapper

do "${here}/replace_w_corrected.do"
