#ifndef __MEM_DEFINE_H_INCLUDED__
#define __MEM_DEFINE_H_INCLUDED__
#include <stdlib.h>
#	define MEM_ALLOC( x) malloc( x)
#	define MEM_FREE( x)  free( x)
#	define MEM_REALLOC( x, t) realloc( x, t)
#	define MEM_CALLOC( x, y) calloc( x, y)
#endif
