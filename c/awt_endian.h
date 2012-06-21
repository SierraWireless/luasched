#ifndef AWT_ENDIAN_H_
#define AWT_ENDIAN_H_

#include <stddef.h>
#include <stdint.h>

typedef enum {
    TBIG_ENDIAN             = 0,    // (byte order: big endian)
    TLITTLE_ENDIAN          = 1,    // (byte order: little endian)
    TMIDDLE_BIG_ENDIAN      = 2,    // (byte order: big endian, word order: little endian)
    TMIDDLE_LITTLE_ENDIAN   = 3     // (byte order: little endian, word order: big endian
} EEndian;

typedef struct SEndian_ {
    int int16_;
    int int32_;
    int int64_;
    int float_;
    int double_;
} SEndian;

/*
 * check_endian
 *  fills SEndian structure with host endianness information
* sendian: pointer to SEndian structure
 */
void check_endian(SEndian* sendian);

/*
 * hton
 *  converts host endianness values to network endianness (big endian)
 * value: value to convert
 * value_size: value's size
 * value_endian: host endianness
 */
void hton(void* value, size_t value_size, int value_endian);

/*
 * ntoh
 *  converts network endianness values to host endianness (big endian)
 * value: value to convert
 * value_size: value's size
 * value_endian: host endianness
 */
#define ntoh hton

#endif /* AWT_ENDIAN_H_ */
