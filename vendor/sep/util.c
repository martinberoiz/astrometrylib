/*%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
*
* This file is part of SEP
*
* All content except array comparison functions fqcmp() and fqmedian() is
* distributed under an MIT license.
* 
* Copyright 2014 SEP developers
*
* Array comparison functions fqcmp() and fqmedian() are distributed under an
* LGPL license:
* 
* Copyright 1993-2011 Emmanuel Bertin -- IAP/CNRS/UPMC
* Copyright 2014 SEP developers
*
*%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%*/

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "sep.h"
#include "sepcore.h"
#include "compat.h"

#define DETAILSIZE 512

char *sep_version_string = "0.6.0";
static char _errdetail_buffer[DETAILSIZE] = "";

/****************************************************************************/
/* data type conversion mechanics for runtime type conversion */

PIXTYPE convert_dbl(void *ptr)
{
  return *(PIXTYPE*)(double*)ptr;
}

PIXTYPE convert_flt(void *ptr)
{
  return *(PIXTYPE*)(float*)ptr;
}

PIXTYPE convert_int(void *ptr)
{
  return *(PIXTYPE*)(int*)ptr;
}

PIXTYPE convert_byt(void *ptr)
{
  return *(PIXTYPE*)(BYTE*)ptr;
}

/* return the correct converter depending on the datatype code */
int get_converter(int dtype, converter *f, int *size)
{
  int status = RETURN_OK;

  if (dtype == SEP_TFLOAT)
    {
      *f = convert_flt;
      *size = sizeof(float);
    }
  else if (dtype == SEP_TINT)
    {
      *f = convert_int;
      *size = sizeof(int);
    }
  else if (dtype == SEP_TDOUBLE)
    {
      *f = convert_dbl;
      *size = sizeof(double);
    }
  else if (dtype == SEP_TBYTE)
    {
      *f = convert_byt;
      *size = sizeof(BYTE);
    }
  else
    {
      *f = NULL;
      *size = 0;
      status = ILLEGAL_DTYPE;
    }
  return status;
}

/* array conversions */
void convert_array_flt(void *ptr, int n, PIXTYPE *target)
{
  float *source = (float *)ptr;
  int i;
  for (i=0; i<n; i++, source++)
    target[i] = *source;
}

void convert_array_dbl(void *ptr, int n, PIXTYPE *target)
{
  double *source = (double *)ptr;
  int i;
  for (i=0; i<n; i++, source++)
    target[i] = convert_dbl(source);
}

void convert_array_int(void *ptr, int n, PIXTYPE *target)
{
  int *source = (int *)ptr;
  int i;
  for (i=0; i<n; i++, source++)
    target[i] = convert_int(source);
}

void convert_array_byt(void *ptr, int n, PIXTYPE *target)
{
  BYTE *source = (BYTE *)ptr;
  int i;
  for (i=0; i<n; i++, source++)
    target[i] = convert_byt(source);
}

int get_array_converter(int dtype, array_converter *f, int *size)
{
  int status = RETURN_OK;

  if (dtype == SEP_TFLOAT)
    {
      *f = convert_array_flt;
      *size = sizeof(float);
    }
  else if (dtype == SEP_TBYTE)
    {
      *f = convert_array_byt;
      *size = sizeof(BYTE);
    }
  else if (dtype == SEP_TINT)
    {
      *f = convert_array_int;
      *size = sizeof(int);
    }
  else if (dtype == SEP_TDOUBLE)
    {
      *f = convert_array_dbl;
      *size = sizeof(double);
    }
  else
    {
      *f = NULL;
      *size = 0;
      status = ILLEGAL_DTYPE;
    }
  return status;
}


/****************************************************************************/
/* Copy a float array to various sorts of arrays */

void write_array_dbl(float *ptr, int n, void *target)
{
  double *t = (double *)target;
  int i;
  for (i=0; i<n; i++, ptr++)
    t[i] = (double)(*ptr);
}

void write_array_int(float *ptr, int n, void *target)
{
  int *t = (int *)target;
  int i;
  for (i=0; i<n; i++, ptr++)
    t[i] = (int)(*ptr+0.5);
}

/* return the correct writer depending on the datatype code */
int get_array_writer(int dtype, array_writer *f, int *size)
{
  int status = RETURN_OK;

  if (dtype == SEP_TINT)
    {
      *f = write_array_int;
      *size = sizeof(int);
    }
  else if (dtype == SEP_TDOUBLE)
    {
      *f = write_array_dbl;
      *size = sizeof(double);
    }
  else
    {
      *f = NULL;
      *size = 0;
      status = ILLEGAL_DTYPE;
    }
  return status;
}

