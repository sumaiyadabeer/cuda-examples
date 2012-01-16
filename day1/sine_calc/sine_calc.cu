__constant__ float PI_NUMBER;

// The kernel to be executed in many threads
__global__ void sine_kernel ( float Period, float * result )
{
    // Global thread index
    // ...
    int idx = threadIdx.x + blockIdx.x * blockDim.x;
	
    // Do the calculations, corresponding to the thread. Use PI_NUMBER constant!
    // ...
    result[idx] = sinf(2.0f * PI_NUMBER / Period * (float) idx);
}

#include <stdio.h>

int sine_device( float Period, size_t n, float *result )
{
  int nb = n * sizeof ( float );
  float * resultDev = NULL;

  // Allocate memory on GPU
  cudaError_t cuerr = cudaMalloc ( (void**)&resultDev, nb );


    // Send PI number to constant memory PI_NUMBER
    // cuerr = cudaMemcpyToSymbol (...
    float pi_number = (float)M_PI;
    cuerr = cudaMemcpyToSymbol ( PI_NUMBER, &pi_number, sizeof(float), 0,  cudaMemcpyHostToDevice );

    
    // Set up the kernel launch configuration for n threads 
    // (note BLOCK_SIZE is a pre-defined macro value!)
    dim3 threads = dim3(BLOCK_SIZE, 1);
    dim3 blocks  = dim3(n / BLOCK_SIZE, 1);

    // Launch the kernel using the configuration set up before
    // ...    
    // Copy input data from host to GPU global memory.
    sine_kernel<<<blocks, threads>>> (Period, resultDev);
    cuerr = cudaGetLastError();

    // Wait the kernel to be finished (cudaDeviceSynchronize)
    // ...
    cuerr = cudaDeviceSynchronize();

    // Copy the results back to CPU memory
    // cuerr = cudaMemcpy (...
    cuerr = cudaMemcpy ( result, resultDev, nb, cudaMemcpyDeviceToHost );

    // Free GPU memory
    // cudaFree (...
    cudaFree ( resultDev );

    return 0;
}

#include <malloc.h>
#include <stdlib.h>

float original_function(int i, float Period) {
  return sinf(2.0f * float(M_PI) / Period * float(i));
} 

int main ( int argc, char* argv[] )
{
    if (argc != 2)
    {
        printf("Usage: %s <n>\n", argv[0]);
        printf("Where n must be a multiplier of %d\n", BLOCK_SIZE);
        return 0;
    }

    int n = atoi(argv[1]), nb = n * sizeof(float);
    printf("n = %d\n", n);
    if (n <= 0)
    {
        fprintf(stderr, "Invalid n: %d, must be positive\n", n);
        return 1;
    }
    if (n % BLOCK_SIZE)
    {
        fprintf(stderr, "Invalid n: %d, must be a multiplier of %d\n",
            n, BLOCK_SIZE);
        return 1;
    }

    float Period = 256.0f;

    float * result = (float*)malloc(nb);

    int status = sine_device (Period, n, result);
    if (status) return status;

    int imaxdiff = 0;
    float maxdiff = 0.0f;
    float maxdiff_good = 0.0f;
    float maxdiff_bad = 0.0f;
    for (int i = 0; i < n; i++)
    {
        float gold = original_function(i, Period); 
        float diff = result[i] / gold;
        if (diff != diff) diff = 0; else diff = 1.0 - diff;
        if (diff > maxdiff)
        {
            maxdiff = diff;
            imaxdiff = i;
            maxdiff_good = gold;
            maxdiff_bad = result[i];
        }
    }
    printf("Max diff = %f% @ i = %d: %f != %f\n",
        maxdiff * 100, imaxdiff, maxdiff_bad, maxdiff_good);
    return 0;
}

