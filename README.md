# GRIPPS

Gnuplot Real-time Interactive Plotting Perl Script

# Synopsis

```
gripps [options] [numStreams]
<command> | perl gripps [options] [numStreams]
```

## Description

Takes input via a command pipe or STDIN.  Input data provides the Y-values to 
plot.  X-axis will be time in seconds as determined by how quickly the input 
is delivering the Y-values to the script.