/* subtract a float array from arrays of various types */

void subtract_array_dbl(float *ptr, int n, void *target)
{
  double *t = (double *)target;
  int i;
  for (i=0; i<n; i++, ptr++)
    t[i] -= (double)(*ptr);
}

void subtract_array_flt(float *ptr, int n, void *target)
{
  float *t = (float *)target;
  int i;
  for (i=0; i<n; i++, ptr++)
    t[i] -= *ptr;
}

void subtract_array_int(float *ptr, int n, void *target)
{
  int *t = (int *)target;
  int i;
  for (i=0; i<n; i++, ptr++)
    t[i] -= (int)(*ptr+0.5);
}

/* return the correct subtractor depending on the datatype code */
int get_array_subtractor(int dtype, array_writer *f, int *size)
{
  int status = RETURN_OK;
  char errtext[80];

  if (dtype == SEP_TFLOAT)
    {
      *f = subtract_array_flt;
      *size = sizeof(float);
    }
  else if (dtype == SEP_TINT)
    {
      *f = subtract_array_int;
      *size = sizeof(int);
    }
  else if (dtype == SEP_TDOUBLE)
    {
      *f = subtract_array_dbl;
      *size = sizeof(double);
    }
  else
    {
      *f = NULL;
      *size = 0;
      status = ILLEGAL_DTYPE;
      sprintf_s(errtext, 80, "in get_array_subtractor(): %d", dtype);
      put_errdetail(errtext, 80);
    }
  return status;
}

/*****************************************************************************/
/* Error messaging */

void sep_get_errmsg(int status, char *errtext, int errsize)
/* Return a short descriptive error message that corresponds to the input
 * error status value.  The message may be up to 60 characters long, plus
 * the terminating null character. */
{
  errtext[0] = '\0';
  switch (status)
    {
    case RETURN_OK:
      strcpy_s(errtext, errsize, "OK - no error");
      break;
    case MEMORY_ALLOC_ERROR:
      strcpy_s(errtext, errsize, "memory allocation");
      break;
    case PIXSTACK_FULL:
      strcpy_s(errtext, errsize, "internal pixel buffer full");
      break;
    case DEBLEND_OVERFLOW:
      strcpy_s(errtext, errsize, "object deblending overflow");
      break;
    case ILLEGAL_DTYPE:
      strcpy_s(errtext, errsize, "dtype not recognized/unsupported");
      break;
    case ILLEGAL_SUBPIX:
      strcpy_s(errtext, errsize, "subpix value must be nonnegative");
      break;
    case NON_ELLIPSE_PARAMS:
      strcpy_s(errtext, errsize, "parameters do not describe ellipse");
      break;
    case ILLEGAL_APER_PARAMS:
      strcpy_s(errtext, errsize, "invalid aperture parameters");
      break;
    case LINE_NOT_IN_BUF:
      strcpy_s(errtext, errsize, "array line out of buffer");
      break;
   case RELTHRESH_NO_NOISE:
      strcpy_s(errtext, errsize, "relative threshold but image has noise_type of NONE");
      break;
    case UNKNOWN_NOISE_TYPE:
      strcpy_s(errtext, errsize, "image has unknown noise_type");
      break;
    default:
       strcpy_s(errtext, errsize, "unknown error status");
       break;
    }
}

void sep_get_errdetail(char *errtext, size_t size)
{
  strcpy_s(errtext, size, _errdetail_buffer);
  memset(_errdetail_buffer, 0, DETAILSIZE);
}

void put_errdetail(const char *errtext, size_t len)
{
   strcpy_s(_errdetail_buffer, DETAILSIZE, errtext);

}

/*****************************************************************************/
/* Array median */

static int fqcmp(const void *p1, const void *p2)
/* Sorting function for floats, used in fqmedian() below.
 * Return value is 1 if *p1>*p2, 0 if *p1==*p2, -1 otherwise */
{
  double f1=*((float *)p1);
  double f2=*((float *)p2);
  return f1>f2? 1 : (f1<f2? -1 : 0);
}

float fqmedian(float *ra, int n)
/* Compute median of an array of floats.
 *
 * WARNING: input data are reordered! */
{
  int dqcmp(const void *p1, const void *p2);
  
  qsort(ra, n, sizeof(float), fqcmp);
  if (n<2)
    return *ra;
  else
    return n&1? ra[n/2] : (ra[n/2-1]+ra[n/2])/2.0f;
}
