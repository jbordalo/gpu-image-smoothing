/*
 * lab3 CAD 2021/2022 FCT/UNL
 * vad
 */
#include <stdlib.h>
#include <stdio.h>
#include <assert.h>
#include <time.h>
#include <ctype.h>
#include <string.h>
#include <cuda.h>
#include "vsize.h"


/* read_ppm - read a PPM image ascii file
 *   returns pointer to data, dimensions and max colors (from PPM header)
 *   data format: sequence of width x height of 3 ints for R,G and B
 *   aborts on errors
 */
void read_ppm(FILE *f, int **img, int *width, int *height, int *maxcolors) {
    int count=0;
    char ppm[10];
    int c;
    // header
    while ( (c = fgetc(f))!=EOF && count<4 ) {
        if (isspace(c)) continue;
        if (c=='#') {
            while (fgetc(f) != '\n')
                ;
            continue;
        }
        ungetc(c,f);
        switch (count) {
            case 0: count += fscanf(f, "%2s", ppm); break;
            case 1: count += fscanf(f, "%d%d%d", width, height, maxcolors); break;
            case 2: count += fscanf(f, "%d%d", height, maxcolors); break;
            case 3: count += fscanf(f, "%d", maxcolors);
        }
    }
    assert(c!=EOF);
    assert(strcmp("P3", ppm)==0);
    // data
    int *data= *img = (int*)malloc(3*(*width)*(*height)*sizeof(int));
    assert(img!=NULL);
    int r,g,b, pos=0;
    while ( fscanf(f,"%d%d%d", &r, &g, &b)==3) {
        data[pos++] = r;
        data[pos++] = g;
        data[pos++] = b;
    }
    assert(pos==3*(*width)*(*height));
}


/* write_ppm - write a PPM image ascii file
 */
void write_ppm(FILE *f, int *img, int width, int height, int maxcolors) {
    // header
    fprintf(f, "P3\n%d %d %d\n", width, height, maxcolors);
    // data
    for (int l = 0; l < height; l++) {
        for (int c = 0; c < width; c++) {
            int p = 3 * (l * width + c);
            fprintf(f, "%d %d %d  ", img[p], img[p + 1], img[p + 2]);
        }
        fputc('\n',f);
    }
}


/* printImg - print to screen the content of img
 */
void printImg(int imgh, int imgw, const int *img) {
    for (int j=0; j < imgh; j++) {
        for (int i=0; i<imgw; i++) {
            int x = 3*(i+j*imgw);
            printf("%d,%d,%d  ", img[x], img[x+1], img[x+2]);
        }
        putchar('\n');
    }
}

__global__ void averageImg(int*out, int*img, int width, int height) {
    int line = blockIdx.x*blockDim.x+threadIdx.x;
    int col = blockIdx.y*blockDim.y+threadIdx.y;

    int r=0,g=0,b=0, n=0;
    for (int l=line-1; l<line+2 && l<height; l++)
        for (int c=col-1; c<col+2 && c<width; c++)
            if (l>=0 && c>=0) {
                int idx = 3*(l*width+c);
                r+=img[idx]; g+=img[idx+1]; b+=img[idx+2];
                n++;
            }
    int idx = 3*(line*width+col);
    out[idx]=r/n;
    out[idx+1]=g/n;
    out[idx+2]=b/n;
}


int main(int argc, char *argv[]) {
    int imgh, imgw, imgc;
    int *img;
    if (argc!=2) {
        fprintf(stderr,"usage: %s img.ppm\n", argv[0]);
        return EXIT_FAILURE;
    }
	FILE *f=fopen(argv[1],"r");
    if (f==NULL) {
        fprintf(stderr,"can't read file %s\n", argv[1]);
        return EXIT_FAILURE;
    }

    read_ppm(f, &img, &imgw, &imgh, &imgc);
	printf("PPM image %dx%dx%d\n", imgw, imgh, imgc);
//    printImg(imgh, imgw, img);

    dim3 dimBlock(NTHREADS, NTHREADS);
    dim3 dimGrid((imgw+dimBlock.x-1)/dimBlock.x, (imgh+dimBlock.y-1)/dimBlock.y);

    int *out = (int*)malloc(3*imgw*imgh*sizeof(int));
    assert(out!=NULL);

    int *img_cuda;
    int *out_cuda;
    cudaMalloc(&img_cuda, 3*imgw*imgh*sizeof(int));
    cudaMalloc(&out_cuda, 3*imgw*imgh*sizeof(int));
    if ( img_cuda==NULL || out_cuda==NULL ) {
        fprintf(stderr,"No GPU mem!\n");
        return EXIT_FAILURE;
    }
    cudaMemcpy(img_cuda, img, 3*imgw*imgh*sizeof(int), cudaMemcpyHostToDevice);

    clock_t t = clock();

    averageImg<<<dimGrid, dimBlock>>>(out_cuda, img_cuda, imgw, imgh);

    t = clock()-t;
    printf("time %f ms\n", t/(double)(CLOCKS_PER_SEC/1000));

    cudaMemcpy(out, out_cuda, 3*imgh*imgw*sizeof(int), cudaMemcpyDeviceToHost);

    //printImg(imgh, imgw, out);
    FILE *g=fopen("out_cuda.ppm", "w");
    write_ppm(g, out, imgw, imgh, imgc);
    fclose(g);
    return EXIT_SUCCESS;
}
