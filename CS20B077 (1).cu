
#include <iostream>
#include <cstdio>        // Added for printf() function 
#include <sys/time.h>    // Added to get time of day
#include <cuda.h>
#include <bits/stdc++.h>
#include <fstream>

#define max_N 100000
#define max_P 30
#define BLOCKSIZE 1024

using namespace std;

typedef struct request  //struct for storing requests
{
    int id;
    int centre;
    int facility;
    int newfacility;
    int start;
    int slots;
}req;

//*******************************************

// Write down the kernels here
__global__ void calprefix(req *reqs, int *presum, int R)  //kernel for calculating prefix sum
{
    int tid = threadIdx.x + blockIdx.x * blockDim.x;
    int i = tid;
    if(i<R)
    {
        atomicAdd(&presum[reqs[i].newfacility],1);        
    }
}

__global__ void final(int *presum, req *reqs, int *success, int *succreqs, int N,int *capacity) //kernel for final allocation(finding success and failures)
{
    int tid = threadIdx.x + blockIdx.x * blockDim.x;            //thread id(facility number)
    int k = tid;
    if(k<N)
    {
        int len;                                                //length of requests for a particular facility
        if(k==0){
            len = presum[k];                                    //if facility number is 0 then length is equal to prefix sum of facility number 0   
        }
        else{
            len = presum[k] - presum[k-1];                      //else length is equal to prefix sum of facility number k - prefix sum of facility number k-1
        }
        if(len!=0){
          int l=presum[k]-len;                                  //left index of requests for a particular facility                  
          int r=presum[k]-1;                                    //right index of requests for a particular facility
          int cap=capacity[reqs[l].newfacility];                //capacity of facility
          int slots[25];                                        //array to store slots of facility      
          for(int i=0;i<25;i++){
            slots[i]=cap;
          }
          /*printf("id-%d before ",k);
          for(int i=0;i<25;i++){
            printf("%d ",slots[i]);
          }*/
          int i;
          for(i=l;i<=r;i++){
            int flag=0;
            for(int j=reqs[i].start;j<reqs[i].start+reqs[i].slots;j++){  //checking if slots are available
              if(slots[j]==0){
                flag=1;
                break;
              }
            }
            //printf("hellob-%d",k);
            if(flag==0){
              for(int j=reqs[i].start;j<reqs[i].start+reqs[i].slots;j++){
                slots[j]--;
                //facilityslots[reqs[i].newfacility*max_P+j]+=1;
              }
              //printf("helloa-%d %d\n",k,success[0]);
              atomicAdd(&success[0],1);                                 //incrementing success
              atomicAdd(&succreqs[reqs[i].centre],1);                   //incrementing success for a particular centre
            }
          }
          /*printf("after");
          for(int i=0;i<25;i++){
            printf("%d ",slots[i]);
          }
          printf("\n");*/
        }
    }
}
//***********************************************

//comparator funtion using both newfacility and id
int compare(const void *a, const void *b)                               //comparator function for sorting requests
{
    req *x = (req *)a;
    req *y = (req *)b;
    if(x->newfacility == y->newfacility)                                //if newfacility is same then sort according to id
    {
        return x->id - y->id;
    }
    return x->newfacility - y->newfacility;                             //else sort according to newfacility
}

