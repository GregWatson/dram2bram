Packets arrive from DRAM in 64B words - the last word of a packet will have 1-64B valid.
Pack all data together on byte boundaries and write new 64B words out to BRAM.
Always immediately write the current data to BRAM except when nothing has changed.
