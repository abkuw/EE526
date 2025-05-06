simSetSimulator "-vcssv" -exec \
           "/home/akumar08/EE526/STA/build/sim-rtl-rundir/simv" -args
debImport "-full64" "-dbdir" \
          "/home/akumar08/EE526/STA/build/sim-rtl-rundir/simv.daidir"
debLoadSimResult /home/akumar08/EE526/STA/build/sim-rtl-rundir/waveform.fsdb
wvCreateWindow
