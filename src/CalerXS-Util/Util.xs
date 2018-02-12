#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <time.h>
#include <stdio.h>

MODULE = CalerXS::Util		PACKAGE = CalerXS::Util		

int
get_init_offset()
CODE:
  time_t t;
  time(&t);
  struct tm *tm = localtime(&t);
  printf("wsdfasdfsadf\n");
  RETVAL = tm->tm_sec + tm->tm_min * 60;
OUTPUT:
  RETVAL
