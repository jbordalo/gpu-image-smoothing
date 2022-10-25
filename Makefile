

.PHONY:	all

all:	main cuda

main:	main.c 
	cc -g -o $@ $< 


cuda:	cuda.cu
	nvcc -o $@ $<


.PHONY:	clean
clean:
	rm -f main out.ppm
