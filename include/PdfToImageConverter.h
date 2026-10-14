#pragma once

/* UTF-16 entry points exported by the Native AOT build of PdfToImageConverter.
   Windows x86 uses stdcall. Apple uses the platform C calling convention.
   char16_t is 16-bit; do not use wchar_t on Apple, where wchar_t is 32-bit.
   messageBuf must hold messageBufChars UTF-16 code units, including the terminating 0.
   Page name and path lists are UTF-16 strings separated by LF or CRLF. */

#include <stdint.h>

#if defined(__cplusplus)
extern "C" {
#endif

#if defined(_WIN32)
#define PDFCONV_CALL __stdcall
#else
#define PDFCONV_CALL
#endif

typedef uint16_t pdfconv_char;

#define PDFCONV_OK 0
#define PDFCONV_ERR_ARGUMENT -1
#define PDFCONV_ERR_FAILED -2

int PDFCONV_CALL ConvertPdfToImage(
    const pdfconv_char* pdfPath,
    const pdfconv_char* outputPath,
    int32_t dpi,
    pdfconv_char* messageBuf,
    int32_t messageBufChars);

int PDFCONV_CALL ConvertPdfToImageWithPageNames(
    const pdfconv_char* pdfPath,
    const pdfconv_char* outputPath,
    int32_t dpi,
    int32_t totalPagesNumber,
    const pdfconv_char* pageNamesJoined,
    pdfconv_char* messageBuf,
    int32_t messageBufChars);

int PDFCONV_CALL ConvertPdfToImageWithPageNamesAndOutputPaths(
    const pdfconv_char* pdfPath,
    const pdfconv_char* outputPath,
    int32_t dpi,
    int32_t totalPagesNumber,
    const pdfconv_char* pageNamesJoined,
    const pdfconv_char* pagePathsJoined,
    pdfconv_char* messageBuf,
    int32_t messageBufChars);

#if defined(__cplusplus)
}
#endif
