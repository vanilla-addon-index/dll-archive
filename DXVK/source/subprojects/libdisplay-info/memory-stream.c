#include <stdlib.h>

#include "memory-stream.h"

#ifndef _WIN32

bool
memory_stream_open(struct memory_stream *m)
{
	*m = (struct memory_stream){ 0 };
	m->fp = open_memstream(&m->str, &m->str_len);

	return m->fp != NULL;
}

char *
memory_stream_close(struct memory_stream *m)
{
	char *str;
	int ret;

	ret = fclose(m->fp);
	str = m->str;
	*m = (struct memory_stream){ 0 };

	if (ret != 0) {
		free(str);
		str = NULL;
	}

	return str;
}

#else

#include <windows.h>

/* Windows has no open_memstream(), so buffer the stream in a temporary file. */
bool
memory_stream_open(struct memory_stream *m)
{
	wchar_t dir[MAX_PATH], path[MAX_PATH];
	DWORD len;

	*m = (struct memory_stream){ 0 };

	len = GetTempPathW(MAX_PATH, dir);
	if (len == 0 || len >= MAX_PATH || GetTempFileNameW(dir, L"di", 0, path) == 0)
		return false;

	/* D deletes the file once it's closed. */
	if (_wfopen_s(&m->fp, path, L"w+bTD") != 0) {
		DeleteFileW(path);
		m->fp = NULL;
		return false;
	}

	return true;
}

char *
memory_stream_close(struct memory_stream *m)
{
	char *str = NULL;
	long size;

	if (!m->fp)
		return NULL;

	if (fflush(m->fp) == 0 && fseek(m->fp, 0, SEEK_END) == 0 &&
	    (size = ftell(m->fp)) >= 0 && fseek(m->fp, 0, SEEK_SET) == 0) {
		str = malloc((size_t)size + 1);
		if (str && fread(str, 1, (size_t)size, m->fp) == (size_t)size) {
			str[size] = '\0';
		} else {
			free(str);
			str = NULL;
		}
	}

	fclose(m->fp);
	*m = (struct memory_stream){ 0 };

	return str;
}

#endif

void
memory_stream_cleanup(struct memory_stream *m)
{
	free(memory_stream_close(m));
}