int main(int argc,char **argv)
{
	// variable declarations...
    int N,*centre,*facility,*capacity,*fac_ids, *succ_reqs, *tot_reqs;
    

    FILE *inputfilepointer;
    
    //File Opening for read
    char *inputfilename = argv[1];
    inputfilepointer    = fopen( inputfilename , "r");

    if ( inputfilepointer == NULL )  {
        printf( "input.txt file failed to open." );
        return 0; 
    }

    fscanf( inputfilepointer, "%d", &N ); // N is number of centres
	
    // Allocate memory on cpu
    centre=(int*)malloc(N * sizeof (int));  // Computer  centre numbers
    facility=(int*)malloc(N * sizeof (int));  // Number of facilities in each computer centre
    fac_ids=(int*)malloc(max_P * N  * sizeof (int));  // Facility room numbers of each computer centre
    capacity=(int*)malloc(max_P * N * sizeof (int));  // stores capacities of each facility for every computer centre 


    int success=0;  // total successful requests
    int fail = 0;   // total failed requests
    tot_reqs = (int *)malloc(N*sizeof(int));   // total requests for each centre
    succ_reqs = (int *)malloc(N*sizeof(int)); // total successful requests for each centre

    // Input the computer centres data
    int k1=0 , k2 = 0;
    for(int i=0;i<N;i++)
    {
      fscanf( inputfilepointer, "%d", &centre[i] );
      fscanf( inputfilepointer, "%d", &facility[i] );
      
      for(int j=0;j<facility[i];j++)
      {
        fscanf( inputfilepointer, "%d", &fac_ids[i*max_P+j] );
        k1++;
      }
      for(int j=0;j<facility[i];j++)
      {
        fscanf( inputfilepointer, "%d", &capacity[i*max_P+j]);
        k2++;     
      }
    }

    // variable declarations
    int *req_id, *req_cen, *req_fac, *req_start, *req_slots;   // Number of slots requested for every request
    
    // Allocate memory on CPU 
	int R;
	fscanf( inputfilepointer, "%d", &R); // Total requests
    req_id = (int *) malloc ( (R) * sizeof (int) );  // Request ids
    req_cen = (int *) malloc ( (R) * sizeof (int) );  // Requested computer centre
    req_fac = (int *) malloc ( (R) * sizeof (int) );  // Requested facility
    req_start = (int *) malloc ( (R) * sizeof (int) );  // Start slot of every request
    req_slots = (int *) malloc ( (R) * sizeof (int) );   // Number of slots requested for every request
    

    //****** by me
    // struct 
    req *reqs = (req *)malloc(R * sizeof(req));         // array of requests
    // Input the user request data
    for(int j = 0; j < R; j++)
    {
       fscanf( inputfilepointer, "%d", &req_id[j]);
       fscanf( inputfilepointer, "%d", &req_cen[j]);
       fscanf( inputfilepointer, "%d", &req_fac[j]);
       fscanf( inputfilepointer, "%d", &req_start[j]);
       fscanf( inputfilepointer, "%d", &req_slots[j]);
       reqs[j].id = req_id[j];
       reqs[j].centre = req_cen[j];
       reqs[j].facility = req_fac[j];
       reqs[j].newfacility = req_cen[j]*max_P+req_fac[j]; // new facility id(current_centre*max_P+facility)
       reqs[j].start = req_start[j];
       reqs[j].slots = req_slots[j];  
       tot_reqs[req_cen[j]]+=1;  
    }
    // sort the requests
    qsort(reqs, R, sizeof(req), compare);                 //sorting requests according to newfacility and id
    /*for(int i=0;i<R;i++){
      printf("%d %d %d %d %d %d\n",reqs[i].id,reqs[i].centre,reqs[i].facility,reqs[i].newfacility,reqs[i].start,reqs[i].slots);
    }
    */
    //*********************************
    //*********************************
    // Call the kernels here
    // Allocate memory on GPU
    int *d_capacity;                                    // stores capacities of each facility for every computer centre
    cudaMalloc(&d_capacity, N*max_P*sizeof(int));
    cudaMemcpy(d_capacity, capacity, N*max_P*sizeof(int), cudaMemcpyHostToDevice);
    int *d_success;                                     // total successful requests
    cudaMalloc(&d_success, sizeof(int));
    cudaMemset(d_success, 0, sizeof(int));
    int *d_succreqs;                                    // total successful requests for each centre
    cudaMalloc(&d_succreqs, N*sizeof(int));
    cudaMemset(d_succreqs, 0, N*sizeof(int));
    int *presum=(int*)malloc(N *max_P* sizeof (int));   // prefix sum of requests for each facility
    int *d_presum;
    cudaMalloc(&d_presum, N*max_P*sizeof(int));
    cudaMemset(d_presum, 0, N*max_P*sizeof(int));
    req *d_reqs;
    cudaMalloc(&d_reqs, R*sizeof(req));
    cudaMemcpy(d_reqs, reqs, R*sizeof(req), cudaMemcpyHostToDevice);
    dim3 grid1((R+1023)/1024,1,1);                                          //grid and block size for kernel call
    dim3 block1(1024,1,1);
    calprefix<<<grid1,block1>>>(d_reqs, d_presum, R);     //calculating request for each facility
    cudaMemcpy(presum, d_presum, N*max_P*sizeof(int), cudaMemcpyDeviceToHost);
    int x=0;
    for(int i=0;i<N*max_P;i++){
        if(i!=0){
            presum[i]+=presum[i-1];                     //calculating prefix sum
        }
    }
    int *d_presum1;
    cudaMalloc(&d_presum1, N*max_P*sizeof(int));
    cudaMemcpy(d_presum1, presum, N*max_P*sizeof(int), cudaMemcpyHostToDevice);
    //remove again
    /*int *facilityslots;
    facilityslots=(int*)malloc((N*max_P*24+1)*sizeof(int));
    */
    //rem
    //int *d_facilityslots;
    /*cudaMalloc(&d_facilityslots, (N*max_P*24+1)*sizeof(int));
    cudaMemset(d_facilityslots, 0, (N*max_P*24+1)*sizeof(int));
    */
    dim3 grid2((N*max_P+1023)/1024,1,1);                                          //grid and block size for kernel call
    dim3 block2(1024,1,1);
    final<<<grid2,block2>>>(d_presum1,d_reqs,d_success,d_succreqs,N*max_P,d_capacity);  //final kernel call(success calculation) parallelism on facilities
    //cudaMemcpy(facilityslots, d_facilityslots, (N*max_P*24+1)*sizeof(int), cudaMemcpyDeviceToHost);
    cudaMemcpy(&success, d_success, sizeof(int), cudaMemcpyDeviceToHost);
    cudaMemcpy(succ_reqs, d_succreqs, N*sizeof(int), cudaMemcpyDeviceToHost);
    fail=R-success;
    /*for(int i=0;i<N;i++){
      printf("center-%d\n",i);
      for(int j=0;j<max_P;j++){
        printf("fac-%d ",j);
        for(int k=1;k<=24;k++){
          printf("%d ",facilityslots[i*max_P*24+j*24+k]);
        }
        printf("\n");
      }
    }
    */
    //********************************
    /*printf("success-%d",success);
    for(int i=0;i<N;i++){
      printf("successcenter%d-%d",i,succ_reqs[i]);
    }
    */

    // Output
    char *outputfilename = argv[2]; 
    FILE *outputfilepointer;
    outputfilepointer = fopen(outputfilename,"w");

    fprintf( outputfilepointer, "%d %d\n", success, fail);
    //printf("**********************************\n");
    //printf("%d %d\n", success, fail);
    for(int j = 0; j < N; j++)
    {
        fprintf( outputfilepointer, "%d %d\n", succ_reqs[j], tot_reqs[j]-succ_reqs[j]);
        //printf("%d %d\n", succ_reqs[j], tot_reqs[j]-succ_reqs[j]);
    }
    /*for(int i=0;i<N;i++){
      fprintf( outputfilepointer, "presum-Center %d\n",i);
      for(int j=0;j<max_P;j++){
        fprintf( outputfilepointer, "%d ",presum[i*max_P+j]);
      }
      fprintf( outputfilepointer, "\n");
    }
    */
    fclose( inputfilepointer );
    fclose( outputfilepointer );
    cudaDeviceSynchronize();
	return 0;
}